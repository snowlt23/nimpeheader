
import macros
import strutils, boost.richstring
import options
import streams
export streams

type BinaryError* = object of Exception

proc removePostfix*(node: NimNode): NimNode {.compileTime.} =
  if node.kind == nnkPostfix:
    node[1]
  else:
    node

proc isInheritance*(node: NimNode): bool {.compileTime.} =
  if node.kind == nnkIdent:
    return false
  elif node.kind == nnkInfix and node[0].repr == "of":
    return true
  else:
    error fmt"unsupported expression: ${node.repr} (${node.kind})", node
proc typename*(node: NimNode): NimNode {.compileTime.} =
  if node.isInheritance():
    return node[1]
  else:
    return node
proc supername*(node: NimNode): Option[NimNode] {.compileTime.} =
  if node.isInheritance():
    return some(node[2])
  else:
    return none(NimNode)

proc isSkip*(node: NimNode): bool =
  if node.repr == "skip":
    return true
  else:
    return false

proc expectBinaryType*(node: NimNode) {.compileTime.} =
  let fieldexpr = node[1]
  if fieldexpr.len != 1:
    error "wrong binary call type len: " & $fieldexpr.len, node

macro replaceByProcType*(readproc: typed): untyped =
  let procimpl = readproc.symbol.getImpl()
  return procimpl[3][2][1][0]

proc `+`*(arr: varargs[int]): int =
  result = 0
  for v in arr:
    result += v

proc genBinarySize*(name: NimNode, body: NimNode): NimNode {.compileTime.} =
  var addexpr = nnkCall.newTree(nnkAccQuoted.newTree(ident"+"))
  for b in body:
    b.expectBinaryType()
    let fieldname = b[0]
    let fieldexpr = b[1][0]
    case fieldexpr.kind
    of nnkIdent:
      addexpr.add(parseExpr(fmt"${fieldexpr}Size"))
    of nnkBracketExpr:
       if $fieldexpr[0] == "array":
         addexpr.add(parseExpr(fmt"(${fieldexpr[2].repr}Size * ${fieldexpr[1].repr})"))
       else:
         return newEmptyNode()
    of nnkCall, nnkCallStrLit, nnkCommand:
      addexpr.add(parseExpr(fmt"${fieldexpr[0]}Size(${fieldexpr.repr})"))
    else:
      return newEmptyNode()
  let sizeid = ident(fmt"${name}Size").postfix("*")
  result = quote do:
    when compiles(`addexpr`):
      let `sizeid` = `addexpr`

proc genBinaryTypeDef*(name: NimNode, body: NimNode): NimNode {.compileTime.} =
  var fieldlist = nnkRecList.newTree()

  for b in body:
    b.expectBinaryType()
    let fieldname = b[0]
    let fieldexpr = b[1][0]
    if fieldname.isSkip:
      continue
    case fieldexpr.kind
    of nnkIdent:
      fieldlist.add(nnkIdentDefs.newTree(
        fieldname.postfix("*"),
        fieldexpr,
        newEmptyNode(),
      ))
    of nnkBracketExpr:
      fieldlist.add(nnkIdentDefs.newTree(
        fieldname.postfix("*"),
        fieldexpr,
        newEmptyNode(),
      ))
    of nnkCall, nnkCallStrLit, nnkCommand:
      let readid = ident("read" & $fieldexpr[0] & "Binary")
      fieldlist.add(nnkIdentDefs.newTree(
        fieldname.postfix("*"),
        nnkCall.newTree(ident"replaceByProcType", readid),
        newEmptyNode(),
      ))
    else:
      error fmt"unsupported binary type: ${fieldexpr.repr} (${fieldexpr.kind})", b
      
  if name.isInheritance:
    result = parseExpr(fmt"type ${name.typename}* = object of ${name.supername.get}")
  else:
    result = parseExpr(fmt"type ${name.typename}* = object of RootObj")
  result[0][2][2] = fieldlist

proc genReadBinaryProc*(name: NimNode, body: NimNode): NimNode {.compileTime.} =
  let procname = ident("readBinary")

  let streamid = ident"stream"
  var procbody = newStmtList()
  
  if name.isInheritance:
    let readid = ident(fmt"readBinary")
    procbody.add(parseExpr(fmt"${readid}(stream, ${name.supername.get}(binobj))"))
    procbody.add(parseExpr(fmt"let super = binobj"))

  for b in body:
    b.expectBinaryType()
    let fieldname = b[0]
    let fieldexpr = b[1][0]
    if fieldname.isSkip:
      var callexpr = nnkCall.newTree(fieldexpr[0])
      callexpr.add(streamid)
      for i in 1..<fieldexpr.len:
        callexpr.add(fieldexpr[i])
      procbody.add(callexpr)
      continue
    case fieldexpr.kind
    of nnkIdent:
      let readid = ident("readBinary")
      procbody.add(parseExpr(fmt"${readid}(${streamid}, binobj.${fieldname})"))
      procbody.add(parseExpr(fmt"let ${fieldname} {.inject.} = binobj.${fieldname}"))
    of nnkBracketExpr:
      if $fieldexpr[0] == "array":
        let readid = ident("readBinary")
        procbody.add(parseExpr(fmt"${readid}(${streamid}, binobj.${fieldname})"))
        procbody.add(parseExpr(fmt"let ${fieldname} {.inject.} = binobj.${fieldname}"))
      else:
        error "unsupported binary type: " & fieldexpr.repr, b
    of nnkCall, nnkCallStrLit, nnkCommand:
      let readid = ident("readBinary")
      var callexpr = nnkCall.newTree(readid)
      callexpr.add(streamid)
      callexpr.add(parseExpr(fmt"binobj.${fieldname}"))
      for i in 1..<fieldexpr.len:
        callexpr.add(fieldexpr[i])
      procbody.add(parseExpr(fmt"${callexpr.repr}"))
      procbody.add(parseExpr(fmt"let ${fieldname} {.inject.} = binobj.${fieldname}"))
    else:
      error "unsupported binary type: " & fieldexpr.repr, b

  result = newStmtList()
  result.add(parseExpr("{.push hint[XDeclaredButNotUsed]: off.}"))
  result.add(parseExpr(fmt"proc ${procname}*(stream: Stream, binobj: var ${name.typename}) = discard"))
  result[^1][6] = procbody
  result.add(parseExpr("{.pop.}"))

proc genWriteBinaryProc*(name: NimNode, body: NimNode): NimNode {.compileTime.} =
  let procname = ident"writeBinary"
  
  var procbody = newStmtList()
  
  if name.isInheritance:
    procbody.add(parseExpr(fmt"stream.writeBinary(cast[${name.supername.get}](bin))"))

  for b in body:
    b.expectBinaryType()
    let fieldname = b[0]
    let fieldexpr = b[1][0]
    if fieldname.isSkip:
      continue
    procbody.add(parseExpr(fmt"stream.writeBinary(bin.${fieldname})"))
  result = parseExpr(fmt"proc ${procname}*(stream: Stream, bin: ${name.typename}) = discard")
  result[6] = procbody

macro binary*(name: untyped, body: untyped): untyped =
  discard name.isInheritance()

  result = newStmtList()
  result.add(genBinarySize(name, body))
  result.add(genBinaryTypeDef(name, body))
  result.add(genReadBinaryProc(name, body))
  result.add(genWriteBinaryProc(name, body))

  echo result.repr

macro rawreadbin*(body: typed): untyped =
  var bodycopy = body.copy
  let procname = ($body[0].removePostfix()).replace("read", "read" & $body[3][2][1][0])
  bodycopy[0] = ident(procname).postfix("*")
  bodycopy[6] = nnkDiscardStmt.newTree(newEmptyNode())
  result = bodycopy

include binmacrodef

when isMainModule:
  binary Frame:
    ident: id"ID3"
    size: byte3
  binary GenericFrame of Frame:
    data: bytes(super.size.int)
  binary ID3:
    ident: id"ID3"
    majorversion: byte
    revision: byte
    bflags: byte
    frame: GenericFrame
  let id3 = ID3(ident: "ID3", majorversion: 1.byte, revision: 0.byte, flags: 0.byte, frame: GenericFrame(ident: "ID3", size: 10.tobyte3, data: "aaaaaaaaaa"))
  echo parseBinary[ID3](id3.toBinary)


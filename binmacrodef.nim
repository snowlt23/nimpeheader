
type
  bytes* = distinct string
  ID* = distinct string
  byte2* = object
    data*: array[2, byte]
  byte3* = object
    data*: array[3, byte]
  byte4* = object
    data*: array[4, byte]
  repeat*[T] = distinct seq[T]

proc writeBytes*(arr: var openarray[byte], val: int) =
  for i in 0..<arr.len:
    arr[i] = cast[byte]((val shr (i*8)) and 0xff)
proc tobyte2*(val: int): byte2 =
  result.data.writeBytes(val)
proc tobyte3*(val: int): byte3 =
  result.data.writeBytes(val)
proc tobyte4*(val: int): byte4 =
  result.data.writeBytes(val)

proc int*(bs: openarray[byte]): int =
  result = 0
  for i in 0..<bs.len:
    let n = bs.len-1 - i
    result = result or (cast[int](bs[n]) shl (i*8))
proc int*(b2: byte2): int = b2.data.int
proc int*(b3: byte3): int = b3.data.int
proc int*(b4: byte4): int = b4.data.int
proc `$`*(b: byte2): string = $b.int
proc `$`*(b: byte3): string = $b.int
proc `$`*(b: byte4): string = $b.int

proc `[]`*(bs: bytes, i: int): char = string(bs)[i]
proc `[]=`*(bs: var bytes, i: int, c: char) =
  string(bs)[i] = c
proc `$`*(bs: bytes): string = string(bs)

proc `$`*(id: ID): string = string(id)

converter toSeq*[T](r: repeat[T]): seq[T] = seq[T](r)

#
# Size
#

let charSize* = sizeof(char)
let byteSize* = sizeof(byte)
let uint8Size* = sizeof(uint8)
let uint16Size* = sizeof(uint16)
let uint32Size* = sizeof(uint32)
let int32Size* = sizeof(int32)
let byte2Size* = 2
let byte3Size* = 3
let byte4Size* = 4

macro idSize*(e: untyped): untyped =
  result = newIntLitNode(e[1].strval.len) 
macro bytesSize*(e: untyped): untyped =
  if e[1].kind == nnkIntLit:
    result = e[1]
  else:
    result = newIntLitNode(0)

#
# readBinary
#

proc readBinary*(stream: StringStream, binobj: var char) = binobj = stream.readChar()
proc readBinary*(stream: StringStream, binobj: var byte) = binobj = stream.readChar().byte
proc readBinary*(stream: StringStream, binobj: var uint16) = binobj = stream.readInt16().uint16
proc readBinary*(stream: StringStream, binobj: var uint32) = binobj = stream.readInt32().uint32
proc readBinary*(stream: StringStream, binobj: var int32) = binobj = stream.readInt32()
proc readBinary*(stream: StringStream, binobj: var byte2) =
  binobj.data[0] = stream.readChar().byte
  binobj.data[1] = stream.readChar().byte
proc readBinary*(stream: StringStream, binobj: var byte3) =
  binobj.data[0] = stream.readChar().byte
  binobj.data[1] = stream.readChar().byte
  binobj.data[2] = stream.readChar().byte
proc readBinary*(stream: StringStream, binobj: var byte4) =
  binobj.data[0] = stream.readChar().byte
  binobj.data[1] = stream.readChar().byte
  binobj.data[2] = stream.readChar().byte
  binobj.data[3] = stream.readChar().byte
proc readBinary*(stream: StringStream, binobj: var bytes, size: int) {.rawreadbin.} =
  binobj = bytes(newString(size))
  for i in 0..<size:
    binobj[i] = stream.readChar()
proc readBinary*(stream: StringStream, binobj: var ID, s: string) {.rawreadbin.} =
  var ss = ""
  for c in s:
    ss.add(stream.readChar())
    if not (ss[^1] == c):
      raise newException(BinaryError, fmt"""unmatched id: "${s}" == "${ss}"""")
  binobj = ID(s)
proc readBinary*(stream: StringStream, binobj: var string) =
  binobj = ""
  while true:
    let c = stream.readChar()
    if c == '\0':
      break
    binobj.add(c)
proc readBinary*[T](stream: StringStream, binobj: var openarray[T]) =
  for v in binobj.mitems:
    readBinary(stream, v)
proc readBinary*[T](stream: StringStream, binobj: var seq[T], len: int) =
  binobj = newSeq[T](len)
  for i in 0..<len:
    readBinary(stream, binobj[i])
proc readBinary*[T](stream: StringStream, binobj: var ptr T) =
  var p: uint
  readBinary(stream, p)
  binobj = cast[ptr T](p)

template replaceBySeq*(T: typedesc): untyped =
  seq[T]

#
# writeBinary
#

proc writeBinary*(stream: StringStream, c: char) =
  stream.write(c)
proc writeBinary*(stream: StringStream, b: byte) =
  stream.write(b)
proc writeBinary*(stream: StringStream, i: uint16) =
  stream.write(i)
proc writeBinary*(stream: StringStream, i: uint32) =
  stream.write(i)
proc writeBinary*(stream: StringStream, i: int32) =
  stream.write(i)
proc writeBinary*(stream: StringStream, u: byte2) =
  stream.write(u.data[0])
  stream.write(u.data[1])
proc writeBinary*(stream: StringStream, u: byte3) =
  stream.write(u.data[0])
  stream.write(u.data[1])
  stream.write(u.data[2])
proc writeBinary*(stream: StringStream, u: byte4) =
  stream.write(u.data[0])
  stream.write(u.data[1])
  stream.write(u.data[2])
  stream.write(u.data[3])
proc writeBinary*(stream: StringStream, s: string) =
  for c in s:
    stream.write(c)
proc writeBinary*(stream: StringStream, s: bytes) =
  stream.writeBinary(string(s))
proc writeBinary*(stream: StringStream, s: ID) =
  stream.writeBinary(string(s))
proc writeBinary*[T](stream: StringStream, arr: openarray[T]) =
  for v in arr:
    stream.writeBinary(v)
proc writeBinary*[T](stream: StringStream, p: ptr T) =
  stream.write(cast[uint](p))
proc writeBinary*[T](stream: StringStream, binobj: repeat[T]) =
  for v in seq[T](binobj):
    stream.writeBinary(v)

#
# StringStream Control
#

proc move*(stream: StringStream, len: int) =
  for i in 0..<len:
    discard stream.readChar()
proc moveTo*(stream: StringStream, pos: int) =
  stream.setPosition(pos)

#
# Utils
#

proc toBinary*[T](binobj: T): string =
  var stream = newStringStream()
  stream.writeBinary(binobj)
  return stream.data
proc parseBinary*[T](bin: string): T =
  var stream = newStringStream(bin)
  readBinary(stream, result)

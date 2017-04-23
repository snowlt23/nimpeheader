
type
  bytes* = distinct string
  ID* = distinct string
  byte2* = object
    data*: array[2, byte]
  byte3* = object
    data*: array[3, byte]
  byte4* = object
    data*: array[4, byte]

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
converter int*(b2: byte2): int = b2.data.int
converter int*(b3: byte3): int = b3.data.int
converter int*(b4: byte4): int = b4.data.int
proc `$`*(b: byte2): string = $b.int
proc `$`*(b: byte3): string = $b.int
proc `$`*(b: byte4): string = $b.int

proc `[]`*(bs: bytes, i: int): char = string(bs)[i]
proc `[]=`*(bs: var bytes, i: int, c: char) =
  string(bs)[i] = c
proc `$`*(bs: bytes): string = string(bs)

proc `$`*(id: ID): string = string(id)

#
# Size
#

let charSize* = sizeof(char)
let byteSize* = sizeof(byte)
let uint16Size* = sizeof(uint16)
let uint32Size* = sizeof(uint32)
let int32Size* = sizeof(int32)
let byte2Size* = 2
let byte3Size* = 3

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

proc readBinary*(stream: Stream, binobj: var char) = binobj = stream.readChar()
proc readBinary*(stream: Stream, binobj: var byte) = binobj = stream.readChar().byte
proc readBinary*(stream: Stream, binobj: var uint16) = binobj = stream.readInt16().uint16
proc readBinary*(stream: Stream, binobj: var uint32) = binobj = stream.readInt32().uint32
proc readBinary*(stream: Stream, binobj: var int32) = binobj = stream.readInt32()
proc readBinary*(stream: Stream, binobj: var byte2) =
  binobj.data[0] = stream.readChar().byte
  binobj.data[1] = stream.readChar().byte
proc readBinary*(stream: Stream, binobj: var byte3) =
  binobj.data[0] = stream.readChar().byte
  binobj.data[1] = stream.readChar().byte
  binobj.data[2] = stream.readChar().byte
proc readBinary*(stream: Stream, binobj: var byte4) =
  binobj.data[0] = stream.readChar().byte
  binobj.data[1] = stream.readChar().byte
  binobj.data[2] = stream.readChar().byte
  binobj.data[3] = stream.readChar().byte
proc readBinary*(stream: Stream, binobj: var bytes, size: int) {.rawreadbin.} =
  binobj = bytes(newString(size))
  for i in 0..<size:
    binobj[i] = stream.readChar()
proc readBinary*(stream: Stream, binobj: var ID, s: string) {.rawreadbin.} =
  var ss = ""
  for c in s:
    ss.add(stream.readChar())
    if not (ss[^1] == c):
      raise newException(BinaryError, fmt"""unmatched id: "${s}" == "${ss}"""")
  binobj = ID(s)
proc readBinary*(stream: Stream, binobj: var string) =
  binobj = ""
  while true:
    let c = stream.readChar()
    if c == '\0':
      break
    binobj.add(c)
proc readBinary*[T](stream: Stream, binobj: var openarray[T]) =
  for v in binobj.mitems:
    readBinary(stream, v)
proc readBinary*[T](stream: Stream, binobj: var ptr T) =
  var p: uint
  readBinary(stream, p)
  binobj = cast[ptr T](p)

#
# writeBinary
#

proc writeBinary*(stream: Stream, c: char) =
  stream.write(c)
proc writeBinary*(stream: Stream, b: byte) =
  stream.write(b)
proc writeBinary*(stream: Stream, i: uint16) =
  stream.write(i)
proc writeBinary*(stream: Stream, i: uint32) =
  stream.write(i)
proc writeBinary*(stream: Stream, i: int32) =
  stream.write(i)
proc writeBinary*(stream: Stream, u: byte2) =
  stream.write(u.data[0])
  stream.write(u.data[1])
proc writeBinary*(stream: Stream, u: byte3) =
  stream.write(u.data[0])
  stream.write(u.data[1])
  stream.write(u.data[2])
proc writeBinary*(stream: Stream, u: byte4) =
  stream.write(u.data[0])
  stream.write(u.data[1])
  stream.write(u.data[2])
  stream.write(u.data[3])
proc writeBinary*(stream: Stream, s: string) =
  for c in s:
    stream.write(c)
proc writeBinary*(stream: Stream, s: bytes) =
  stream.writeBinary(string(s))
proc writeBinary*(stream: Stream, s: ID) =
  stream.writeBinary(string(s))
proc writeBinary*[T](stream: Stream, arr: openarray[T]) =
  for v in arr:
    stream.writeBinary(v)
proc writeBinary*[T](stream: Stream, p: ptr T) =
  stream.write(cast[uint](p))

#
# Stream Control
#

proc move*(stream: Stream, len: int) =
  for i in 0..<len:
    discard stream.readChar()

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

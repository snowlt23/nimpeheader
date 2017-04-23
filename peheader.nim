
import binmacro

const IMAGE_NUMBEROF_DIRECTORY_ENTRIES = 16

binary IMAGE_DOS_HEADER:
  e_magic: id"MZ"
  e_cblp: uint16
  e_cp: uint16
  e_crlc: uint16
  e_cparhdr: uint16
  e_minalloc: uint16
  e_maxalloc: uint16
  e_ss: uint16
  e_sp: uint16
  e_csum: uint16
  e_ip: uint16
  e_cs: uint16
  e_lfarlc: uint16
  e_ovno: uint16
  e_res: array[4, uint16]
  e_oemid: uint16
  e_oeminfo: uint16
  e_res2: array[10, uint16]
  e_lfanew: int32

binary IMAGE_FILE_HEADER:
  Machine: byte2
  NumberOfSections: uint16
  TimeDateStamp: uint32
  PointerToSymbolTable: uint32
  NumberOfSymbols: uint32
  SizeOfOptionalHeader: uint16
  Characteristics: uint16

binary IMAGE_DATA_DIRECTORY:
  VirtualAddress: uint32
  Size: uint32

binary IMAGE_OPTIONAL_HEADER32:
  WMagic: bytes(2)
  MajorLinkerVersion: byte
  MinorLinkerVersion: byte
  SizeOfCode: uint32
  SizeOfInitializedData: uint32
  SizeOfUninitializedData: uint32
  AddressOfEntryPoint: uint32
  BaseOfCode: uint32
  BaseOfData: uint32
  ImageBase: uint32
  SectionAlignment: uint32
  FileAlignment: uint32
  MajorOperatingSystemVersion: uint16
  MinorOperatingSystemVersion: uint16
  MajorImageVersion: uint16
  MinorImageVersion: uint16
  MajorSubsystemVersion: uint16
  MinorSubsystemVersion: uint16
  Win32VersionValue: uint32
  SizeOfImage: uint32
  SizeOfHeaders: uint32
  CheckSum: uint32
  Subsystem: uint16
  DllCharacteristics: uint16
  SizeOfStackReserve: uint32
  SizeOfStackCommit: uint32
  SizeOfHeapReserve: uint32
  SizeOfHeapCommit: uint32
  LoaderFlags: uint32
  NumberOfRvaAndSizes: uint32
  DataDirectory: array[IMAGE_NUMBEROF_DIRECTORY_ENTRIES, IMAGE_DATA_DIRECTORY]

binary IMAGE_EXPORT_DIRECTORY:
  Characteristics: uint32
  TimeDateStamp: uint32
  MajorVersion: uint16
  MinorVersion: uint16
  Name: uint32
  Base: uint32
  NumberOfFunctions: uint32
  NumberOfNames: uint32
  AddressOfFunctions: uint32
  AddressOfNames: uint32
  AddressOfNameOrdinals: uint32

binary IMAGE_NT_HEADER32:
  dos: IMAGE_DOS_HEADER
  space: bytes(dos.e_lfanew - IMAGE_DOS_HEADER_SIZE)
  Signature: bytes(4)
  FileHeader: IMAGE_FILE_HEADER
  OptionalHeader: IMAGE_OPTIONAL_HEADER32
  skip: move(OptionalHeader.DataDirectory[0].VirtualAddress.int - dos.e_lfanew - IMAGE_FILE_HEADER_SIZE - IMAGE_OPTIONAL_HEADER32_SIZE)
  exportdir: IMAGE_EXPORT_DIRECTORY

# type
#   ExportFunction* = object
#     address*: pointer
#     name*: string

# proc readImageExportDirectory*(optheader: IMAGE_OPTIONAL_HEADER32, bin: StringStream): IMAGE_EXPORT_DIRECTORY =
#   let address = optheader.DataDirectory[0].VirtualAddress.int
#   bin.setPosition(address)
#   bin.readBinary(result)
# proc readExportFunctions*(exdir: IMAGE_EXPORT_DIRECTORY, bin: StringStream): seq[ExportFunction] =
#   bin.setPosition(exdir.AddressOfNames.int)
#   var namervas = newSeq[uint32]()
#   for i in 0..<exdir.NumberOfNames:
#     var namerva: uint32
#     bin.readBinary(namerva)
#     namervas.add(namerva)

#   bin.setPosition(exdir.AddressOfNameOrdinals.int)
#   var ords = newSeq[int]()
#   for i in 0..<exdir.NumberOfNames:
#     var ordval: uint32
#     bin.readBinary(ordval)

#   bin.setPosition(exdir.AddressOfNames.int)
#   var procrvas = newSeq[uint32]()
#   for i in 0..<exdir.NumberOfFunctions:
#     var procrva: uint32
#     bin.readBinary(procrva)
#     procrvas.add(procrva)

#   result = newSeq[ExportFunction]()
#   for i in 0..<namervas.len:
#     bin.setPosition(namervas[i].int)
#     var name = ""
#     bin.readBinary(name)
#     result.add(ExportFunction(
#         address: cast[pointer](procrvas[ords[i]]),
#         name: name,
#     ))

let dllstream = newStringStream(readFile("test.dll"))
var imgheader: IMAGE_NT_HEADER32
readBinary(dllstream, imgheader)
# let exdir = imgheader.OptionalHeader.readImageExportDirectory(dllstream)
# let fns = exdir.readExportFunctions(dllstream)
# echo fns

echo imgheader.dos.e_magic
echo imgheader.dos.e_lfanew
echo imgheader.Signature

echo imgheader.FileHeader.Machine and 0x0002
echo imgheader.FileHeader.Machine and 0x0100
echo imgheader.FileHeader.Machine and 0x1000
echo imgheader.FileHeader.Machine and 0x2000

echo imgheader.OptionalHeader.WMagic
echo imgheader.OptionalHeader.DataDirectory[0].VirtualAddress

echo imgheader.exportdir.NumberOfNames

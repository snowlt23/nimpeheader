
import binmacro
import strutils

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
  Machine: uint16
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
  Magic: uint16
  MajorLinkerVersion: uint8 
  MinorLinkerVersion: uint8 
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
  # skip: move(OptionalHeader.DataDirectory[0].VirtualAddress.int - dos.e_lfanew - IMAGE_FILE_HEADER_SIZE - IMAGE_OPTIONAL_HEADER32_SIZE)
  # skip: move(OptionalHeader.DataDirectory[0].VirtualAddress.int - dos.e_lfanew - IMAGE_FILE_HEADER_SIZE - IMAGE_OPTIONAL_HEADER32_SIZE + OptionalHeader.ImageBase.int)
  # exportdir: IMAGE_EXPORT_DIRECTORY

binary IMAGE_SECTION_HEARDER:
  Name: bytes(8)
  VirtualSize: uint32
  VirtualAddress: uint32
  SizeOfRawData: uint32
  PointerToRawData: uint32
  PointerToRelocations: uint32
  PointerToLinenumbers: uint32
  NumberOfRelocations: uint16
  NumberOfLinenumbers: uint16
  Characteristics: uint32

binary IMAGE_HEARDER32:
  nt: IMAGE_NT_HEADER32
  sectionheaders: repeat[IMAGE_SECTION_HEARDER](nt.FileHeader.NumberOfSections.int)

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

let imgheader = parseBinary[IMAGE_HEARDER32](readFile("test.dll"))
# let exdir = imgheader.OptionalHeader.readImageExportDirectory(dllstream)
# let fns = exdir.readExportFunctions(dllstream)
# echo fns

echo imgheader.nt.dos.e_magic
echo imgheader.nt.dos.e_lfanew.toHex
echo imgheader.nt.Signature

echo imgheader.nt.FileHeader.Machine.toHex
echo imgheader.nt.FileHeader.Characteristics.toHex

echo imgheader.nt.OptionalHeader.Magic.toHex
echo imgheader.nt.OptionalHeader.DataDirectory[0].VirtualAddress.toHex
 
echo imgheader.nt.OptionalHeader.ImageBase.toHex

echo imgheader.sectionheaders.toSeq()[0].Name
echo imgheader.sectionheaders.toSeq()[1].Name
echo imgheader.sectionheaders.toSeq()[2].Name

# echo imgheader.exportdir.NumberOfNames

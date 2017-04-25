
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

binary IMAGE_NT_HEADER32:
  dos: IMAGE_DOS_HEADER
  space: bytes(self.dos.e_lfanew - IMAGE_DOS_HEADER_SIZE)
  Signature: bytes(4)
  FileHeader: IMAGE_FILE_HEADER
  OptionalHeader: IMAGE_OPTIONAL_HEADER32

binary IMAGE_SECTION_HEADER:
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

type
  SectionKind* = enum
    sectionText
    sectionData
    sectionRData
    sectionBSS
    sectionEData
    sectionIData
    sectionCRT
    sectionTLS
    sectionReloc
    sectionOther
  Section* = object
    case kind*: SectionKind
    of sectionEData:
      exdir*: IMAGE_EXPORT_DIRECTORY
    else:
      data*: bytes

proc readBinary*(stream: StringStream, section: var Section, sectionheader: IMAGE_SECTION_HEADER, datadirs: seq[IMAGE_DATA_DIRECTORY]) {.readbinproc.} =
  if ($sectionheader.Name).startsWith(".edata"):
    stream.moveTo(int(datadirs[0].VirtualAddress - sectionheader.VirtualAddress + sectionheader.PointerToRawData))
    section.kind = sectionEData
    stream.readBinary(section.exdir)
  else:
    stream.moveTo(sectionheader.PointerToRawData.int) # TODO:
    section.kind = sectionOther
    stream.readBinary(section.data, sectionheader.SizeOfRawData.int)
proc readBinary*(stream: StringStream, sections: var seq[Section], sectionheaders: seq[IMAGE_SECTION_HEADER], datadirs: seq[IMAGE_DATA_DIRECTORY]) {.readbinproc.} =
  sections = newSeq[Section](sectionheaders.len)
  for i in 0..<sectionheaders.len:
    stream.readBinary(sections[i], sectionheaders[i], datadirs)

binary IMAGE_HEARDER32:
  nt: IMAGE_NT_HEADER32
  sectionheaders: seq[IMAGE_SECTION_HEADER](self.nt.FileHeader.NumberOfSections.int)
  sections: seq[Section](self.sectionheaders, @(self.nt.OptionalHeader.DataDirectory))

type
  ExportFunction* = object
    address*: uint32
    name*: string

proc readExportFunctions*(stream: StringStream, sectionheader: IMAGE_SECTION_HEADER, exdir: IMAGE_EXPORT_DIRECTORY): seq[ExportFunction] =
  stream.moveTo(int(exdir.AddressOfNames - sectionheader.VirtualAddress + sectionheader.PointerToRawData))
  var namervas = newSeq[uint32]()
  for i in 0..<exdir.NumberOfNames:
    namervas.add(parseBinary[uint32](stream))

  stream.moveTo(int(exdir.AddressOfNameOrdinals - sectionheader.VirtualAddress + sectionheader.PointerToRawData))
  var ords = newSeq[uint16]()
  for i in 0..<exdir.NumberOfNames:
    ords.add(parseBinary[uint16](stream))

  stream.moveTo(int(exdir.AddressOfFunctions - sectionheader.VirtualAddress + sectionheader.PointerToRawData))
  var procrvas = newSeq[uint32]()
  for i in 0..<exdir.NumberOfFunctions:
    procrvas.add(parseBinary[uint32](stream))

  result = newSeq[ExportFunction]()
  for i in 0..<namervas.len:
    stream.moveTo(int(namervas[i] - sectionheader.VirtualAddress + sectionheader.PointerToRawData))
    result.add(ExportFunction(
        address: procrvas[int(ords[i].uint32 - exdir.Base + 1)],
        name: parseBinary[string](stream),
    ))

let imgheader = parseBinary[IMAGE_HEARDER32](readFile("test.dll"))

echo imgheader.nt.dos.e_magic
echo imgheader.nt.dos.e_lfanew.toHex
echo imgheader.nt.Signature

echo imgheader.nt.FileHeader.Machine.toHex
echo imgheader.nt.FileHeader.Characteristics.toHex

echo imgheader.nt.OptionalHeader.Magic.toHex
echo imgheader.nt.OptionalHeader.DataDirectory[0].VirtualAddress.toHex
 
echo imgheader.nt.OptionalHeader.ImageBase.toHex

echo imgheader.sectionheaders[0].Name
echo imgheader.sectionheaders[1].Name
echo imgheader.sectionheaders[2].Name

for i in 0..<imgheader.sectionheaders.len:
  if imgheader.sections[i].kind == sectionEData:
    let stream = newStringStream(readFile("test.dll"))
    echo stream.readExportFunctions(imgheader.sectionheaders[i], imgheader.sections[i].exdir)


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

proc readBinary*(stream: StringStream, section: var Section, sectionheader: IMAGE_SECTION_HEADER) {.rawreadbin.} =
  stream.moveTo(sectionheader.PointerToRawData.int)
  if ($sectionheader.Name).startsWith(".edata"):
    section.kind = sectionEData
    stream.readBinary(section.exdir)
  else:
    section.kind = sectionOther
    stream.readBinary(section.data, sectionheader.SizeOfRawData.int)
proc readBinary*(stream: StringStream, sections: var seq[Section], sectionheaders: seq[IMAGE_SECTION_HEADER]) {.rawreadbin.} =
  sections = newSeq[Section](sectionheaders.len)
  for i in 0..<sectionheaders.len:
    stream.readBinary(sections[i], sectionheaders[i])

binary IMAGE_HEARDER32:
  nt: IMAGE_NT_HEADER32
  sectionheaders: seq[IMAGE_SECTION_HEADER](self.nt.FileHeader.NumberOfSections.int)
  sections: seq[Section](self.sectionheaders)

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

for section in imgheader.sections:
  echo section.kind
  if section.kind == sectionEData:
    echo section.exdir.NumberOfFunctions

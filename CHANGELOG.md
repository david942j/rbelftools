# Changelog

All notable changes to **elftools** are recorded here.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html),
so a change that removes or alters existing API only lands in a major release and
is listed under *Breaking* below.

Releases up to 1.3.1 were announced on the
[releases page](https://github.com/david942j/rbelftools/releases) only, their
entries here are collected from those announcements and from the commit history.

## Unreleased

### Added

- `Dynamic::Tag#type`, what kind of tag it is, which took reaching into its header
  ([#131](https://github.com/david942j/rbelftools/pull/131))
- `Structs::ELFStruct.unpack_fields` and `.num_bytes`, and `Structs::Fields`, which reads a
  structure's fields from its bytes and builds the structure only when something asks
  ([#127](https://github.com/david942j/rbelftools/pull/127),
  [#129](https://github.com/david942j/rbelftools/pull/129))

### Fixed

- `ELFFile#patches` and `#save` dropped a change made to a dynamic tag or to a symbol read
  through the tags, which are remembered in a hash rather than an array and so were never
  reached ([#132](https://github.com/david942j/rbelftools/pull/132))

### Changed

- Reading a dynamic tag unpacks its bytes rather than building a structure, so looking one
  up reads no structure at all: 10 objects a tag rather than 208
  ([#131](https://github.com/david942j/rbelftools/pull/131))
- Reading a relocation unpacks its bytes rather than building a structure, packed ones
  included: 8 objects an entry rather than 179, and `Dynamic#num_symbols` four times faster
  where it reads them all ([#129](https://github.com/david942j/rbelftools/pull/129))
- Reading a symbol unpacks its bytes rather than building a structure for every entry, one
  being built only for a caller that asks for `header`: 10 objects a symbol rather than 203.
  A symbol read through the sections now records the class of the file, as one read through
  the tags did ([#127](https://github.com/david942j/rbelftools/pull/127))

## 2.1.0 - 2026-08-31

### Added

- `Sections::Section#writable?`, `#executable?`, and `#allocated?`, which read `sh_flags`
  the way `Segments::Segment` already reads `p_flags`
  ([#117](https://github.com/david942j/rbelftools/pull/117))
- `Sections::Symbol#value` and `#size`, what a symbol is worth and how large what it names
  is, the last of what it records that took reaching into its header
  ([#116](https://github.com/david942j/rbelftools/pull/116))
- `Sections::VersionSection`, `VersionNeedSection`, and `VersionDefinitionSection`, the
  `.gnu.version` sections the tags point at, and `VersionTables`, which reads either view
  ([#115](https://github.com/david942j/rbelftools/pull/115))
- `Sections::Symbol#version` and `#version_hidden?`, the version a symbol binds to, which
  tells `memcpy@GLIBC_2.14` from the `memcpy@GLIBC_2.2.5` of the same name
  ([#114](https://github.com/david942j/rbelftools/pull/114))
- `Dynamic#version_requirements` and `#version_definitions`, the versions a file needs and
  the ones it defines, read from the tags so a file stripped of its sections still answers
  ([#114](https://github.com/david942j/rbelftools/pull/114))
- `Constants::VER_FLG` and `VER_NDX`, and the `Structs::ELF_Verneed`, `ELF_Vernaux`,
  `ELF_Verdef`, and `ELF_Verdaux` structures behind them
  ([#114](https://github.com/david942j/rbelftools/pull/114))
- `Sections::RelativeRelocationSection` and `RelativeRelocations`, the `SHT_RELR`
  relocations a file packs into a bitmap, of the type the machine calls relative
  ([#113](https://github.com/david942j/rbelftools/pull/113))
- `Constants::R.relative`, the type a machine calls a relocation that only adds the load
  bias ([#113](https://github.com/david942j/rbelftools/pull/113))
- `Sections::Symbol#type=`, `#bind=`, and `#visibility=`, and `Relocation#type=` and
  `#symbol_index=`, which assign what a value means and leave the rest of the byte or field
  it shares alone ([#112](https://github.com/david942j/rbelftools/pull/112))
- `Util.fits!`, which reports a value too large for the bits recording it
  ([#112](https://github.com/david942j/rbelftools/pull/112))

### Fixed

- The lookups taking a symbol or a string could not name a constant keeping the case an ABI
  wrote it in, so `sections_by_type(:gnu_verneed)` raised
  ([#115](https://github.com/david942j/rbelftools/pull/115))
- `Dynamic#relocations` passed over the relocations `DT_RELR` packs into a bitmap. Of a
  system's 3780 loaded files, 557 pack some of theirs that way
  ([#113](https://github.com/david942j/rbelftools/pull/113))
- Assigning to a field of a structure a header records, `e_ident` and the seven fields it
  holds, was dropped without a word
  ([#111](https://github.com/david942j/rbelftools/pull/111))
- Patching a field of a big endian file wrote the bytes of that field the wrong way round
  ([#111](https://github.com/david942j/rbelftools/pull/111))

### Changed

- `Structs::ELFStruct#patches` answers with the bytes that differ from those a structure was
  read from, not a log of the assignments made to it, so a field is patchable however deeply
  it is nested. `Structs::ELFStruct.pack` is deprecated
  ([#111](https://github.com/david942j/rbelftools/pull/111))
- `Dynamic#num_symbols` answers with what `DT_HASH` counts rather than reading every
  relocation to bound a number the table already states. Reading the symbols the tags point
  at is well over twice as fast ([#119](https://github.com/david942j/rbelftools/pull/119))
- A structure remembers the bytes it was read from by taking them back off the stream rather
  than serializing itself again. A stream that cannot be seeked is serialized as before
  ([#120](https://github.com/david942j/rbelftools/pull/120))
- `Util.cstring` takes a stream in chunks rather than a byte at a time, so reading a name no
  longer costs the square of its length: a name of 1024 bytes reads around 45 times faster
  ([#121](https://github.com/david942j/rbelftools/pull/121))
- `Dynamic#symbol_by_name` stops at a hash table built over every symbol instead of
  searching the whole table for a name it has already answered for. Asking a libc for a name
  it does not record is around fifty times faster
  ([#123](https://github.com/david942j/rbelftools/pull/123))
- `Util.to_constant` reads what a module names its constants once instead of walking the
  list for every lookup, and answers around nine times faster
  ([#124](https://github.com/david942j/rbelftools/pull/124))

## 2.0.0 - 2026-08-24

### Breaking

- `Relocation#r_info_sym` and `#r_info_type` are gone. `#symbol_index` and `#type`, which
  used to be aliases of them, are the names now, after what the values mean rather than the
  field they are read out of ([#110](https://github.com/david942j/rbelftools/pull/110))
- `ELFFile#strtab_section` is `ELFFile#section_name_table`, and answers with `.shstrtab`
  rather than `.strtab`, which `Sections::SymTabSection#symstr` answers with. The keyword
  `Sections::Section` takes for it is `section_name_table:`
  ([#109](https://github.com/david942j/rbelftools/pull/109))
- Ruby 3.3 or later is required ([#85](https://github.com/david942j/rbelftools/pull/85))
- Addresses that occupy memory but have no content in the file, `.bss` for instance, are no
  longer converted into a file offset by `ELFFile#offset_from_vma` or
  `Segments::LoadSegment#vma_in?` ([#83](https://github.com/david942j/rbelftools/pull/83))
- A dynamic section or segment whose `DT_STRTAB` is missing, or points to an address that is
  not loaded, raises `ELFError` instead of failing with `NoMethodError`
  ([#82](https://github.com/david942j/rbelftools/pull/82))
- `ELFFile#machine` returns the name binutils records, so `EM_X86_64` is
  `'Advanced Micro Devices X86-64 processor'` and `EM_AARCH64` is
  `'ARM 64-bit architecture'` ([#92](https://github.com/david942j/rbelftools/pull/92))
- Eight `Constants::EM` constants are gone. `EM_486`, `EM_FRV`, `EM_MIPS_RS4_BE`,
  `EM_OPENRISC`, `EM_SHARC`, `EM_TI_ARP32`, and `EM_VPP500` are what binutils spells
  `EM_IAMCU`, `EM_CYGNUS_FRV`, `EM_MIPS_RS3_LE`, `EM_OR1K`, `EM_res133`, `EM_res143`, and
  `EM_VPP550`, and `EM_C116` was a misspelling of `EM_C166`
  ([#92](https://github.com/david942j/rbelftools/pull/92))

### Added

- `ELFFile#vma_from_offset`, the counterpart of `ELFFile#offset_from_vma`
  ([#76](https://github.com/david942j/rbelftools/pull/76))
- `Sections::Symbol#type`, `#bind`, `#visibility`, and `#section_index`, which decode
  `st_info` and `st_other`, together with the `Constants::STV` visibilities
  ([#89](https://github.com/david942j/rbelftools/pull/89))
- `Dynamic#symbol_by_name` looks a name up through `DT_HASH` or `DT_GNU_HASH`, which is what
  the loader itself does. A name no table leads to is still searched for
  ([#105](https://github.com/david942j/rbelftools/pull/105))
- `Dynamic#symbols`, `#symbol_at`, `#symbol_by_name`, and `#num_symbols`, the symbols the
  tags point at, which is where a file stripped of its sections still records them. Nothing
  records how large that table is, so the count is how far the hash tables and the
  relocations reach, and `#symbol_at` is exact for any index
  ([#104](https://github.com/david942j/rbelftools/pull/104))
- `Dynamic#relocations`, the relocations the tags point at, read from `DT_REL` or `DT_RELA`
  and from `DT_JMPREL` ([#103](https://github.com/david942j/rbelftools/pull/103))
- `ELFFile#dynamic`, the tags read from the view the type of the file makes authoritative:
  the segment for a file that is loaded, the section for a relocatable one
  ([#102](https://github.com/david942j/rbelftools/pull/102))
- `Sections::Symbol#type_name`, `#bind_name`, and `#visibility_name`, and
  `Constants::Naming` behind them, which names a value after the constants defining it,
  telling `STT_GNU_IFUNC` from the `STT_LOOS` it shares a value with
  ([#101](https://github.com/david942j/rbelftools/pull/101))
- 42 more `Constants::EM` constants, `EM_RISCV`, `EM_LOONGARCH`, and `EM_IAMCU` among them
  ([#92](https://github.com/david942j/rbelftools/pull/92))
- `ELFFile#machine` names 229 machines, where it used to name 11 and answer
  `'<unknown>: 0x...'` for the rest ([#92](https://github.com/david942j/rbelftools/pull/92))
- `Constants::R`, the relocation types of 77 architectures, 3579 of them. The same number
  means different things to different machines, so they are grouped as
  `Constants::R::X86_64` and so on, each loaded once it is asked for
  ([#93](https://github.com/david942j/rbelftools/pull/93))
- `Relocation#type_name`, which names a relocation type after the machine of the file it was
  read from, and `Constants::R.mapping` behind it
  ([#95](https://github.com/david942j/rbelftools/pull/95))

### Fixed

- Every `LazyArray` method but `#[]` used to operate on elements that had not been loaded,
  so `#to_a`, `#map`, and friends returned `nil`s
  ([#84](https://github.com/david942j/rbelftools/pull/84))
- `Relocation#type` and `#symbol_index` of a 64-bit MIPS file returned a mix of fields. The
  ABI packs three types and a second symbol index into `r_info`, ordered as the file is
  ([#97](https://github.com/david942j/rbelftools/pull/97))

### Changed

- Every iterator is named in the singular, `ELFFile#each_section`, `Dynamic#each_tag`,
  `Note#each_note`, and the rest. The plural name each used to go by is an alias of it
  ([#108](https://github.com/david942j/rbelftools/pull/108))
- `Dynamic#relocations` reads a table once instead of re-reading it on every call, so the
  relocations it returns are the same objects each time
  ([#106](https://github.com/david942j/rbelftools/pull/106))
- The `bindata` requirement is relaxed to `>= 2, < 4`
  ([#81](https://github.com/david942j/rbelftools/pull/81))
- `Constants::EM` and the names behind `ELFFile#machine` are generated from binutils by
  `bundle exec rake gen:constants` instead of being maintained by hand
  ([#92](https://github.com/david942j/rbelftools/pull/92))

## 1.3.1 - 2024-04-22

### Fixed

- Off-by-one in `ELFFile#offset_from_vma`, whose `size` argument now defaults to 1
  ([#74](https://github.com/david942j/rbelftools/pull/74))

## 1.3.0 - 2024-02-17

### Breaking

- Ruby 3.1 or later is required ([#73](https://github.com/david942j/rbelftools/pull/73))

### Fixed

- Miscellaneous typos ([#72](https://github.com/david942j/rbelftools/pull/72))

## 1.2.0 - 2022-10-13

### Breaking

- Ruby 2.6 or later is required, raised from 2.3 in two steps
  ([#54](https://github.com/david942j/rbelftools/pull/54),
  [#67](https://github.com/david942j/rbelftools/pull/67))

### Added

- Many more `DT`, `EM`, and section constants
  ([#70](https://github.com/david942j/rbelftools/pull/70))
- `Structs::ELFStruct#to_h`, so that a header can be turned into a Hash
  ([#61](https://github.com/david942j/rbelftools/pull/61),
  [#65](https://github.com/david942j/rbelftools/pull/65))
- `SHF` constants ([#60](https://github.com/david942j/rbelftools/pull/60))

### Changed

- `LazyArray` reworked ([#63](https://github.com/david942j/rbelftools/pull/63))

## 1.1.3 - 2020-08-26

### Added

- `SHN`, `PF`, and `DT_VERSYM` constants
  ([#44](https://github.com/david942j/rbelftools/pull/44))

### Removed

- Ruby 2.3 from the tested versions

## 1.1.2 - 2020-02-03

### Added

- `ELFMagicError`, `ELFClassError`, and `ELFDataError`, which inherit `ELFError` and
  tell apart why a file was rejected
  ([#43](https://github.com/david942j/rbelftools/pull/43))

## 1.1.1 - 2019-10-27

### Breaking

- Ruby 2.3 or later is required
  ([#40](https://github.com/david942j/rbelftools/pull/40))

### Fixed

- Warning about keyword arguments on Ruby 2.7
  ([#42](https://github.com/david942j/rbelftools/pull/42))

## 1.1.0 - 2019-01-07

### Added

- `Segments::LoadSegment`, which converts between a file offset and a virtual address
- `Dynamic#tags_by_type`

### Removed

- Ruby 2.2 from the tested versions

## 1.0.2 - 2018-10-25

### Added

- `STT` and `STB` constants
  ([#23](https://github.com/david942j/rbelftools/pull/23))

### Changed

- Dynamic tags are loaded lazily
- Dependencies upgraded

### Removed

- Ruby 2.1 from the tested versions

## 1.0.1 - 2017-10-03

### Fixed

- A bug of big endian
- `method redefined` warning

## 1.0.0 - 2017-10-02

### Added

- ELF patcher. Fields of any header can be assigned, and `ELFFile#save` writes the
  patched file out
- `offset`, the file offset a header was read from, on every header

## 0.2.1 - 2017-05-26

### Changed

- `each_symbols` and `each_notes` return an enumerator when no block is given

## 0.2.0 - 2017-03-17

### Added

- Relocation sections and their entries
- `ELFFile#elf_type`

### Changed

- `sections_by_type` and `segments_by_type` return an enumerator when no block is given

## 0.1.0 - 2017-03-16

### Added

- First release, parsing the ELF header, sections, segments, symbols, dynamic tags,
  and notes, all of them loaded lazily
- `ELFFile#machine` and `ELFFile#build_id`

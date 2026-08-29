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

- `Sections::Symbol#value` and `#size`, the last of what a symbol records that took
  reaching into its header. What a symbol is worth is the address of what it names in a
  file that is loaded, an offset into the section holding it in one that is not, and the
  alignment it needs where the linker is still to place it
  ([#116](https://github.com/david942j/rbelftools/pull/116))

- `Sections::VersionSection`, `VersionNeedSection`, and `VersionDefinitionSection`, the
  `.gnu.version`, `.gnu.version_r`, and `.gnu.version_d` sections recording the very
  versions the tags point at, and `VersionTables`, which reads either view. A symbol read
  from `.dynsym` answers with its version as one read from the tags does
  ([#115](https://github.com/david942j/rbelftools/pull/115))

- `Sections::Symbol#version` and `#version_hidden?`, the version a symbol binds to, which
  tells `memcpy@GLIBC_2.14` from the `memcpy@GLIBC_2.2.5` of the same name. `#name` is
  left as the file records it, without the version appended
  ([#114](https://github.com/david942j/rbelftools/pull/114))
- `Dynamic#version_requirements` and `#version_definitions`, the versions a file needs of
  the files it is loaded with and the versions it defines for what it exports, which
  answer what a file needs without walking its symbols. Both are read from the tags, so a
  file stripped of its sections still records them
  ([#114](https://github.com/david942j/rbelftools/pull/114))
- `Constants::VER_FLG` and `VER_NDX`, and the `Structs::ELF_Verneed`, `ELF_Vernaux`,
  `ELF_Verdef`, and `ELF_Verdaux` structures behind them
  ([#114](https://github.com/david942j/rbelftools/pull/114))

### Fixed

- `sections_by_type` and the other lookups taking a symbol or a string could not name the
  constants keeping the case an ABI wrote them in, so `sections_by_type(:gnu_verneed)`
  raised where `SHT_GNU_verneed` is what defines it
  ([#115](https://github.com/david942j/rbelftools/pull/115))
- `Dynamic#relocations` used to pass over
 the relocations a file packs into a bitmap, the
  ones `DT_RELR` points at, and answer with only the tables `DT_REL`, `DT_RELA`, and
  `DT_JMPREL` record. Of the 3780 loaded files of a current system, 557 pack some of
  theirs that way, and across those 46% of their relocations were missing from the answer,
  `ldconfig` reporting 11 of its 1503
  ([#113](https://github.com/david942j/rbelftools/pull/113))

### Added

- `Sections::RelativeRelocationSection`, the `SHT_RELR` section holding the same
  relocations, and `RelativeRelocations`, which unpacks either of them. An entry is an
  address, or a bitmap of the words following the last address, and records no type of its
  own, so the type reported is the one the machine calls relative
  ([#113](https://github.com/david942j/rbelftools/pull/113))
- `Constants::R.relative`, the type a machine calls a relocation that only adds the load
  bias, which every architecture defining one spells `R_<arch>_RELATIVE`
  ([#113](https://github.com/david942j/rbelftools/pull/113))
- `Sections::Symbol#type=`
, `#bind=`, and `#visibility=`, and `Relocation#type=` and
  `#symbol_index=`, which assign what a value means rather than the bits recording it. Each
  leaves the rest of the byte or field it shares alone, the 64-bit MIPS ABI layout and the
  machine's own half of `st_other` included, and reports a value too large for its bits
  instead of writing it over its neighbours
  ([#112](https://github.com/david942j/rbelftools/pull/112))
- `Util.fits!`, which is what reports it
  ([#112](https://github.com/david942j/rbelftools/pull/112))

### Fixed

- Assigning to a field of a structure a header records, `e_ident` and each of the seven
  fields it holds, used to be dropped without a word. The value read back as assigned and
  `save` wrote the file out unchanged, because only the fields of the outermost structure
  were watched ([#111](https://github.com/david942j/rbelftools/pull/111))
- Patching any field of a big endian file used to write the bytes of that field the wrong
  way round, because the packing was asked of the base structure class, which is ordered
  little endian whatever the file is
  ([#111](https://github.com/david942j/rbelftools/pull/111))

### Changed

- `Structs::ELFStruct#patches` answers with the difference between the bytes a structure
  was read from and the bytes it holds now, as the runs of bytes that differ, instead of a
  log of the assignments made to it. Every field is therefore patchable however deeply it
  is nested, and a field assigned the value it already held leaves nothing behind.
  `Structs::ELFStruct.pack` is no longer how a patch is made, and is deprecated
  ([#111](https://github.com/david942j/rbelftools/pull/111))

## 2.0.0 - 2026-08-24

### Breaking

- `Relocation#r_info_sym` and `#r_info_type` are gone. `#symbol_index` and `#type`, which
  used to be aliases of them, are the names now. They name what the two values mean rather
  than the field they are read out of, which since
  [#97](https://github.com/david942j/rbelftools/pull/97) is not even how every file records
  them: the 64-bit MIPS ABI packs three types and a second symbol index into `r_info`
  instead of halving it ([#110](https://github.com/david942j/rbelftools/pull/110))
- `ELFFile#strtab_section` is `ELFFile#section_name_table`. It answers with the section the
  names of the sections are recorded in, `.shstrtab`, and not with `.strtab`, which records
  the names of the symbols and which `Sections::SymTabSection#symstr` answers with. The
  keyword `Sections::Section` takes for it is `section_name_table:` rather than `strtab:`
  ([#109](https://github.com/david942j/rbelftools/pull/109))
- Ruby 3.3 or later is required ([#85](https://github.com/david942j/rbelftools/pull/85))
- Addresses that occupy memory but have no content in file, `.bss` for instance, are
  not converted into a file offset anymore. This affects `ELFFile#offset_from_vma` and
  `Segments::LoadSegment#vma_in?`, both of which used to return a file offset beyond
  the content of the segment ([#83](https://github.com/david942j/rbelftools/pull/83))
- A dynamic section or segment whose `DT_STRTAB` is missing, or points to an address
  that is not loaded, raises `ELFError` instead of failing with `NoMethodError`
  ([#82](https://github.com/david942j/rbelftools/pull/82))
- `ELFFile#machine` returns the name binutils records for a machine, which reads
  differently than the name returned before. `EM_X86_64` is
  `'Advanced Micro Devices X86-64 processor'` rather than
  `'Advanced Micro Devices X86-64'`, `EM_AARCH64` is `'ARM 64-bit architecture'`
  rather than `'AArch64'`, and `EM_PPC64` is `'64-bit PowerPC'` rather than
  `'PowerPC64'` ([#92](https://github.com/david942j/rbelftools/pull/92))
- Eight `Constants::EM` constants are gone. `EM_486`, `EM_FRV`, `EM_MIPS_RS4_BE`,
  `EM_OPENRISC`, `EM_SHARC`, `EM_TI_ARP32`, and `EM_VPP500` name machines binutils
  spells `EM_IAMCU`, `EM_CYGNUS_FRV`, `EM_MIPS_RS3_LE`, `EM_OR1K`, `EM_res133`,
  `EM_res143`, and `EM_VPP550`. `EM_C116` was a misspelling of `EM_C166`
  ([#92](https://github.com/david942j/rbelftools/pull/92))

### Added

- `ELFFile#vma_from_offset`, the counterpart of `ELFFile#offset_from_vma`
  ([#76](https://github.com/david942j/rbelftools/pull/76))
- `Sections::Symbol#type`, `#bind`, `#visibility`, and `#section_index`, which decode
  `st_info` and `st_other`, together with the `Constants::STV` visibilities
  ([#89](https://github.com/david942j/rbelftools/pull/89))
- `Dynamic#symbol_by_name` looks a name up through `DT_HASH` or `DT_GNU_HASH`, which is what
  the loader itself does, instead of reading every symbol until it finds the name. Neither
  table indexes every symbol, and a file need not record either, so a name a table does not
  lead to is still searched for
  ([#105](https://github.com/david942j/rbelftools/pull/105))
- `Dynamic#symbols`, `#symbol_at`, `#symbol_by_name`, and `#num_symbols`, the symbols the
  tags of a file point at, which is where a file that has been stripped of its sections
  still records them. Nothing a file is loaded by records how large that table is, because
  the loader looks a name up through a hash table and jumps straight to an index rather
  than ever enumerating it, so the count is how far `DT_HASH`, `DT_GNU_HASH`, and the
  relocations reach between them, and is a lower bound where only the latter two answer.
  `#symbol_at` needs no count and is exact for any index
  ([#104](https://github.com/david942j/rbelftools/pull/104))
- `Dynamic#relocations`, the relocations the tags of a file point at, which is where a
  file that has been stripped of its sections still records them. They are read from
  `DT_REL` or `DT_RELA` and from `DT_JMPREL`, and are the same relocations the
  `.rel(a).dyn` and `.rel(a).plt` sections record
  ([#103](https://github.com/david942j/rbelftools/pull/103))
- `ELFFile#dynamic`, the dynamic tags of a file read from the view its type makes
  authoritative. An executable or a shared object is loaded by its segments, so the
  segment answers and the section recording the same tags is metadata; a relocatable
  file has no segments, so its sections do
  ([#102](https://github.com/david942j/rbelftools/pull/102))
- `Sections::Symbol#type_name`, `#bind_name`, and `#visibility_name`, and
  `Constants::Naming` behind them, which names a value after the constants defining it.
  Several may define one, a machine naming a value for itself and a name marking where a
  range begins rather than naming anything, so `STT_ARM_TFUNC` and `STT_SPARC_REGISTER`
  are told apart and `STT_GNU_IFUNC` is named over the `STT_LOOS` it shares a value with
  ([#101](https://github.com/david942j/rbelftools/pull/101))
- 42 more `Constants::EM` constants, `EM_RISCV`, `EM_LOONGARCH`, and `EM_IAMCU` among
  them ([#92](https://github.com/david942j/rbelftools/pull/92))
- `ELFFile#machine` names 229 machines, where it used to name 11 and answer
  `'<unknown>: 0x...'` for every other one, RISC-V included
  ([#92](https://github.com/david942j/rbelftools/pull/92))
- `Constants::R`, the relocation types of 77 architectures, 3579 of them. A relocation
  type only means something together with the architecture that recorded it, the same
  number being `R_X86_64_JUMP_SLOT`, `R_386_JUMP_SLOT`, and `R_ARM_THM_ABS5`, so they
  are grouped as `Constants::R::X86_64`, `Constants::R::I386`, and so on. Each group is
  loaded once it is asked for ([#93](https://github.com/david942j/rbelftools/pull/93))
- `Relocation#type_name`, which names a relocation type after the machine of the file
  it was read from, and `Constants::R.mapping` behind it
  ([#95](https://github.com/david942j/rbelftools/pull/95))

### Fixed

- Every `LazyArray` method but `#[]` used to operate on elements that had not been
  loaded, so `#to_a`, `#map`, and friends returned `nil`s
  ([#84](https://github.com/david942j/rbelftools/pull/84))
- `Relocation#type` and `Relocation#symbol_index` of a 64-bit MIPS file. The ABI packs
  three types and a second symbol index into `r_info` where every other machine leaves
  the halves of it to a type and a symbol index, and orders them the way the file is
  ordered, so both used to return a mix of those fields
  ([#97](https://github.com/david942j/rbelftools/pull/97))

### Changed

- Every iterator is named in the singular, `ELFFile#each_section` and `#each_segment`,
  `Dynamic#each_tag`, `Note#each_note`, `Sections::RelocationSection#each_relocation`, and
  `#each_symbol` of both `Sections::SymTabSection` and `Dynamic`, which is how Ruby names
  the ones it defines itself and agrees with the one thing each of them yields. The plural
  name each used to go by is an alias of it, so nothing that calls one has to change
  ([#108](https://github.com/david942j/rbelftools/pull/108))
- `Dynamic#relocations` reads a table once instead of re-reading it on every call, so the
  relocations it returns are the same objects each time
  ([#106](https://github.com/david942j/rbelftools/pull/106))
- The `bindata` requirement is relaxed to `>= 2, < 4`
  ([#81](https://github.com/david942j/rbelftools/pull/81))
- `Constants::EM` and the names behind `ELFFile#machine` are generated from binutils
  by `bundle exec rake gen:constants`, instead of being maintained by hand. The names
  are only loaded once one is asked for
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

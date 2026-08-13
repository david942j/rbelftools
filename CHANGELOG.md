# Changelog

All notable changes to **elftools** are recorded here.

This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html),
so a change that removes or alters existing API only lands in a major release and
is listed under *Breaking* below.

Releases up to 1.3.1 were announced on the
[releases page](https://github.com/david942j/rbelftools/releases) only, their
entries here are collected from those announcements and from the commit history.

## Unreleased

### Breaking

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

### Fixed

- Every `LazyArray` method but `#[]` used to operate on elements that had not been
  loaded, so `#to_a`, `#map`, and friends returned `nil`s
  ([#84](https://github.com/david942j/rbelftools/pull/84))

### Changed

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

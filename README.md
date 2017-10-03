[![Build Status](https://travis-ci.org/david942j/rbelftools.svg?branch=master)](https://travis-ci.org/david942j/rbelftools)
[![Build Status](https://ci.appveyor.com/api/projects/status/sq5c4gli8ir95h6k?svg=true&retina=true)](https://ci.appveyor.com/project/david942j/rbelftools)
[![Code Climate](https://codeclimate.com/github/david942j/rbelftools/badges/gpa.svg)](https://codeclimate.com/github/david942j/rbelftools)
[![Issue Count](https://codeclimate.com/github/david942j/rbelftools/badges/issue_count.svg)](https://codeclimate.com/github/david942j/rbelftools)
[![Test Coverage](https://codeclimate.com/github/david942j/rbelftools/badges/coverage.svg)](https://codeclimate.com/github/david942j/rbelftools/coverage)
[![Inline docs](https://inch-ci.org/github/david942j/rbelftools.svg?branch=master)](https://inch-ci.org/github/david942j/rbelftools)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](http://choosealicense.com/licenses/mit/)

# rbelftools
Pure ruby library for parsing and patching ELF files.

# Introduction

ELF parser in pure ruby implementation. This work is inspired by [pyelftools](https://github.com/eliben/pyelftools) by [Eli Bendersky](https://github.com/eliben).

The motivation to create this repository is want to be a dependency of [pwntools-ruby](https://github.com/peter50216/pwntools-ruby). Since ELF parser is a big work, it should not be implemented directly in pwntools.

**rbelftools**'s target is to create a nice ELF parsing library in ruby. More features remain a work in progress.

# Install

Available on RubyGems.org!
```bash
gem install elftools
```

# Features

- [x] Supports both big and little endian
- [x] ELF parser
- [x] ELF headers patcher

See example usage for more details.

# Example Usage

## Start from file object
```ruby
require 'elftools'
elf = ELFTools::ELFFile.new(File.open('spec/files/amd64.elf'))
#=> #<ELFTools::ELFFile:0x00560b147f8328 @elf_class=64, @endian=:little, @stream=#<File:spec/files/amd64>>

elf.machine
#=> 'Advanced Micro Devices X86-64'

elf.build_id
#=> '73ab62cb7bc9959ce053c2b711322158708cdc07'
```

## Sections
```ruby
elf.section_by_name('.dynstr')
#=>
# #<ELFTools::Sections::StrTabSection:0x00560b148cef40
# @header=
#  {:sh_name=>86,
#   :sh_type=>3,
#   :sh_flags=>2,
#   :sh_addr=>4195224,
#   :sh_offset=>920,
#   :sh_size=>113,
#   :sh_link=>0,
#   :sh_info=>0,
#   :sh_addralign=>1,
#   :sh_entsize=>0},
# @name=".dynstr">
```
```ruby
elf.sections.map(&:name).join(' ')
#=> " .interp .note.ABI-tag .note.gnu.build-id .gnu.hash .dynsym .dynstr .gnu.version .gnu.version_r .rela.dyn .rela.plt .init .plt .plt.got .text .fini .rodata .eh_frame_hdr .eh_frame .init_array .fini_array .jcr .dynamic .got .got.plt .data .bss .comment .shstrtab .symtab .strtab"
```
```ruby
elf.section_by_name('.note.gnu.build-id').data
#=> "\x04\x00\x00\x00\x14\x00\x00\x00\x03\x00\x00\x00GNU\x00s\xABb\xCB{\xC9\x95\x9C\xE0S\xC2\xB7\x112!Xp\x8C\xDC\a"
```

## Symbols
```ruby
symtab_section = elf.section_by_name('.symtab')
symtab_section.num_symbols
#=> 75

symtab_section.symbol_by_name('puts@@GLIBC_2.2.5')
#=>
# #<ELFTools::Sections::Symbol:0x00560b14af67a0
#  @header={:st_name=>348, :st_info=>18, :st_other=>0, :st_shndx=>0, :st_value=>0, :st_size=>0},
#  @name="puts@@GLIBC_2.2.5">

symbols = symtab_section.symbols # Array of symbols
symbols.map(&:name).reject(&:empty?).first(5).join(' ')
#=> "crtstuff.c __JCR_LIST__ deregister_tm_clones register_tm_clones __do_global_dtors_aux"
```

## Segments
```ruby
elf.segment_by_type(:note)
#=>
# #<ELFTools::Segments::NoteSegment:0x00555beaafe218
# @header=
#  {:p_type=>4,
#   :p_flags=>4,
#   :p_offset=>624,
#   :p_vaddr=>624,
#   :p_paddr=>624,
#   :p_filesz=>68,
#   :p_memsz=>68,
#   :p_align=>4}>

elf.segment_by_type(:interp).interp_name
#=> "/lib64/ld-linux-x86-64.so.2"
```

## Relocations
```ruby
elf = ELFTools::ELFFile.new(File.open('spec/files/amd64.elf'))
# Use relocation to get plt names.
rela_section = elf.sections_by_type(:rela).last
rela_section.name
#=> ".rela.plt"
relocations = rela_section.relocations
relocations.map { |r| '%x' % r.header.r_info }
#=> ["100000007", "200000007", "300000007", "400000007", "500000007", "700000007"]
symtab = elf.section_at(rela_section.header.sh_link) # get the symbol table section
relocations.map { |r| symtab.symbol_at(r.symbol_index).name }
#=> ["puts", "__stack_chk_fail", "printf", "__libc_start_main", "fgets", "scanf"]
```

## Patch

Patch ELF is so easy!

All kinds of headers (i.e. `Ehdr`, `Shdr`, `Phdr`, etc.) can be patched.
Patched slots will not be applied on the opened file.
Invoke `elf.save(filename)` to save the patched ELF into `filename`.

```ruby
elf = ELFTools::ELFFile.new(File.open('spec/files/amd64.elf'))
elf.machine
#=> "Advanced Micro Devices X86-64"
elf.header.e_machine = 40
elf.machine
#=> "ARM"

interp_segment = elf.segment_by_type(:interp)
interp_segment.interp_name
#=> "/lib64/ld-linux-x86-64.so.2"
interp_segment.header.p_filesz
#=> 28
interp_segment.header.p_filesz = 20
interp_segment.interp_name
#=> "/lib64/ld-linux-x86"

# save the patched ELF
elf.save('elf.patched')

# in bash
# $ file elf.patched
# elf.patched: ELF 64-bit LSB executable, ARM, version 1 (SYSV), dynamically linked, interpreter /lib64/ld-linux-x86, for GNU...
```

# Why rbelftools

1. Fully documented   
   Always important for an Open-Source project. Online document is [here](http://www.rubydoc.info/github/david942j/rbelftools/master/frames)
2. Fully tested   
   Of course.
3. Lazy loading on everything   
   To use **rbelftools**, only need to pass the stream object of ELF file.
   **rbelftools** will read the stream object **as least times as possible** when parsing
   the file. Most information will not be fetched until you need it, which makes
   **rbelftools** efficient.
4. To be a library   
   **rbelftools** is designed to be a library for further usage.
   It will _not_ add any too trivial features.
   For example, to check if NX disabled, you can use
   `!elf.segment_by_type(:gnu_stack).executable?` but not `elf.nx?`
5. Section and segment parser   
   Providing common sections and segments parser. For example, `.symtab`, `.shstrtab`
   `.dynamic` sections and `INTERP`, `DYNAMIC` segments, etc.

# Development
```bash
git clone https://github.com/david942j/rbelftools
cd rbelftools
bundle
bundle exec rake
```
Any comments or suggestions are welcome!

# Cross Platform
**rbelftools** can be used and has been fully tested on all platforms include Linux, OSX, and Windows!

# License
MIT License

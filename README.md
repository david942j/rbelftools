[![Downloads](https://img.shields.io/gem/dt/elftools)](https://rubygems.org/gems/elftools)

[![Gem Version](https://badge.fury.io/rb/elftools.svg)](https://badge.fury.io/rb/elftools)
[![Build Status](https://github.com/david942j/rbelftools/workflows/build/badge.svg)](https://github.com/david942j/rbelftools/actions)
[![Maintainability](https://qlty.sh/gh/david942j/projects/rbelftools/maintainability.svg)](https://qlty.sh/gh/david942j/projects/rbelftools)
[![Code Coverage](https://qlty.sh/gh/david942j/projects/rbelftools/coverage.svg)](https://qlty.sh/gh/david942j/projects/rbelftools)
[![Yard Docs](http://img.shields.io/badge/yard-docs-blue.svg)](https://www.rubydoc.info/github/david942j/rbelftools/master)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](http://choosealicense.com/licenses/mit/)

# rbelftools
Pure Ruby library for parsing and patching ELF files.

# Introduction

An ELF parser implemented in pure Ruby. This work is inspired by [pyelftools](https://github.com/eliben/pyelftools) by [Eli Bendersky](https://github.com/eliben).

The original motivation to create this gem is to be a dependency of [pwntools-ruby](https://github.com/peter50216/pwntools-ruby). Since ELF parser is not an easy work, it should not be implemented directly in pwntools.

Now rbelftools is also used by the [Homebrew](https://github.com/Homebrew/brew) project: https://github.com/Homebrew/brew/tree/master/Library/Homebrew/vendor/bundle/ruby/2.6.0/gems/elftools-1.1.3/lib

**rbelftools**'s target is to create a nice ELF parsing library in Ruby. More features remain a work in progress.

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

## Start from a file object
```ruby
require 'elftools'

elf = ELFTools::ELFFile.new(File.open('spec/files/amd64.elf'))
#=> #<ELFTools::ELFFile:0x00560b147f8328 @elf_class=64, @endian=:little, @stream=#<File:spec/files/amd64>>

elf.machine
#=> 'Advanced Micro Devices X86-64 processor'

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

What a symbol refers to and how it is linked are recorded in `st_info` and `st_other`,
values are defined in `ELFTools::Constants::STT`, `STB`, and `STV` respectively.
```ruby
main = symtab_section.symbol_by_name('main')
main.type == ELFTools::Constants::STT_FUNC
#=> true
main.bind == ELFTools::Constants::STB_GLOBAL
#=> true
main.visibility == ELFTools::Constants::STV_DEFAULT
#=> true

# Symbols to be resolved at runtime are not defined in any section.
symtab_section.symbol_by_name('puts@@GLIBC_2.2.5').section_index == ELFTools::Constants::SHN_UNDEF
#=> true
```

Each of those has a name. Several constants may define one value, so naming it takes
the machine of the file, which names some of them for itself.
```ruby
[main.type_name, main.bind_name, main.visibility_name]
#=> ["STT_FUNC", "STB_GLOBAL", "STV_DEFAULT"]

# 13 is a symbol type ARM and SPARC each define, and no one else names.
ELFTools::Constants::STT.mapping(ELFTools::Constants::EM_ARM, 13)
#=> "STT_ARM_TFUNC"
ELFTools::Constants::STT.mapping(ELFTools::Constants::EM_X86_64, 13)
#=> "<unknown>: 0xd"
```

The symbols a file is loaded by are recorded twice, and the tags are the copy the loader
reads, so they answer even when the sections have been stripped away. Naming the symbol a
relocation points at takes nothing but the tags.
```ruby
dynamic = elf.dynamic
dynamic.symbols.map(&:name).reject(&:empty?).first(4).join(' ')
#=> "puts __stack_chk_fail printf __libc_start_main"
dynamic.symbol_by_name('printf').type_name
#=> "STT_FUNC"
dynamic.relocations.map { |rel| dynamic.symbol_at(rel.symbol_index).name }.first(3)
#=> ["__gmon_start__", "stdin", "puts"]
```

A symbol of a file that is loaded binds to a version of the name, which is how one file
offers `memcpy` twice and each caller keeps the one it was built against. The name is left
as the file records it.
```ruby
dynamic.symbol_by_name('printf').version
#=> "GLIBC_2.2.5"
dynamic.symbol_by_name('__stack_chk_fail').version
#=> "GLIBC_2.4"

# What the file needs, without walking a symbol at all.
dynamic.version_requirements.map { |need| [need.file, need.versions.map(&:name)] }
#=> [["libc.so.6", ["GLIBC_2.4", "GLIBC_2.2.5"]]]

# What a library defines, the first naming the library rather than a version of it.
libc = ELFTools::ELFFile.new(File.open('spec/files/libc.so.6'))
libc.dynamic.version_definitions.map(&:name).first(3)
#=> ["libc.so.6", "GLIBC_2.2.5", "GLIBC_2.2.6"]
libc.dynamic.version_definitions[2].parents
#=> ["GLIBC_2.2.5"]
```

Nothing a file is loaded by records how large its symbol table is, because the loader
looks a name up through a hash table and jumps straight to an index rather than ever
enumerating it. `num_symbols` is therefore how far the hash table and the relocations
reach between them, which is a lower bound, while `symbol_at` is exact for any index.
```ruby
dynamic.num_symbols
#=> 9
```

Looking a name up is what the loader does through a hash table, rather than searching the
symbol table for it, and `symbol_by_name` does the same wherever the file records one. A
table only indexes the names a file exports, so a name it does not lead to, and a file
that records no table at all, are searched for instead.
```ruby
libc = ELFTools::ELFFile.new(File.open('spec/files/libc.so.6'))
# Reached through DT_HASH, without reading any of the other 2244 symbols.
libc.dynamic.symbol_by_name('malloc').type_name
#=> "STT_FUNC"
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

Each architecture numbers relocation types on its own, so a type is named after the
machine of the file it was read from.
```ruby
relocations.map(&:type).uniq
#=> [7]
relocations.map(&:type_name).uniq
#=> ["R_X86_64_JUMP_SLOT"]

# The very same number means something else elsewhere.
ELFTools::Constants::R::ARM::R_ARM_THM_ABS5
#=> 7
```

A machine may also lay `r_info` out its own way. Knowing the machine is what tells
those layouts apart, so such a file reads like any other.
```ruby
mips = ELFTools::ELFFile.new(File.open('spec/files/mips64.o'))
relocation = mips.sections_by_type(:rela).first.relocations.first
# The 64-bit MIPS ABI packs three types and a second symbol index in there.
'%x' % relocation.header.r_info
#=> "800051807"
[relocation.symbol_index, relocation.type_name]
#=> [8, "R_MIPS_GPREL16"]
```

A relocation is recorded twice in a file that is loaded, and the tags are the copy the
loader reads, so they answer even when the sections have been stripped away.
```ruby
elf.dynamic.relocations.size
#=> 8
elf.dynamic.relocations.map(&:type_name).uniq
#=> ["R_X86_64_GLOB_DAT", "R_X86_64_COPY", "R_X86_64_JUMP_SLOT"]
```

Nearly every relocation of a file that is loaded only adds the load bias to a word, so a
file may pack them into a bitmap instead of spending an entry on each. They are read with
the rest, from the tags or from the section holding them, and are named after the machine
because the bitmap records no type of its own.
```ruby
packed = ELFTools::ELFFile.new(File.open('spec/files/aarch64.relr.elf'))
packed.dynamic.relocations.count { |rel| rel.type_name == 'R_AARCH64_RELATIVE' }
#=> 132
section = packed.sections_by_type(:relr).first
[section.name, section.header.sh_size, section.num_relocations]
#=> [".relr.dyn", 48, 132]
```

## Patch

Patch ELF is so easy!

All kinds of headers (i.e. `Ehdr`, `Shdr`, `Phdr`, etc.) can be patched.
Patched slots will not be applied on the opened file.
Invoke `elf.save(filename)` to save the patched ELF into `filename`.

```ruby
elf = ELFTools::ELFFile.new(File.open('spec/files/amd64.elf'))
elf.machine
#=> "Advanced Micro Devices X86-64 processor"
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

Values that share a byte with others, which a symbol and a relocation both record, are
assigned as what they mean rather than as the bits holding them. A value too large for
its bits is reported instead of being written over its neighbours.
```ruby
elf = ELFTools::ELFFile.new(File.open('spec/files/amd64.elf'))
symbol = elf.section_by_name('.symtab').symbol_by_name('main')
symbol.type = ELFTools::Constants::STT_OBJECT
symbol.bind = ELFTools::Constants::STB_WEAK
[symbol.type_name, symbol.bind_name]
#=> ["STT_OBJECT", "STB_WEAK"]
symbol.bind = 16
#=> ArgumentError: Symbol binding must be in 0..15, got 16

relocation = elf.dynamic.relocations.first
relocation.symbol_index = 3
relocation.type = ELFTools::Constants::R::X86_64::R_X86_64_JUMP_SLOT
[relocation.symbol_index, relocation.type_name]
#=> [3, "R_X86_64_JUMP_SLOT"]
```

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
   To use **rbelftools**, passing the stream object of an ELF file.
   **rbelftools** will read the stream object **as least times as possible** when parsing
   the file. Most information will not be fetched until you need it, which makes
   **rbelftools** efficient.
4. To be a library   
   **rbelftools** is designed to be a library for further usage.
   It will _not_ add any too trivial features.
   For example, to check whether NX is disabled, **rbelftools** provides
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

Constant tables are generated from [binutils](https://sourceware.org/cgit/binutils-gdb/tree/include/elf/common.h),
regenerate them against the latest revision by
```bash
bundle exec rake gen:constants
```

Any comments or suggestions are welcome!

# Cross Platform
**rbelftools** can be used and has been fully tested on all platforms include Linux, OSX, and Windows!

# License
MIT License

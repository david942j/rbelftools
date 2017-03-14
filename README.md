[![Build Status](https://travis-ci.org/david942j/rbelftools.svg?branch=master)](https://travis-ci.org/david942j/rbelftools)
[![Code Climate](https://codeclimate.com/github/david942j/rbelftools/badges/gpa.svg)](https://codeclimate.com/github/david942j/rbelftools)
[![Issue Count](https://codeclimate.com/github/david942j/rbelftools/badges/issue_count.svg)](https://codeclimate.com/github/david942j/rbelftools)
[![Test Coverage](https://codeclimate.com/github/david942j/rbelftools/badges/coverage.svg)](https://codeclimate.com/github/david942j/rbelftools/coverage)
[![Inline docs](https://inch-ci.org/github/david942j/rbelftools.svg?branch=master)](https://inch-ci.org/github/david942j/rbelftools)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](http://choosealicense.com/licenses/mit/)

# Introduction

ELF parser in pure ruby implementation. This work is inspired by [pyelftools](https://github.com/eliben/pyelftools) by [Eli Bendersky](https://github.com/eliben).

The motivation to create this repository is want to be a dependency of [pwntools-ruby](https://github.com/peter50216/pwntools-ruby). Since ELF parser is a big work, it should not be implemented directly in pwntools.

# Install

Coming soon(?)

# Example Usage

## Start from file object
```ruby
require 'elftools'
elf = ELFTools::ELFFile.new(File.open('spec/files/amd64'))
#=> #<ELFTools::ELFFile:0x00560b147f8328 @elf_class=64, @endian=:little, @stream=#<File:spec/files/amd64>>
```

## Sections
```ruby
elf.section_by_name('.dynstr')
#=>
# #<ELFTools::StrTabSection:0x00560b148cef40
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
elf.seciont_by_name('.note.gnu.build-id').data
#=> "\x04\x00\x00\x00\x14\x00\x00\x00\x03\x00\x00\x00GNU\x00s\xABb\xCB{\xC9\x95\x9C\xE0S\xC2\xB7\x112!Xp\x8C\xDC\a"
```

## Symbols
```ruby
symtab_section = elf.section_by_name('.symtab')
symtab_section.num_symbols
#=> 75

symtab_section.symbol_by_name('puts@@GLIBC_2.2.5')
#=>
# #<ELFTools::Symbol:0x00560b14af67a0
#  @header={:st_name=>348, :st_info=>18, :st_other=>0, :st_shndx=>0, :st_value=>0, :st_size=>0},
#  @name="puts@@GLIBC_2.2.5",

symbols = symtab_section.symbols # Array of ELFTools::Symbol
symbols.map(&:name).reject(&:empty?).first(5).join(' ')
#=> "crtstuff.c __JCR_LIST__ deregister_tm_clones register_tm_clones __do_global_dtors_aux"
```

# Why rbelftools

1. Fully documented

   Always important for an Open-Source project.
2. Fully tested

   Of course.
3. Lazy loading on everything

   To use **rbelftools**, only need to pass the stream object of ELF file.
   **rbelftools** will read the stream object **as least times as possible** when parsing
   this file. Most information will not be fetched until you access it, which makes
   **rbelftools** efficient.
4. To be a library

   **rbelftools** are designed to be a library for furthur usage.
   It will _not_ add any trivial features (e.g. show full/partial/no relro).

# Development
```bash
git clone https://github.com/david942j/rbelftools.git
cd rbelftools
bundle
rake
```
Any comments, suggestions, and pull requests are welcome!

# Platform
**rbelftools** can be used on Linux and OSX.

# License
MIT License

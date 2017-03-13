require 'elftools/elf_file'
describe ELFTools::ELFFile do
  before(:all) do
    filepath = File.join(__dir__, 'files', 'amd64')
    @elf = ELFTools::ELFFile.new(File.open(filepath))
  end

  it 'basic' do
    expect(@elf.elf_class).to be 64
    expect(@elf.endian).to be :little
  end

  it 'file header' do
    expect(@elf.header.e_ident.magic).to eq "\x7FELF"
    expect(@elf.header.e_ident.ei_version).to eq 1
    expect(@elf.header.e_ident.ei_padding).to eq "\x00" * 7
  end

  describe 'sections' do
    it 'basic' do
      expect(@elf.num_sections).to eq 31
    end

    it 'names' do
      expect(@elf.sections.map(&:name)).to eq [''] + %w(
        .interp .note.ABI-tag .note.gnu.build-id .gnu.hash
        .dynsym .dynstr .gnu.version .gnu.version_r
        .rela.dyn .rela.plt .init .plt .plt.got .text
        .fini .rodata .eh_frame_hdr .eh_frame .init_array
        .fini_array .jcr .dynamic .got .got.plt .data .bss
        .comment .shstrtab .symtab .strtab
      )

      expect(@elf.section_by_name('.shstrtab')).to be @elf.strtab_section
    end
  end

  describe 'segments' do
    it 'basic' do
      expect(@elf.num_segments).to eq 9
    end

    it 'data' do
      expect(@elf.segment_at(1).data).to eq "/lib64/ld-linux-x86-64.so.2\x00"
      expect(@elf.segments[1]).to be @elf.segment_at(1)
    end
  end
end

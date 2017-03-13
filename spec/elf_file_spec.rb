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
end

require 'elftools/elffile'
describe ELFTools::ELFFile do
  before(:all) do
    @elf = ELFTools::ELFFile.new(File.open('/bin/cat'))
  end

  it 'simple' do
    expect(@elf.elfclass).to be 64
    expect(@elf.endian).to be :little
  end
end

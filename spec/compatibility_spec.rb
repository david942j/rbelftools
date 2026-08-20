# frozen_string_literal: true

require 'elftools/elf_file'

describe 'the names the iterators used to go by' do
  # Every iterator, paired with the object that answers it. The plural name
  # each one used to go by is an alias of the singular it goes by now, so both
  # have to iterate the same things.
  def iterators
    elf = ELFTools::ELFFile.new(File.open(File.join(__dir__, 'files', 'amd64.elf')))
    { elf => %i[section segment],
      elf.dynamic => %i[tag symbol],
      elf.section_by_name('.symtab') => %i[symbol],
      elf.sections_by_type(:rela).first => %i[relocation],
      elf.section_by_name('.note.ABI-tag') => %i[note] }
  end

  it 'iterates what the names they go by now do' do
    iterators.each do |object, names|
      names.each do |name|
        singular = object.public_send(:"each_#{name}").to_a
        expect(singular).not_to be_empty
        expect(object.public_send(:"each_#{name}s").to_a).to eq singular
      end
    end
  end

  it 'is the very same method under either name' do
    iterators.each do |object, names|
      names.each do |name|
        expect(object.class.instance_method(:"each_#{name}s").original_name).to eq :"each_#{name}"
      end
    end
  end
end

require 'elftools/note'
require 'elftools/sections/section'

module ELFTools
  # Class of note section.
  # Note section records notes
  class NoteSection < Section
    include ELFTools::Note
    # Iterate all notes
    # @param [Block] block Will yield each note.
    # @return [Array<ELFTools::Note::Note>] Array of notes will be returned.
    def each_notes(&block)
      internal_each_notes(stream, header.sh_offset, header.sh_size, header.class.self_endian, &block)
    end

    # Simply +sec.notes+ to get all notes.
    alias notes each_notes
  end
end

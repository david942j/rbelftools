require 'elftools/note'
require 'elftools/segments/segment'

module ELFTools
  # Class of note segment.
  class NoteSegment < Segment
    include ELFTools::Note
    # Iterate all notes
    # @param [Block] block Will yield each note.
    # @return [Array<ELFTools::Note::Note>] Array of notes will be returned.
    def each_notes(&block)
      internal_each_notes(stream, header.p_offset, header.p_filesz, header.class.self_endian, &block)
    end

    # Simply +seg.notes+ to get all notes.
    alias notes each_notes
  end
end

require 'elftools/structures'

module ELFTools
  # Since both note sections and note segments
  # refer to notes, this module defines common
  # methods for {ELFTools::NoteSection} and {ELFTools::NoteSegment}.
  module Note
    # Since size of {ELFTools::ELF_Nhdr} will not change no
    # matter what endian and what arch, so we can do this here.
    SIZE_OF_NHDR = ELF_Nhdr.new(endian: :little).num_bytes
    # Iterate all notes in a note section or segment.
    #
    # Structure of notes are:
    # +---------------+
    # | Note 1 header |
    # +---------------+
    # |  Note 1 name  |
    # +---------------+
    # |  Note 1 desc  |
    # +---------------+
    # | Note 2 header |
    # +---------------+
    # |      ...      |
    # +---------------+
    #
    # @param [File] stream Streaming object.
    # @param [Integer] start Address offset of notes start.
    # @param [Integer] total_size The total size of these notes.
    # @param [Symbol] endian
    #   +:little+ or +:big+.
    #   So sad we have to pass this parameter..
    # @return [Array<ELFTools::Note::Note]
    #   The array of notes will be returned.
    def internal_each_notes(stream, start, total_size, endian)
      @notes_offset_map ||= {}
      cur = start
      notes = []
      while cur < start + total_size
        stream.pos = cur
        cur += SIZE_OF_NHDR
        @notes_offset_map[cur] ||= create_note(endian, stream, cur)
        note = @notes_offset_map[cur]
        name_size = (note.header.n_namesz >> 2) << 2
        desc_size = (note.header.n_descsz >> 2) << 2
        cur += name_size + desc_size
        notes << note
        yield note if block_given?
      end
      notes
    end

    private

    def create_note(endian, stream, cur)
      nhdr = ELF_Nhdr.new(endian: endian).read(stream)
      ELFTools::Note::Note.new(nhdr, stream, cur)
    end

    # Class of a note.
    class Note
      attr_reader :header # @return [ELFTools::ELF_Nhdr] Note header.
      attr_reader :stream # @return [File] Streaming object.

      # Instantiate a {ELFTools::Note::Note} object.
      # @param [ELF_Nhdr] header The note header.
      # @param [File] stream Streaming object.
      # @param [Integer] offset
      #   Start address of this note, exclude the header.
      def initialize(header, stream, offset)
        @header = header
        @stream = stream
        @offset = offset
      end

      # Name of this note.
      # @return [String] The name.
      def name
        return @name if @name
        stream.pos = @offset
        # XXX: Should we remove the last null byte?
        @name = stream.read(header.n_namesz)
      end

      # Description of this note.
      # @return [String] The description.
      def desc
        return @desc if @desc
        stream.pos = @offset + ((header.n_namesz >> 2) << 2)
        @desc ||= stream.read(header.n_descsz)
      end

      # If someone likes to use full name.
      alias description desc
    end
  end
end

require 'elftools/structures'
require 'elftools/util'

module ELFTools
  # Since both note sections and note segments
  # refer to notes, this module defines common
  # methods for {ELFTools::NoteSection} and {ELFTools::NoteSegment}.
  #
  # Notice: this module can only be included in {ELFTools::NoteSection} and
  # {ELFTools::NoteSegment} since some methods assume some attributes already
  # exist.
  module Note
    # Since size of {ELFTools::ELF_Nhdr} will not change no
    # matter what endian and what arch, we can do this here.
    # This value should equal to 12.
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
    # Notice: This method assume following methods exist:
    #   * +stream+
    #   * +note_start+
    #   * +note_total_size+
    # @return [Array<ELFTools::Note::Note]
    #   The array of notes will be returned.
    def each_notes
      @notes_offset_map ||= {}
      cur = note_start
      notes = []
      while cur < note_start + note_total_size
        stream.pos = cur
        @notes_offset_map[cur] ||= create_note(cur)
        note = @notes_offset_map[cur]
        # name and desc size needs to be 4-bytes align
        name_size = Util.align(note.header.n_namesz, 2)
        desc_size = Util.align(note.header.n_descsz, 2)
        cur += SIZE_OF_NHDR + name_size + desc_size
        notes << note
        yield note if block_given?
      end
      notes
    end

    # Simply +#notes+ to get all notes.
    alias notes each_notes

    private

    # Get the endian.
    #
    # Notice: This method assume method +header+ exists.
    # @return [Symbol] +:little+ or +:big+.
    def endian
      header.class.self_endian
    end

    def create_note(cur)
      nhdr = ELF_Nhdr.new(endian: endian).read(stream)
      ELFTools::Note::Note.new(nhdr, stream, cur)
    end

    # Class of a note.
    class Note
      attr_reader :header # @return [ELFTools::ELF_Nhdr] Note header.
      attr_reader :stream # @return [File] Streaming object.
      attr_reader :offset # @return [Integer] Address of this note start, includes note header.

      # Instantiate a {ELFTools::Note::Note} object.
      # @param [ELF_Nhdr] header The note header.
      # @param [File] stream Streaming object.
      # @param [Integer] offset
      #   Start address of this note, includes the header.
      def initialize(header, stream, offset)
        @header = header
        @stream = stream
        @offset = offset
      end

      # Name of this note.
      # @return [String] The name.
      def name
        return @name if @name
        stream.pos = @offset + SIZE_OF_NHDR
        # XXX: Should we remove the last null byte?
        @name = stream.read(header.n_namesz)
      end

      # Description of this note.
      # @return [String] The description.
      def desc
        return @desc if @desc
        stream.pos = @offset + SIZE_OF_NHDR + Util.align(header.n_namesz, 2)
        @desc = stream.read(header.n_descsz)
      end

      # If someone likes to use full name.
      alias description desc
    end
  end
end

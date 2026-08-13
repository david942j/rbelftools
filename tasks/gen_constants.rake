# frozen_string_literal: true

require 'net/http'
require 'uri'

# Generates constant tables from binutils, which tracks the ELF registry more
# closely than the other headers defining the same constants.
namespace :gen do
  BASE_URL = 'https://sourceware.org/cgit/binutils-gdb/tree/include/elf'
  HEADER_URL = 'https://sourceware.org/cgit/binutils-gdb/plain/include/elf/%s'
  COMMAND = 'bundle exec rake gen:constants'

  # +EM_NUM+ is the number of machines defined, +EM_res*+ are values the
  # registry reserves without assigning a machine to them, and +EM_OLD_SPARCV9+
  # is a value that predates the ABI and that the registry reserves as well.
  MACHINE_IGNORED = /\AEM_(NUM|res\d+|OLD_SPARCV9)\z/

  # Constants binutils defines without describing them anywhere. A constant
  # binutils describes is reported so that the entry can be dropped.
  MACHINE_DESCRIPTIONS = {
    'EM_XSTORMY16' => 'Sanyo XStormy16 CPU core'
  }.freeze

  # Definitions kept for compatibility describe themselves as such, and the
  # machine is named after the definition that doesn't.
  SUPERSEDED = /\bold\b|deprecat/i

  # Headers of the +include/elf+ directory that describe no architecture.
  NOT_ARCHITECTURES = %w[common.h dwarf.h external.h internal.h reloc-macros.h].freeze

  # Which architecture relocates a machine, for the machines whose constant is
  # not simply +EM_+ followed by the name of the architecture. binutils records
  # this nowhere, the entries are read off the backends it builds. An entry that
  # names a machine or an architecture that doesn't exist is reported, as is one
  # that has become unnecessary.
  RELOCATES = {
    'EM_386' => :I386,
    'EM_68HC11' => :M68HC11,
    'EM_68HC12' => :M68HC11,
    'EM_68K' => :M68K,
    'EM_860' => :I860,
    'EM_960' => :I960,
    'EM_ADAPTEVA_EPIPHANY' => :EPIPHANY,
    'EM_ALTERA_NIOS2' => :NIOS2,
    'EM_BLACKFIN' => :BFIN,
    'EM_CYGNUS_FRV' => :FRV,
    'EM_CYGNUS_MEP' => :MEP,
    'EM_H8S' => :H8,
    'EM_H8_300' => :H8,
    'EM_H8_300H' => :H8,
    'EM_IA_64' => :IA64,
    'EM_IAMCU' => :I386, # an x86 machine, relocated as one
    'EM_LATTICEMICO32' => :LM32,
    'EM_PARISC' => :HPPA,
    'EM_S370' => :I370,
    'EM_S390_OLD' => :S390,
    'EM_SPARC32PLUS' => :SPARC,
    'EM_SPARCV9' => :SPARC,
    'EM_TI_C6000' => :TIC6X,
    'EM_TI_PRU' => :PRU,
    'EM_WEBASSEMBLY' => :WASM32
  }.freeze

  desc 'Generate constant tables from binutils'
  task :constants do
    definitions = parse(header('common.h'))
    write_machines(definitions)
    write_machine_names(definitions)
    architectures = parse_relocations
    write_relocations(architectures)
    write_relocation_index(architectures.keys, relocates(definitions, architectures.keys))
  end

  # Pairs each machine with the architecture that relocates it, by name where
  # the two agree and by {RELOCATES} where they don't.
  # @return [Array<Array(String, String)>] Machine constants and architectures.
  def relocates(definitions, architectures)
    machines = definitions.to_h { |name, _, _| [name, name.sub(/\AEM_/, '')] }
    pairs = machines.filter_map { |name, arch| [name, arch] if architectures.include?(arch) }.to_h
    RELOCATES.each do |name, architecture|
      raise "#{name} is not a machine, drop it from RELOCATES" unless machines.key?(name)
      raise "#{architecture} relocates nothing, drop it from RELOCATES" unless architectures.include?(architecture.to_s)
      raise "#{name} is paired with #{architecture} by name, drop it from RELOCATES" if pairs[name]

      pairs[name] = architecture.to_s
    end
    pairs.sort
  end

  # Reads every architecture header, which is where relocation types live.
  # @return [Hash{String => Array}] Architecture names and their relocations.
  def parse_relocations
    architectures = {}
    headers.each do |name|
      relocation_blocks(header(name)).each do |block, relocations|
        raise "#{block} is defined by #{name} and by another header" if architectures.key?(block)

        architectures[block] = relocations
      end
    end
    architectures.sort.to_h
  end

  # @return [Array<String>] Name of every header describing an architecture.
  def headers
    local = ENV.fetch('ELF_INCLUDE', nil)
    names = if local
              Dir[File.join(local, '*.h')].map { |path| File.basename(path) }
            else
              fetch(BASE_URL).scan(%r{include/elf/([\w.+-]+\.h)}).flatten
            end
    names = names.uniq.sort - NOT_ARCHITECTURES
    raise 'Found no architecture header, the listing must have changed' if names.empty?

    names
  end

  # Extracts the relocations each +START_RELOC_NUMBERS+ block of a header holds.
  #
  # +RELOC_NUMBER+ records a relocation the linker emits, while +FAKE_RELOC+
  # only marks where a range of them begins or ends.
  # @return [Hash{String => Array<Array(String, Integer, String?)>}]
  def relocation_blocks(text)
    blocks = {}
    current = nil
    text.each_line do |line|
      if (m = line.match(/START_RELOC_NUMBERS\s*\(\s*(\w+)\s*\)/))
        current = architecture_of(m[1])
        blocks[current] = []
      elsif line.match?(/END_RELOC_NUMBERS/)
        current = nil
      elsif current && (m = line.match(%r{RELOC_NUMBER\s*\(\s*(\w+)\s*,\s*(0x\h+|\d+)\s*\)\s*(?:/\*\s*(.+?)\s*\*/)?}))
        blocks[current] << [m[1], parse_int(m[2]), m[3] && normalize(m[3])]
      end
    end
    blocks.reject { |_, relocations| relocations.empty? }
  end

  # Names the architecture a +START_RELOC_NUMBERS+ block stands for.
  # @example
  #   architecture_of('elf_x86_64_reloc_type') #=> 'X86_64'
  # @return [String] The name.
  def architecture_of(block)
    name = block.sub(/\Aelf(32|64)?_/, '').sub(/_reloc_types?\z/, '').upcase
    raise "#{block} does not name an architecture" if name.empty? || !name.match?(/\A[A-Z][A-Z0-9_]*\z/)

    name
  end

  # Reads a header of the +include/elf+ directory, from +ELF_INCLUDE+ when it
  # points at a copy of that directory, downloading it otherwise.
  # @param [String] name Name of the header, +common.h+ for instance.
  # @return [String] The header.
  def header(name)
    local = ENV.fetch('ELF_INCLUDE', nil)
    return File.read(File.join(local, name)) if local

    fetch(format(HEADER_URL, name))
  end

  # Downloads +url+, retrying because the server rejects requests that come in
  # too quickly and gives no hint of how long to hold off.
  # @return [String] The body.
  def fetch(url, attempts: 8)
    delay = 1
    attempts.times do |attempt|
      Net::HTTP.get_response(URI(url)) do |res|
        # A downloaded body is binary, while the file it stands for is text.
        return res.body.dup.force_encoding(Encoding::UTF_8) if res.is_a?(Net::HTTPSuccess)
        raise "Failed to fetch #{url}: #{res.code} #{res.message}" unless res.is_a?(Net::HTTPTooManyRequests)
        raise "Gave up fetching #{url}, still being rate limited" if attempt == attempts - 1
      end
      sleep(delay)
      delay = [delay * 2, 30].min
    end
  end

  # Extracts every +EM_*+ definition and what it is described as.
  #
  # A definition is described by a trailing comment, or by the comment above it
  # when that would not fit. Such a comment describes every definition until the
  # next empty line, so that one comment can introduce a group of them.
  # @return [Array<Array(String, Integer, String?)>]
  #   Constant names, their values, and their descriptions.
  def parse(header)
    definitions = {}
    comment = nil
    each_chunk(header) do |kind, text|
      case kind
      when :comment then comment = normalize(text)
      when :blank then comment = nil
      when :other then comment = nil
      when :define
        name, value, trailing = text
        definitions[name] = [value, trailing ? normalize(trailing) : comment] unless MACHINE_IGNORED.match?(name)
      end
    end
    describe(definitions)
    definitions.map { |name, (value, text)| [name, value, text] }
  end

  # Splits the header into the pieces {#parse} cares about, joining the lines of
  # a comment that spans several of them.
  # @yieldparam [Symbol] kind One of +:define+, +:comment+, +:blank+, +:other+.
  # @yieldparam [Array, String] text The definition or the comment.
  def each_chunk(header)
    pending = nil
    header.each_line do |line|
      if pending
        pending << ' ' << line.strip.sub(%r{\*/.*}, '').strip
        next unless line.include?('*/')

        yield(:comment, pending.strip)
        pending = nil
      elsif (m = line.match(%r{^#define\s+(EM_\w+)\s+(0x\h+|\d+)\s*(?:/\*\s*(.+?)\s*\*/)?}))
        yield(:define, [m[1], parse_int(m[2]), m[3]])
      elsif (m = line.match(%r{^\s*/\*\s*(.*?)\s*\*/\s*$}))
        yield(:comment, m[1])
      elsif (m = line.match(%r{^\s*/\*\s*(.*)$}))
        pending = +m[1]
      elsif line.strip.empty?
        yield(:blank, line)
      else
        yield(:other, line)
      end
    end
  end

  # Fills in the descriptions binutils doesn't carry.
  def describe(definitions)
    MACHINE_DESCRIPTIONS.each do |name, description|
      value, text = definitions[name]
      raise "#{name} is not defined anymore, drop it from MACHINE_DESCRIPTIONS" if value.nil?
      raise "#{name} is described as #{text.inspect} now, drop it from MACHINE_DESCRIPTIONS" if text

      definitions[name] = [value, description]
    end
  end

  # Names each machine, choosing between the definitions that share a value.
  # @return [Array<Array(Integer, String, String)>]
  #   Machine values, the constants naming them, and their names.
  def machine_names(definitions)
    by_value = definitions.group_by { |_, value, _| value }
    by_value.filter_map { |value, defs| (winner = name_of(value, defs)) && [value, winner[0], winner[2]] }
            .sort_by(&:first)
  end

  # Chooses the definition that names the machine of +value+.
  # @return [Array?] The definition, +nil+ if none of them describes it.
  def name_of(value, defs)
    described = defs.reject { |_, _, text| text.nil? }
    return described.first if described.size <= 1

    current = described.reject { |_, _, text| text.match?(SUPERSEDED) }
    current = described if current.empty?
    longest = current.max_by { |_, _, text| text.size }[2].size
    rivals = current.select { |_, _, text| text.size == longest }
    texts = rivals.map { |_, _, text| text }.uniq
    raise "#{value} is described as #{texts.join(' and ')}, they need telling apart" if texts.size > 1

    rivals.first
  end

  # Turns a comment into a name, i.e. plain ASCII without the spacing and the
  # trailing period a sentence in a comment carries.
  # @return [String] The name.
  def normalize(comment)
    name = comment.tr("\u2010-\u2015", '-').squeeze(' ').strip.sub(/\.\z/, '')
    raise "#{name.inspect} is not ASCII, teach #normalize how to spell it" unless name.ascii_only?

    name
  end

  # The header writes values in both decimal and hexadecimal.
  def parse_int(str)
    str.start_with?('0x') ? Integer(str, 16) : Integer(str, 10)
  end

  def write_machines(definitions)
    path = 'lib/elftools/constants/machine.rb'
    sorted = definitions.sort_by { |name, value, _| [value, name] }
    width = sorted.map { |name, _, _| name.size }.max
    values = sorted.map { |_, value, _| number(value).size }.max
    entries = sorted.map do |name, value, description|
      next format('      %-*s = %s', width, name, number(value)) if description.nil?

      format('      %-*s = %-*s # %s', width, name, values, number(value), description)
    end
    write(path, 'Machine architectures, records in +e_machine+.', entries)
    puts "Wrote #{path} (#{sorted.size} constants)"
  end

  def write_machine_names(definitions)
    path = 'lib/elftools/constants/machine_names.rb'
    names = machine_names(definitions)
    entries = ['    # Name of each machine, see {ELFTools::Constants::EM.mapping}.',
               '    # @return [Hash{Integer => String}]',
               '    NAMES = {']
    entries += names.map { |_, constant, name| "      #{constant} => #{quote(name)}," }
    entries[-1] = entries[-1].chomp(',')
    entries << '    }.freeze'
    write(path, nil, entries.map { |line| "  #{line}" }, requires: 'elftools/constants/machine')
    puts "Wrote #{path} (#{names.size} machines)"
  end

  # Writes one file per architecture, plus the index that loads them on demand.
  def write_relocations(architectures)
    architectures.each do |architecture, relocations|
      path = "lib/elftools/constants/relocation/#{architecture.downcase}.rb"
      sorted = relocations.sort_by { |name, value, _| [value, name] }
      width = sorted.map { |name, _, _| name.size }.max
      # Only the names are aligned, an architecture may describe some of its
      # relocations and leave the rest without a comment to align with.
      entries = sorted.map do |name, value, description|
        # Most architectures describe none of their relocations, and a bare
        # number is nothing to document.
        format('        %-*s = %s # %s', width, name, number(value), description || ':nodoc:')
      end
      write_relocation(path, architecture, entries)
    end
    puts "Wrote lib/elftools/constants/relocation (#{architectures.size} architectures, " \
         "#{architectures.values.sum(&:size)} relocations)"
  end

  def write_relocation(path, architecture, entries)
    File.write(path, <<~RUBY)
      # frozen_string_literal: true

      # This file is generated by `#{COMMAND}`, do not edit it.
      # Source: #{BASE_URL}

      module ELFTools
        module Constants
          module R
            # Relocation types of #{architecture}.
            module #{architecture}
      #{entries.join("\n")}
            end
          end
        end
      end
    RUBY
  end

  def write_relocation_index(architectures, relocates)
    path = 'lib/elftools/constants/relocation.rb'
    width = architectures.map(&:size).max
    entries = architectures.map do |architecture|
      format("      autoload %-*s 'elftools/constants/relocation/%s'", width + 2, ":#{architecture},",
             architecture.downcase)
    end
    entries << ''
    entries << '      # The architecture that relocates each machine.'
    entries << '      # @return [Hash{Integer => Symbol}]'
    entries << '      MACHINES = {'
    # +EM+ is qualified because this file is loaded before its constants are
    # made available to the whole of +Constants+.
    entries += relocates.map { |machine, architecture| "        EM::#{machine} => :#{architecture}," }
    entries[-1] = entries[-1].chomp(',')
    entries << '      }.freeze'
    File.write(path, <<~RUBY)
      # frozen_string_literal: true

      require 'elftools/constants/machine'

      # This file is generated by `#{COMMAND}`, do not edit it.
      # Source: #{BASE_URL}

      module ELFTools
        module Constants
          # Relocation types, recorded in the +r_info+ of a relocation.
          #
          # Every architecture numbers them on its own, so they are grouped by
          # architecture and only loaded once one of the groups is asked for.
          module R
      #{entries.join("\n")}
          end
        end
      end
    RUBY
  end

  # Writes a generated file defining +ELFTools::Constants::EM+.
  # @param [String?] requires What the file needs to be loaded on its own.
  def write(path, doc, entries, requires: nil)
    File.write(path, <<~RUBY)
      # frozen_string_literal: true
      #{requires ? "\nrequire '#{requires}'\n" : ''}
      # This file is generated by `#{COMMAND}`, do not edit it.
      # Source: #{BASE_URL}

      module ELFTools
        module Constants
      #{doc ? "    # #{doc}\n" : ''}    module EM
      #{entries.join("\n")}
          end
        end
      end
    RUBY
  end

  # Writes as Rubocop wants it, i.e. long numbers are grouped by thousands.
  def number(value)
    return value.to_s if value < 10_000

    value.to_s.reverse.scan(/\d{1,3}/).join('_').reverse
  end

  # Quotes as Rubocop wants it, i.e. single quotes unless escaping is needed.
  def quote(str)
    str.match?(/['\\]/) ? str.inspect : "'#{str}'"
  end
end

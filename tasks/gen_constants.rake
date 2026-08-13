# frozen_string_literal: true

require 'net/http'
require 'uri'

# Generates constant tables from binutils, which tracks the ELF registry more
# closely than the other headers defining the same constants.
namespace :gen do
  HEADER_URL = 'https://sourceware.org/cgit/binutils-gdb/plain/include/elf/common.h'
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

  desc 'Generate constant tables from binutils'
  task :constants do
    definitions = parse(fetch_header)
    write_machines(definitions)
    write_machine_names(definitions)
  end

  # Reads the header from +HEADER+ when given, downloads it otherwise.
  def fetch_header
    local = ENV.fetch('HEADER', nil)
    return File.read(local) if local

    puts "Fetching #{HEADER_URL}"
    Net::HTTP.get_response(URI(HEADER_URL)) do |res|
      raise "Failed to fetch the header: #{res.code} #{res.message}" unless res.is_a?(Net::HTTPSuccess)

      # A downloaded body is binary, while the file it stands for is text.
      return res.body.dup.force_encoding(Encoding::UTF_8)
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
  # @return [Array<Array(Integer, String)>] Machine values and their names.
  def machine_names(definitions)
    by_value = definitions.group_by { |_, value, _| value }
    by_value.filter_map { |value, defs| (name = name_of(value, defs)) && [value, name] }.sort
  end

  # @return [String?] What the machine of +value+ is named, +nil+ if unnamed.
  def name_of(value, defs)
    described = defs.filter_map { |_, _, text| text }
    return described.first if described.size <= 1

    current = described.reject { |text| text.match?(SUPERSEDED) }
    current = described if current.empty?
    longest = current.max_by(&:size).size
    rivals = current.select { |text| text.size == longest }.uniq
    raise "#{value} is described as #{rivals.join(' and ')}, they need telling apart" if rivals.size > 1

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
    entries += names.map { |value, name| "      #{number(value)} => #{quote(name)}," }
    entries[-1] = entries[-1].chomp(',')
    entries << '    }.freeze'
    write(path, nil, entries.map { |line| "  #{line}" })
    puts "Wrote #{path} (#{names.size} machines)"
  end

  # Writes a generated file defining +ELFTools::Constants::EM+.
  def write(path, doc, entries)
    File.write(path, <<~RUBY)
      # frozen_string_literal: true

      # This file is generated by `#{COMMAND}`, do not edit it.
      # Source: #{HEADER_URL}

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

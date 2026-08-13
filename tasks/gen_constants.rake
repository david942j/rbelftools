# frozen_string_literal: true

require 'net/http'
require 'uri'

# Generates constant tables from binutils, which tracks the ELF registry more
# closely than the other headers defining the same constants.
namespace :gen do
  HEADER_URL = 'https://sourceware.org/cgit/binutils-gdb/plain/include/elf/common.h'
  COMMAND = 'bundle exec rake gen:constants'

  # Names that rbelftools has been returning before binutils was used as the
  # source, kept so that {ELFTools::ELFFile#machine} keeps returning them.
  # Every entry must name a machine binutils names differently, a stale one is
  # reported instead of being applied silently.
  MACHINE_OVERRIDES = {
    0 => 'None',                              # binutils: No machine
    6 => 'Intel 80386',                       # EM_486, binutils: Intel MCU
    8 => 'MIPS R3000',                        # binutils: MIPS R3000 (officially, big-endian only)
    10 => 'MIPS R3000 little-endian',         # binutils records a draft date and deprecation here
    21 => 'PowerPC64',                        # binutils: 64-bit PowerPC
    50 => 'Intel IA-64',                      # binutils: Intel IA-64 Processor
    62 => 'Advanced Micro Devices X86-64',    # binutils: Advanced Micro Devices X86-64 processor
    183 => 'AArch64'                          # binutils: ARM 64-bit architecture
  }.freeze

  # Machines binutils reserves but doesn't name, taken from glibc's elf.h.
  # Hardcoded rather than fetched, glibc names only these two of the 40+
  # values binutils reserves. Once binutils names one of them, it is reported
  # so that the entry can be dropped or turned into an override.
  MACHINE_EXTRAS = {
    133 => 'Analog Devices SHARC family',     # EM_SHARC, binutils: EM_res133
    143 => 'Texas Instruments App. Specific RISC' # EM_TI_ARP32, binutils: EM_res143
  }.freeze

  # +EM_NUM+ is the number of machines defined, +EM_res*+ are values the
  # registry reserves without assigning a machine to them, and +EM_OLD_SPARCV9+
  # is a value that predates the ABI and that the registry reserves as well.
  MACHINE_IGNORED = /\AEM_(NUM|res\d+|OLD_SPARCV9)\z/

  # Constants rbelftools has been defining before binutils was used as the
  # source. Kept so that no constant disappears, either because binutils spells
  # a machine differently or because it doesn't define it at all. A name
  # binutils defines is reported instead of being shadowed.
  MACHINE_ALIASES = {
    'EM_486' => [6, 'Intel 80486'],                                  # binutils: EM_IAMCU
    'EM_MIPS_RS4_BE' => [10, 'MIPS R4000 big-endian'],               # binutils: EM_MIPS_RS3_LE
    'EM_VPP500' => [17, 'Fujitsu VPP500'],                           # binutils: EM_VPP550
    'EM_OPENRISC' => [0x5c, 'OpenRISC 1000 32-bit embedded processor'], # binutils: EM_OR1K
    'EM_SHARC' => [133, 'Analog Devices SHARC family'],              # binutils: EM_res133
    'EM_TI_ARP32' => [143, 'Texas Instruments App. Specific RISC'],  # binutils: EM_res143
    'EM_FRV' => [0x5441, 'Fujitsu FR-V']                             # binutils: EM_CYGNUS_FRV
  }.freeze

  # Constants binutils defines without describing them, either because it
  # describes several of them at once or not at all. A constant binutils
  # describes is reported so that the entry can be dropped.
  MACHINE_DESCRIPTIONS = {
    'EM_XSTORMY16' => 'Sanyo XStormy16 CPU core',
    'EM_CYGNUS_MN10300' => 'Matsushita MN10300 backend magic number',
    'EM_CYGNUS_MN10200' => 'Matsushita MN10200 backend magic number'
  }.freeze

  # A few machines are defined twice, usually because a name was superseded but
  # kept for compatibility. The definition to take the name from is recorded
  # here, a value defined twice without an entry is reported.
  MACHINE_PREFERRED = {
    17 => 'EM_VPP550',    # EM_PPC_OLD is deprecated
    39 => 'EM_MCORE',     # EM_RCE is the old name of it
    95 => 'EM_VIDEOCORE', # EM_SCORE_OLD is deprecated
    99 => 'EM_SNP1K',     # EM_PJ_OLD is deprecated
    115 => 'EM_XGATE',    # EM_CR16_OLD is deprecated
    135 => 'EM_SCORE7',   # EM_SCORE names the same family less precisely
    168 => 'EM_ECOG1X'    # EM_ECOG1 records the very same machine
  }.freeze

  desc 'Generate constant tables from binutils'
  task :constants do
    header = fetch_header
    write_machines(parse_constants(header))
    write_machine_names(parse_machines(header))
  end

  # Extracts every +EM_*+ definition, the constants themselves rather than the
  # machines they name.
  # @return [Array<Array(String, Integer, String)>]
  #   Constant names, their values, and what they stand for.
  def parse_constants(header)
    constants = {}
    # A definition is described either by a trailing comment or, when that
    # would not fit, by a comment on its own line right above it.
    preceding = nil
    header.each_line do |line|
      if (m = line.match(%r{^#define\s+(EM_\w+)\s+(0x\h+|\d+)\s*(?:/\*\s*(.+?)\s*\*/)?}))
        constants[m[1]] = [parse_int(m[2]), m[3] ? normalize(m[3]) : preceding] unless MACHINE_IGNORED.match?(m[1])
        preceding = nil
      elsif (c = line.match(%r{^\s*/\*\s*(.+?)\s*\*/\s*$}))
        preceding = normalize(c[1])
      elsif !line.strip.empty?
        preceding = nil
      end
    end
    MACHINE_DESCRIPTIONS.each do |name, description|
      value, comment = constants[name]
      raise "#{name} is not defined anymore, drop it from MACHINE_DESCRIPTIONS" if value.nil?
      raise "#{name} is described as #{comment.inspect} now, drop it from MACHINE_DESCRIPTIONS" if comment

      constants[name] = [value, description]
    end
    MACHINE_ALIASES.each do |name, (value, comment)|
      raise "#{name} is defined by binutils now, drop it from MACHINE_ALIASES" if constants.key?(name)

      constants[name] = [value, comment]
    end
    constants.sort_by { |name, (value, _)| [value, name] }.map { |name, (value, comment)| [name, value, comment] }
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

  # Extracts +EM_*+ definitions and the name recorded in their trailing comment.
  # @return [Array<Array(Integer, String)>] Machine values and their names.
  def parse_machines(header)
    defines = Hash.new { |hash, value| hash[value] = {} }
    header.each_line do |line|
      next unless (m = line.match(%r{^#define\s+(EM_\w+)\s+(0x\h+|\d+)\s*/\*\s*(.+?)\s*\*/}))
      next if MACHINE_IGNORED.match?(m[1])

      defines[parse_int(m[2])][m[1]] = normalize(m[3])
    end
    machines = defines.to_h { |value, names| [value, pick(value, names)] }
    stale = MACHINE_PREFERRED.keys - defines.select { |_, names| names.size > 1 }.keys
    raise "#{stale.join(', ')} are not defined twice anymore, drop them from MACHINE_PREFERRED" if stale.any?

    apply(machines, MACHINE_OVERRIDES, expected: true)
    apply(machines, MACHINE_EXTRAS, expected: false)
    machines.sort
  end

  # Chooses which definition of +value+ names it.
  # @param [Hash{String => String}] names Every definition of +value+.
  # @return [String] The name.
  def pick(value, names)
    return names.values.first if names.size == 1

    preferred = MACHINE_PREFERRED[value]
    raise "#{value} is defined by #{names.keys.join(' and ')}, add it to MACHINE_PREFERRED" if preferred.nil?
    raise "#{value} is not defined by #{preferred} anymore, update MACHINE_PREFERRED" unless names.key?(preferred)

    names[preferred]
  end

  # Applies hand maintained entries, raising when one of them no longer
  # describes what the source defines.
  # @param [Boolean] expected Whether the source is expected to define the entry.
  def apply(machines, entries, expected:)
    entries.each do |value, name|
      defined = machines.key?(value)
      raise "#{value} is not defined anymore, drop it from MACHINE_OVERRIDES" if expected && !defined
      raise "#{value} is named now, move it to MACHINE_OVERRIDES" if !expected && defined
      raise "#{value} is already named #{name.inspect}, drop it from the overrides" if machines[value] == name

      machines[value] = name
    end
  end

  # Turns a comment into a name, i.e. plain ASCII without the spacing and the
  # trailing period a sentence in a comment carries.
  # @return [String] The name.
  def normalize(comment)
    # U+2010 to U+2015 are the dashes, which comments occasionally use.
    name = comment.tr("\u2010-\u2015", '-').squeeze(' ').sub(/\.\z/, '')
    raise "#{name.inspect} is not ASCII, teach #normalize how to spell it" unless name.ascii_only?

    name
  end

  # The header writes values in both decimal and hexadecimal.
  def parse_int(str)
    str.start_with?('0x') ? Integer(str, 16) : Integer(str, 10)
  end

  def write_machines(constants)
    path = 'lib/elftools/constants/machine.rb'
    width = constants.map { |name, _, _| name.size }.max
    values = constants.map { |_, value, _| number(value).size }.max
    entries = constants.map do |name, value, comment|
      next format('      %-*s = %s', width, name, number(value)) if comment.nil?

      format('      %-*s = %-*s # %s', width, name, values, number(value), comment)
    end
    File.write(path, <<~RUBY)
      # frozen_string_literal: true

      # This file is generated by `#{COMMAND}`, do not edit it.
      # Source: #{HEADER_URL}

      module ELFTools
        module Constants
          # Machine architectures, records in +e_machine+.
          module EM
      #{entries.join("\n")}
          end
        end
      end
    RUBY
    puts "Wrote #{path} (#{constants.size} constants)"
  end

  def write_machine_names(machines)
    path = 'lib/elftools/constants/machine_names.rb'
    entries = machines.map { |val, name| "        #{number(val)} => #{quote(name)}" }
    File.write(path, <<~RUBY)
      # frozen_string_literal: true

      # This file is generated by `#{COMMAND}`, do not edit it.
      # Source: #{HEADER_URL}

      module ELFTools
        module Constants
          module EM
            # Name of each machine, see {ELFTools::Constants::EM.mapping}.
            # @return [Hash{Integer => String}]
            NAMES = {
      #{entries.join(",\n")}
            }.freeze
          end
        end
      end
    RUBY
    puts "Wrote #{path} (#{machines.size} machines)"
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

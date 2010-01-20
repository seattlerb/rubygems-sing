require 'rubygems/command'
require 'rubygems/version_option'
require 'rubygems/text'

require 'midiator'

##
# gem command to "sing" the implementation of a gem.

class Gem::Commands::SingCommand < Gem::Command
  VERSION = '1.0.0'

  include MIDIator::Notes
  include MIDIator::Drums

  include Gem::VersionOption
  # include Gem::Text

  def initialize
    super("sing", "\"Sing\" a gem's implementation",
          :version => Gem::Requirement.default)

    add_version_option
  end

  def arguments # :nodoc:
    'GEMNAME       name of an installed gem to sing'
  end

  def defaults_str # :nodoc:
    "--version='>= 0'"
  end

  def usage # :nodoc:
    "#{program_name} GEMNAME [options]"
  end

  def execute
    name = get_one_gem_name

    dep = Gem::Dependency.new name, options[:version]
    specs = Gem.source_index.search dep

    if specs.empty? then
      alert_error "No installed gem #{dep}"
      terminate_interaction 1
    end

    spec = specs.last
    base = spec.full_gem_path

    ##
    # Special thanks to Ben Bleything for midiator and help getting
    # this up and running!

    midi = MIDIator::Interface.new
    midi.use :dls_synth

    scale = [ C4, Cs4, D4, Eb4, E4, F4, Fs4, G4, Gs4, A4, Bb4, B4,
              C5, Cs5, D5, Eb5, E5, F5, Fs5, G5, Gs5, A5, Bb5, B5 ]

    midi.control_change 32, 10, 1 # TR-808 is Program 26 in LSB bank 1
    midi.program_change 10, 26

    # TODO: eventually add ability to play actual AST

    spec.lib_files.each do |path|
      full_path = File.join base, path
      warn path
      File.foreach(full_path) do |line|
        if line =~ /^(\s+)end$/ then
          num_spaces = $1.size
          midi.play scale[ num_spaces / 2 ]
          print line
        end
      end

      [ HighTom1, HighTom2, LowTom1, LowTom2 ].each do |note|
        midi.play note, 0.067, 10
      end

      midi.play CrashCymbal1, 0.25, 10
    end

    midi.play CrashCymbal2, 0.25, 10
    sleep 1.0
  end
end

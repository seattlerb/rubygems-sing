# -*- coding: utf-8 -*-
require 'rubygems/command'
require 'rubygems/version_option'
require 'rubygems/text'
require 'rubygems/installer'

require 'midiator'
require 'English'

##
# gem command to "sing" the implementation of a gem.

class Gem::Commands::SingCommand < Gem::Command
  VERSION = '1.1.0'

  include MIDIator::Notes
  include MIDIator::Drums

  include Gem::VersionOption
  include Gem::LocalRemoteOptions

  def initialize
    super("sing", "\"Sing\" a gem's implementation",
          :version => Gem::Requirement.default)

    add_version_option
    add_local_remote_options
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

    base = files = nil

    if remote? then
      version = options[:version] || Gem::Requirement.default
      all = Gem::Requirement.default
      dep = Gem::Dependency.new name, version

      specs_and_sources = Gem::SpecFetcher.fetcher.fetch dep

      spec, source_uri = specs_and_sources.sort_by { |spec,| spec.version }.last

      alert_error "Could not find #{name} in any repository" unless spec

      gem_path = File.join "/tmp", spec.file_name

      unless File.file? gem_path then
        path = Gem::RemoteFetcher.fetcher.download spec, source_uri
        FileUtils.mv path, gem_path
      end

      dir_path = File.join "/tmp", File.basename(gem_path, '.gem')

      unless File.directory? dir_path then
        FileUtils.mkdir_p dir_path
        Gem::Installer.new(gem_path, :unpack => true).unpack dir_path
      end

      Dir.chdir dir_path do
        files = spec.require_paths.map { |d| Dir["#{d}/**/*.rb"] }.flatten.sort
      end

      base = dir_path
    else
      dep = Gem::Dependency.new name, options[:version]
      specs = Gem.source_index.search dep

      if specs.empty? then
        alert_error "No installed gem #{dep}"
        terminate_interaction 1
      end

      spec  = specs.last
      base  = spec.full_gem_path
      files = spec.lib_files
    end

    $stdout.sync = true

    ##
    # Special thanks to Ben Bleything for midiator and help getting
    # this up and running!

    midi = MIDIator::Interface.new
    midi.use :dls_synth

    # blues scale
    scale = [ C4, Eb4, F4, Fs4, G4, Bb4,
              C5, Eb5, F5, Fs5, G5, Bb5,
              C6, Eb6, F6, Fs6, G6, Bb6 ]

    midi.control_change 32, 10, 1 # TR-808 is Program 26 in LSB bank 1
    midi.program_change 10, 26

    # TODO: eventually add ability to play actual AST

    files.each do |path|
      full_path = File.join base, path

      next unless File.file? full_path # rails is run by MORONS

      warn path

      line_number_of_last_end = 0
      File.foreach full_path do |line|
        if line =~ /^(\s+)end$/ then
          distance = $INPUT_LINE_NUMBER - line_number_of_last_end
          note_character = "♩"
          duration = case distance
                     when 0 .. 3
                       note_character = "♪"
                       0.125
                     when 4 .. 10
                       note_character = "♩"
                       0.25
                     when 11 .. 30
                       note_character = "d"
                       0.5
                     else
                       note_character = "o"
                       1.0
                     end
          line_number_of_last_end = $INPUT_LINE_NUMBER
          num_spaces = $1.size

          print "#{note_character} "
          print line
          midi.play scale[ num_spaces / 2 ], duration
          print "\n" * (duration * 4).to_i if Gem.configuration.really_verbose
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

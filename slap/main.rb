#
# Main entry point and parsing
#
#
# Glossary
#
# | term       | meaning                            | example                   |
# |------------|------------------------------------|---------------------------|
# | flag       | configured cli flag                | o.int "-p", "--port"      |
# | switch     | dashed string invoking a flag      | -p or --port              |
# | key        | result field derived from a switch | --http-port => :http_port |
# | param      | raw input consumed by a flag       | 8080 from --port=8080     |
# | -          | -                                  | -                         |
# | app_name   | program name used in output        | "curl"                    |
# | banner     | usage text at top of help          | Usage: curl [options]     |
# | meta       | placeholder shown for a param      | <xxx> from `--port <xxx>` |
# | positional | configured required param slot     | o.positional "<url>"      |
# | separator  | help section heading               | "Network:"                |
#

module Slap
  class Error < StandardError; end

  # early exits
  class HelpRequested < Exception; end # rubocop:disable Lint/InheritException
  class NakedRequested < Exception; end # rubocop:disable Lint/InheritException
  class VersionRequested < Exception; end # rubocop:disable Lint/InheritException

  # main entry point
  def self.parse(argv = ARGV)
    Main.new.tap { yield _1.config if block_given? }.parse(argv)
  end

  class Main
    attr_reader :config

    def initialize
      @config = Config.new
    end

    # Parse argv and turn internal parser outcomes into CLI behavior.
    def parse(argv)
      config.prepare!

      begin
        options = Parser.new(config).parse(argv)
        OpenStruct.new(options).freeze
      rescue Error => ex
        warn "#{app_name}: #{ex.message}"
        warn "#{app_name}: try '#{app_name} --help' for more information"
        do_exit(1, error: ex.message)
      rescue HelpRequested, NakedRequested, VersionRequested => ex
        case ex
        when HelpRequested
          puts Help.new(config)
        when NakedRequested
          puts "#{app_name}: try '#{app_name} --help' for more information"
        when VersionRequested
          puts "#{app_name} #{config.version}"
        end
        do_exit
      end
    end

    protected

    def do_exit(status = 0, error: nil)
      if (fn = config.exit)
        (fn.arity == 2) ? fn.call(status, error) : fn.call(status)
      else
        exit(status)
      end
      nil
    end

    # one-liners
    def app_name = config.app_name
  end
end

# BUG: Slap-shaped code loses String#lines in help test.
# https://github.com/matz/spinel/issues/3403
# Bad line: `text.lines` after help text is rendered.
# Ruby: iterates lines.
# Spinel: raises undefined method lines for String.

require "ostruct"
require "stringio"
module Slap
  class Config

    attr_reader :flags
    def initialize

      @flags, @positionals, @separators = [], [], []
    end
    def str()
      add_flag(1)
    end

    def prepare!
      add_builtin(1, 1)
    end
    def add_builtin(switches, help_text)
      add_flag(1)
    end
    def add_flag(flag)
      flags << flag
    end
  end
end

module Slap
  class Help
    attr_reader :config
    def initialize(config)
      @config = config
    end
    def to_s
      return  if nil
      buf = StringIO.new
      buf << "\n\n"
      config.flags.each.with_index do
        buf << "\n"
      end
      buf.string
    end

  end
end
config = Slap::Config.new
config.str
config.prepare!
text = Slap::Help.new(config).to_s
count = 0
text.lines.each { count += 1 }
# keep
raise "FAIL #{count}" unless count == 4

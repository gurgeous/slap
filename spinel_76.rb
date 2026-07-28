
require "io/console"
require "ostruct"
require "pathname"
require "stringio"

module Slap
  class Color
    attr_reader :enabled
    alias_method :enabled?, :enabled

    def initialize(enabled)
      @enabled = enabled.nil? ? $stdout.tty? : enabled
    end

    def blue(str) = paint(str, 34)
    def cyan(str) = paint(str, 36)
    def green(str) = paint(str, 32)
    def magenta(str) = paint(str, 35)
    def red(str) = paint(str, 31)
    def yellow(str) = paint(str, 33)

    protected

    def paint(str, code)
      enabled? ? "\e[1;#{code}m#{str}\e[0m" : str
    end
  end
end

module Slap
  class Config
    attr_accessor :app_name, :banner, :color, :exit, :help, :naked, :version
    attr_reader :flags, :help_flag, :lookup, :positionals, :separators, :version_flag
    alias_method :naked?, :naked

    def initialize
      @app_name = File.basename($PROGRAM_NAME)
      @naked = true
      @lookup = {}
      @flags, @positionals, @separators = [], [], []
    end

    def pos(meta, help = "")
      Positional.new(meta:, help:).tap do
        raise ArgumentError, "duplicate positional #{_1.key}" if key?(_1.key)
        positionals << _1
        lookup[_1.key] = _1
      end
    end

    def sep(text = "")
      [flags.length, text].tap do
        separators << _1
      end
    end

    def bool(*opts, default: nil, required: false)
      add_flag(Flag.new(:bool, opts, default:, required:))
    end

    def int(*opts, default: nil, required: false, choices: nil)
      add_flag(Flag.new(:int, opts, default:, required:, choices:))
    end

    def str(*opts, default: nil, required: false, choices: nil)
      add_flag(Flag.new(:str, opts, default:, required:, choices:))
    end

    alias_method :positional, :pos
    alias_method :separator, :sep

    def defaults
      flags.filter_map do
        next if _1.required || _1 == help_flag || _1 == version_flag
        [_1.key, _1.default]
      end.to_h
    end

    def flag(switch) = lookup[switch]
    def flag?(switch) = lookup.key?(switch)
    def key?(key) = lookup.key?(key)
    def required = flags.select(&:required?)

    def prepare!
      return if @prepared
      @prepared = true
      @exit ||= lambda { |status| Kernel.exit(status) }
      @help_flag = add_builtin(["-h", "--help"], "Show this message")
      @version_flag = add_builtin(["-v", "--version"], "Show version") if version
    end

    protected

    def add_builtin(switches, help_text)
      unused = switches.select { !flag?(_1) }
      return if unused.empty?
      add_flag(Flag.new(:bool, unused + [help_text]))
    end

    def add_flag(flag)
      raise ArgumentError, "reserved flag key: _args" if flag.key == :_args
      raise ArgumentError, "dup flag key: #{flag.key}" if key?(flag.key)
      flag.switches.each do
        raise ArgumentError, "dup flag switch: #{_1}" if flag?(_1)
      end

      flags << flag
      lookup[flag.key] = flag
      flag.switches.each { lookup[_1] = flag }

      flag
    end
  end
end

module Slap
  class Flag
    SWITCH_RE = /\A-(\w|-\w[\w-]*)\z/
    INLINE_RE = /\A-(\w|-\w[\w-]*)=(.*)\z/m
    NEGATE_RE = /\A--no-(\w[\w-]*)\z/

    KINDS = %i[bool int str]

    attr_reader :choices, :default, :help, :kind, :meta, :required, :switches

    def initialize(kind, opts, default: nil, required: false, choices: nil)
      @choices, @kind, @required = choices, kind, required

      @switches = opts.dup
      @help = if switch && !switch.start_with?("-")
        switches.pop
      end

      @meta = build_meta

      @default = default
      if bool? && default.nil? && !required?
        @default = false
      end

      validate
    end

    def parse(switch, param)
      if bool?
        raise Error, "option '#{switch}=#{param}' does not take a value" if param
        return true
      end

      raise Error, "option '#{switch}' requires a value" if !param
      parsed = begin
        case kind
        when :int then Integer(param, 10)
        when :str then param
        end
      rescue ArgumentError
        raise Error, "invalid value '#{param}' for option '#{switch}'"
      end

      if choices && !choices.include?(parsed)
        raise Error, "invalid value '#{parsed}' for option '#{switch}', must be one of #{choices.join(", ")}"
      end
      parsed
    end

    def label(color)
      label = switches.map { color.green(_1) }.join(", ")
      return label unless takes_param?
      "#{label} #{color.yellow("<#{meta}>")}"
    end

    def bool? = kind == :bool
    def key = @key ||= switch.sub(/^-+/, "").tr("-", "_").to_sym
    def switch = switches.last
    def takes_param? = !bool?
    alias_method :required?, :required

    protected

    def validate
      raise ArgumentError, "at least one switch is required" if switches.empty?
      switches.each do
        raise ArgumentError, "invalid switch: #{_1}" unless _1.is_a?(String)
        raise ArgumentError, "invalid switch: #{_1}" unless _1.match?(SWITCH_RE)
      end
      raise ArgumentError, "duplicate switch" unless switches.uniq.length == switches.length

      raise ArgumentError, "invalid flag kind: #{kind}" unless KINDS.include?(kind)
      raise ArgumentError, "boolean flags do not accept meta" if bool? && meta
      raise ArgumentError, "required must be true or false" unless required == true || required == false
      raise ArgumentError, "required flags cannot have defaults" if required && default != nil
      raise ArgumentError, "invalid default #{default.inspect} for #{kind}" if default != nil && !allowed?(default)

      if choices
        raise ArgumentError, "choices must be an array" unless choices.is_a?(Array)
        raise ArgumentError, "choices cannot be empty" if choices.empty?
        choices.each do
          raise ArgumentError, "invalid choice #{_1.inspect} for #{kind}" unless allowed?(_1)
        end
      end
    end

    def build_meta
      if (m = /\A(\S+) <([^>]+)>\z/.match(switch))
        switches[switches.length - 1] = m[1]
        return m[2]
      end
      kind.to_s unless bool?
    end

    def allowed?(candidate)
      case kind
      when :bool then candidate == true || candidate == false
      when :int then candidate.is_a?(Integer)
      when :str then candidate.is_a?(String)
      end
    end
  end
end

module Slap
  class Help
    INDENT = 2

    attr_reader :config, :width

    def initialize(config, width = nil)
      @config = config
      @width = (width || Util.termwidth).clamp(60, 100)
    end

    def to_s
      return config.help if config.help

      buf = StringIO.new
      buf << banner
      buf << "\n\n"

      label_width = widest_label
      config.flags.each.with_index do |flag, idx|
        buf << separator_text(idx) # sep

        label = flag.label(color)
        buf << " " * INDENT
        buf << label

        if flag.help
          buf << " " * (label_width - Util.width(label) + 2)
          indent = INDENT + label_width + 2
          buf << Util.wrap(flag.help, width - indent).gsub("\n", "\n#{" " * indent}")
        end
        buf << "\n"
      end
      buf << separator_text(config.flags.length)

      buf.string
    end

    def banner
      text = config.banner
      text ||= [color.blue("Usage:"), color.green(config.app_name), "[options]"].tap do
        _1.push(*config.positionals.map(&:meta))
      end.join(" ")
      Util.wrap(text, width)
    end

    def separator_text(position)
      StringIO.new.tap do |buf|
        config.separators.each do |(pos, str)|
          if pos == position
            buf << color.blue(str)
            buf << "\n"
          end
        end
      end.string
    end

    def color = @color ||= Color.new(config.color)
    def widest_label = config.flags.map { Util.width(_1.label(color)) }.max
  end
end

module Slap
  class Main
    attr_reader :config

    def initialize = @config = Config.new
    def app_name = config.app_name

    def parse(argv)
      config.prepare!

      begin
        options = Parser.new(config).parse(argv)
        OpenStruct.new(options).freeze
      rescue Error => ex
        warn "#{app_name}: #{ex.message}"
        warn "#{app_name}: try '#{app_name} --help' for more information"
        exit_fn(1, error: ex.message)
      rescue HelpRequested, NakedRequested, VersionRequested => ex
        early_exit(ex)
        exit_fn(0)
      end
    end

    protected

    def early_exit(ex)
      case ex
      when HelpRequested
        puts Help.new(config)
      when NakedRequested
        puts "#{app_name}: try '#{app_name} --help' for more information"
      when VersionRequested
        puts "#{app_name} #{config.version}"
      end
    end

    def exit_fn(status, error: nil)
      args = [].tap do
        _1 << status
        _1 << error if config.exit.arity == 2
      end
      config.exit.call(*args)
      nil
    end
  end

  class Error < StandardError; end

  class HelpRequested < Exception; end # rubocop:disable Lint/InheritException
  class NakedRequested < Exception; end # rubocop:disable Lint/InheritException
  class VersionRequested < Exception; end # rubocop:disable Lint/InheritException

  def self.parse(argv = ARGV)
    Main.new.tap { yield _1.config if block_given? }.parse(argv)
  end
end

module Slap
  class Parser
    attr_reader :config, :options, :queue

    def initialize(config)
      @config = config
    end

    def parse(argv)
      @options, @queue = config.defaults, argv.dup
      parse_queue
      validate!
      options
    end

    protected

    def parse_queue
      raise NakedRequested if config.naked? && queue.empty?

      operands = []

      while (item = queue.shift)
        case item
        when Flag::SWITCH_RE, Flag::INLINE_RE then parse_switch(item, Regexp.last_match)
        when /\A-[^-]/ then parse_smashed(item)
        when "", /\A[^-]/ then operands << item
        when "--" then break operands.concat(queue)
        else; raise Error, "unexpected argument '#{item}' found"
        end
      end

      config.positionals.each do
        options[_1.key] = operands.shift
      end

      options[:_args] = operands
    end

    def parse_switch(item, match)
      switch = "-#{match[1]}"
      param = match[2]
      separator = param ? "=" : ""

      if (flag = config.flag(switch))
        builtin!(flag)
        param = queue.shift if flag.takes_param? && separator.empty?
        options[flag.key] = flag.parse(switch, param)
        return
      end

      if (neg = find_negated_flag(switch))
        raise Error, "option '#{item}' does not take a value" if separator == "="
        options[neg.key] = false
        return
      end

      raise Error, "unexpected argument '#{item}' found"
    end

    def parse_smashed(group)
      (1...group.length).each do |idx|
        switch = "-#{group[idx]}"
        flag = config.flag(switch)
        raise Error, "unexpected argument '#{group}' found" unless flag
        builtin!(flag)

        if flag.takes_param?
          param = if idx + 1 < group.length
            group[idx + 1...group.length]
          else
            queue.shift
          end
          options[flag.key] = flag.parse(switch, param)
          return
        end

        options[flag.key] = true
      end
    end

    def builtin!(flag)
      raise HelpRequested if flag == config.help_flag
      raise VersionRequested if flag == config.version_flag
    end

    def find_negated_flag(switch)
      if (m = Flag::NEGATE_RE.match(switch))
        flag = config.flag("--#{m[1]}")
        flag if flag&.bool?
      end
    end

    def validate!
      config.required.each do
        raise Error, "required option '#{_1.switch}' is missing" if !options.key?(_1.key)
      end
      config.positionals.each do
        raise Error, "required argument '#{_1.meta}' is missing" if !options[_1.key]
      end
    end
  end
end

module Slap
  class Positional
    POSITIONAL_RE = /\A<([A-Z][\w_]*)>\z/i

    attr_reader :help, :meta

    def initialize(meta:, help:)
      @help, @meta = help, meta
      raise ArgumentError, "positional help must be a string" unless help.is_a?(String)
      raise ArgumentError, "positional meta must be a string" unless meta.is_a?(String)
      raise ArgumentError, "positional must use <meta>" unless POSITIONAL_RE.match?(meta)
    end

    def key = @key ||= POSITIONAL_RE.match(meta)[1].to_sym
  end
end

module Slap
  module Util
    module_function

    ANSI_RE = /\e\[[\d;]*m/

    def termwidth
      width = 80
      if $stdout.tty?
        w = $stdout.winsize[1]
        width = w if w > 0
      end
      width
    end

    def width(str) = str.gsub(ANSI_RE, "").length

    def wrap(str, columns)
      return "" if str.empty?

      lines, words = [], []
      tokens = str.split(/[ \t\r]+|(\n)/).reject(&:empty?) # words and newlines
      tokens.each do |word|
        if word == "\n"
          lines << words.join(" ")
          words = []
          next
        end
        if !words.empty? && width("#{words.join(" ")} #{word}") > columns
          lines << words.join(" ")
          words = []
        end

        words << word
      end
      lines << words.join(" ") unless words.empty?
      lines << "" if tokens.last == "\n"
      lines.join("\n")
    end
  end
end

$stderr = $stdout

def assert_equal(exp, actual)
  raise "expected #{exp.inspect}, got #{actual.inspect}" unless exp == actual
end

def help_text(config, width = nil)
  config.prepare!
  Slap::Help.new(config, width).to_s
end

config = Slap::Config.new
config.app_name = "a"
config.version = "1"
config.separator "C:"
config.str "-H", "--host <n>", "h"
config.int "-p", "--port", "p"
config.sep
config.bool "--q", "q"
config.positional "<u>", "u"

expected = "Usage: a [options] <u>\n\nC:\n  -H, --host <n>    h\n  -p, --port <int>  p\n\n  --q               q\n  -h, --help        Show this message\n  -v, --version     Show version\n"
assert_equal expected, help_text(config)

banner = Slap::Config.new
banner.app_name = "slap"
banner.banner = "slap custom usage"
banner.bool "--verbose", "verbose output"
assert_equal "slap custom usage\n\n  --verbose   verbose output\n  -h, --help  Show this message\n", help_text(banner)

custom = Slap::Config.new
custom.help = "Custom help\n"
assert_equal "Custom help\n", Slap::Help.new(custom).to_s

color = Slap::Config.new
color.app_name = "slap"
color.color = true
color.separator "Options:"
color.str "--host <name>", "hostname"
color_expected = "\e[1;34mUsage:\e[0m \e[1;32mslap\e[0m [options]\n\n\e[1;34mOptions:\e[0m\n  \e[1;32m--host\e[0m \e[1;33m<name>\e[0m  hostname\n  \e[1;32m-h\e[0m, \e[1;32m--help\e[0m     Show this message\n"
assert_equal color_expected, help_text(color)
Slap::Help.new(color).to_s.lines.each do |line|
  raise "colored line too wide" if Slap::Util.width(line.chomp) > 80
end

color.color = false
color_off_expected = "Usage: slap [options]\n\nOptions:\n  --host <name>  hostname\n  -h, --help     Show this message\n"
assert_equal color_off_expected, Slap::Help.new(color).to_s

wrap = Slap::Config.new
wrap.app_name = "slap"
wrap.str "--long", "one two three four five six seven eight nine ten"
wrap_expected = "Usage: slap [options]\n\n  --long <str>  one two three four five six seven eight nine\n                ten\n  -h, --help    Show this message\n"
assert_equal wrap_expected, help_text(wrap, 60)
assert_equal wrap_expected, Slap::Help.new(wrap, 1).to_s
assert_equal Slap::Help.new(wrap, 100).to_s, Slap::Help.new(wrap, 1_000).to_s

separators = Slap::Config.new
separators.app_name = "slap"
separators.separator "First:"
separators.separator "Second:"
separators.bool "--quiet", "suppress output"
separators_expected = "Usage: slap [options]\n\nFirst:\nSecond:\n  --quiet     suppress output\n  -h, --help  Show this message\n"
assert_equal separators_expected, help_text(separators)

status = nil
error = true
Slap.parse(["--help"]) do |o|
  o.app_name = "slap"
  o.bool "--verbose", "verbose output"
  o.str "--name", required: true
  o.positional "<url>"
  o.exit = ->(value, message) {
    status = value
    error = message
  }
end
assert_equal 0, status
raise "wrong error" if error

status = nil
Slap.parse(["--help"]) do |o|
  o.color = true
  o.help = "Custom help\n"
  o.exit = ->(value) { status = value }
end
assert_equal 0, status

status = nil
error = true
Slap.parse(["--version"]) do |o|
  o.app_name = "slap"
  o.version = "1.2.3"
  o.str "--name", required: true
  o.positional "<url>"
  o.exit = ->(value, message) {
    status = value
    error = message
  }
end
assert_equal 0, status
raise "wrong error" if error

status = nil
Slap.parse(["-v"]) do |o|
  o.app_name = "slap"
  o.version = 1.2
  o.exit = ->(value) { status = value }
end
assert_equal 0, status

puts "ok"

# Bug: assigning `$stderr = $stdout` can segfault on Ubuntu in a larger
# parser-shaped program.
# Bad line (UNREDUCED): `$stderr = $stdout`
#
# Ruby result:
#   status 0, prints ok
#
# Spinel result on Ubuntu:
#   status 139, Segmentation fault
#
# Spinel result on other platforms:
#   may pass; crash is currently known to be Ubuntu-specific
#
# Repro:
#   ruby spinel_76.rb
#   spinel -o build/crash-76 spinel_76.rb
#   build/crash-76
#

require "io/console"
require "ostruct"
require "pathname"
require "stringio"

# >>> slap/color.rb
#
# A simple color toggle that can format text. If unset infer from stdout.tty.
#

module Slap
  class Color
    attr_reader :enabled
    alias_method :enabled?, :enabled

    def initialize(enabled)
      @enabled = enabled.nil? ? $stdout.tty? : enabled
    end

    # one-liners
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
# <<< slap/color.rb
# >>> slap/config.rb
#
# Config users setup with `Slap.parse`. Records flags, positionals, help text,
# etc.
#

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

    # Add a positional param declared as `<url>`.
    def pos(meta, help = "")
      Positional.new(meta:, help:).tap do
        raise ArgumentError, "duplicate positional #{_1.key}" if key?(_1.key)
        positionals << _1
        lookup[_1.key] = _1
      end
    end

    # Add separator text at the current point in generated help.
    def sep(text = "")
      [flags.length, text].tap do
        separators << _1
      end
    end

    #
    # flags
    #

    def bool(*opts, default: nil, required: false)
      add_flag(Flag.new(:bool, opts, default:, required:))
    end

    def float(*opts, default: nil, required: false, choices: nil)
      add_flag(Flag.new(:float, opts, default:, required:, choices:))
    end

    def int(*opts, default: nil, required: false, choices: nil)
      add_flag(Flag.new(:int, opts, default:, required:, choices:))
    end

    def path(*opts, default: nil, required: false, choices: nil)
      add_flag(Flag.new(:path, opts, default:, required:, choices:))
    end

    def str(*opts, default: nil, required: false, choices: nil)
      add_flag(Flag.new(:str, opts, default:, required:, choices:))
    end

    def sym(*opts, default: nil, required: false, choices: nil)
      add_flag(Flag.new(:sym, opts, default:, required:, choices:))
    end

    # long-form aliases
    alias_method :boolean, :bool
    alias_method :integer, :int
    alias_method :pathname, :path
    alias_method :positional, :pos
    alias_method :separator, :sep
    alias_method :string, :str
    alias_method :symbol, :sym

    # handy helpers
    def defaults
      flags.filter_map do
        next if _1.required || _1 == help_flag || _1 == version_flag
        [_1.key, _1.default]
      end.to_h
    end

    # one-liners
    def flag(switch) = lookup[switch]
    def flag?(switch) = lookup.key?(switch)
    def key?(key) = lookup.key?(key)
    def required = flags.select(&:required?)

    # Complete one-time setup after the caller has declared overrides.
    def prepare!
      return if @prepared
      @prepared = true
      @exit ||= lambda { |status| Kernel.exit(status) }
      @help_flag = add_builtin(["-h", "--help"], "Show this message")
      @version_flag = add_builtin(["-v", "--version"], "Show version") if version
    end

    protected

    # Add help/version flags, but only for switches the user did not override.
    def add_builtin(switches, help_text)
      unused = switches.select { !flag?(_1) }
      return if unused.empty?
      add_flag(Flag.new(:bool, unused + [help_text]))
    end

    def add_flag(flag)
      # dup check
      raise ArgumentError, "reserved flag key: _args" if flag.key == :_args
      raise ArgumentError, "dup flag key: #{flag.key}" if key?(flag.key)
      flag.switches.each do
        raise ArgumentError, "dup flag switch: #{_1}" if flag?(_1)
      end

      # append
      flags << flag
      lookup[flag.key] = flag
      flag.switches.each { lookup[_1] = flag }

      # return flag
      flag
    end
  end
end
# <<< slap/config.rb
# >>> slap/flag.rb
#
# One configured flag, including all switches that invoke it.
#

module Slap
  class Flag
    # --foo or -f
    SWITCH_RE = /\A-(\w|-\w[\w-]*)\z/
    # --foo=bar
    INLINE_RE = /\A-(\w|-\w[\w-]*)=(.*)\z/m
    # --no-foo
    NEGATE_RE = /\A--no-(\w[\w-]*)\z/

    KINDS = %i[bool float int path str sym]

    attr_reader :choices, :default, :help, :kind, :meta, :required, :switches

    # ctor
    def initialize(kind, opts, default: nil, required: false, choices: nil)
      @choices, @kind, @required = choices, kind, required

      # extract @help from last string
      @switches = opts.dup
      @help = if switch && !switch.start_with?("-")
        switches.pop
      end

      # Extract meta from the final switch, if written as `--port <int>`.
      @meta = build_meta

      # default, with some special handling for bool
      @default = default
      if bool? && default.nil? && !required?
        @default = false
      end

      validate
    end

    #
    # parsing
    #

    # Parse a single cli param
    def parse(switch, param)
      if bool?
        raise Error, "option '#{switch}=#{param}' does not take a value" if param
        return true
      end

      raise Error, "option '#{switch}' requires a value" if !param
      parsed = begin
        case kind
        when :float then Float(param)
        when :int then Integer(param, 10)
        when :path then Pathname.new(param)
        when :str then param
        when :sym then param.to_sym
        end
      rescue ArgumentError
        raise Error, "invalid value '#{param}' for option '#{switch}'"
      end

      if choices && !choices.include?(parsed)
        raise Error, "invalid value '#{parsed}' for option '#{switch}', must be one of #{choices.join(", ")}"
      end
      parsed
    end

    #
    # rendering
    #

    def label(color)
      label = switches.map { color.green(_1) }.join(", ")
      return label unless takes_param?
      "#{label} #{color.yellow("<#{meta}>")}"
    end

    # one-liners
    def bool? = kind == :bool
    def key = @key ||= switch.sub(/^-+/, "").tr("-", "_").to_sym
    def switch = switches.last
    def takes_param? = !bool?
    alias_method :required?, :required

    protected

    #
    # validation
    #

    def validate
      # switches
      raise ArgumentError, "at least one switch is required" if switches.empty?
      switches.each do
        raise ArgumentError, "invalid switch: #{_1}" unless _1.is_a?(String)
        raise ArgumentError, "invalid switch: #{_1}" unless _1.match?(SWITCH_RE)
      end
      raise ArgumentError, "duplicate switch" unless switches.uniq.length == switches.length

      # params
      raise ArgumentError, "invalid flag kind: #{kind}" unless KINDS.include?(kind)
      raise ArgumentError, "boolean flags do not accept meta" if bool? && meta
      raise ArgumentError, "required must be true or false" unless required == true || required == false
      raise ArgumentError, "required flags cannot have defaults" if required && default != nil
      raise ArgumentError, "invalid default #{default.inspect} for #{kind}" if default != nil && !allowed?(default)

      # choices
      if choices
        raise ArgumentError, "choices must be an array" unless choices.is_a?(Array)
        raise ArgumentError, "choices cannot be empty" if choices.empty?
        choices.each do
          raise ArgumentError, "invalid choice #{_1.inspect} for #{kind}" unless allowed?(_1)
        end
      end
    end

    #
    # helpers
    #

    def build_meta
      # Only the final spelling may carry an inferred `<meta>`.
      if (m = /\A(\S+) <([^>]+)>\z/.match(switch))
        switches[switches.length - 1] = m[1]
        return m[2]
      end
      kind.to_s unless bool?
    end

    def allowed?(candidate)
      case kind
      when :bool then candidate == true || candidate == false
      when :float then candidate.is_a?(Float)
      when :int then candidate.is_a?(Integer)
      when :path then candidate.is_a?(Pathname)
      when :str then candidate.is_a?(String)
      when :sym then candidate.is_a?(Symbol)
      end
    end
  end
end
# <<< slap/flag.rb
# >>> slap/help.rb
#
# Renders the generated help text. Most of the fiddly work here is keeping
# columns aligned while ANSI color is present.
#

module Slap
  class Help
    INDENT = 2

    attr_reader :config, :width

    def initialize(config, width = nil)
      @config = config
      @width = (width || Util.termwidth).clamp(60, 100)
    end

    # Render generated help, unless the caller supplied complete help text.
    def to_s
      return config.help if config.help

      # usage: xyz (banner)
      buf = StringIO.new
      buf << banner
      buf << "\n\n"

      # Render each flag with aligned switch labels and wrapped help text.
      label_width = widest_label
      config.flags.each.with_index do |flag, idx|
        buf << separator_text(idx) # sep

        # left
        label = flag.label(color)
        buf << " " * INDENT
        buf << label

        # right
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

    # Build the usage line from the configured app name and positionals.
    def banner
      text = config.banner
      text ||= [color.blue("Usage:"), color.green(config.app_name), "[options]"].tap do
        _1.push(*config.positionals.map(&:meta))
      end.join(" ")
      Util.wrap(text, width)
    end

    # Render separator text at its recorded position between flags.
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

    # one-liners
    def color = @color ||= Color.new(config.color)
    def widest_label = config.flags.map { Util.width(_1.label(color)) }.max
  end
end
# <<< slap/help.rb
# >>> slap/main.rb
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
  class Main
    attr_reader :config

    def initialize = @config = Config.new
    def app_name = config.app_name

    # Parse argv and turn internal parser outcomes into CLI behavior.
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

  # early exits
  class HelpRequested < Exception; end # rubocop:disable Lint/InheritException
  class NakedRequested < Exception; end # rubocop:disable Lint/InheritException
  class VersionRequested < Exception; end # rubocop:disable Lint/InheritException

  # main entry point
  def self.parse(argv = ARGV)
    Main.new.tap { yield _1.config if block_given? }.parse(argv)
  end
end
# <<< slap/main.rb
# >>> slap/parser.rb
#
# Turns argv into a typed result. It knows the CLI grammar but stays away from
# printing and exiting.
#

module Slap
  class Parser
    attr_reader :config, :options, :queue

    def initialize(config)
      @config = config
    end

    # Reset transient state, parse argv, and assemble the result.
    def parse(argv)
      @options, @queue = config.defaults, argv.dup
      parse_queue
      validate!
      options
    end

    protected

    #
    # main parser
    #

    def parse_queue
      raise NakedRequested if config.naked? && queue.empty?

      # any non-flags we find below
      operands = []

      # process argv as queue
      while (item = queue.shift)
        case item
        when Flag::SWITCH_RE, Flag::INLINE_RE then parse_switch(item, Regexp.last_match)
        when /\A-[^-]/ then parse_smashed(item)
        when "", /\A[^-]/ then operands << item
        when "--" then break operands.concat(queue)
        else; raise Error, "unexpected argument '#{item}' found"
        end
      end

      # positionals
      config.positionals.each do
        options[_1.key] = operands.shift
      end

      # _args
      options[:_args] = operands
    end

    #
    # -x or -x=123 or --xyz or --xyz=123 or --no-xyz
    #

    def parse_switch(item, match)
      switch = "-#{match[1]}"
      param = match[2]
      separator = param ? "=" : ""

      # -x or --xyz?
      if (flag = config.flag(switch))
        builtin!(flag)
        param = queue.shift if flag.takes_param? && separator.empty?
        options[flag.key] = flag.parse(switch, param)
        return
      end

      # --no-xyz?
      if (neg = find_negated_flag(switch))
        raise Error, "option '#{item}' does not take a value" if separator == "="
        options[neg.key] = false
        return
      end

      raise Error, "unexpected argument '#{item}' found"
    end

    #
    # smashed flags
    #

    # Expand short-switch groups such as `-qv`. A parameter-taking switch ends
    # the group and consumes either its attached suffix or the next queue item.
    def parse_smashed(group)
      (1...group.length).each do |idx|
        switch = "-#{group[idx]}"
        flag = config.flag(switch)
        raise Error, "unexpected argument '#{group}' found" unless flag
        builtin!(flag)

        # For `-qnLee`, `Lee` belongs to `-n`; for `-qn Lee`, shift the queue.
        if flag.takes_param?
          param = if idx + 1 < group.length
            group[idx + 1...group.length]
          else
            queue.shift
          end
          options[flag.key] = flag.parse(switch, param)
          return
        end

        # bool
        options[flag.key] = true
      end
    end

    #
    # helpers
    #

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
# <<< slap/parser.rb
# >>> slap/positional.rb
#
# A required positional param like `<url>`.
#

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

    # one-liners
    def key = @key ||= POSITIONAL_RE.match(meta)[1].to_sym
  end
end
# <<< slap/positional.rb
# >>> slap/util.rb
#
# Shared helpers
#

module Slap
  module Util
    module_function

    ANSI_RE = /\e\[[\d;]*m/

    # Calculate terminal width, defaulting to 80.
    def termwidth
      width = 80
      if $stdout.tty?
        w = $stdout.winsize[1]
        width = w if w > 0
      end
      width
    end

    # Measure characters while ignoring ANSI control sequences.
    def width(str) = str.gsub(ANSI_RE, "").length

    # Return word-wrapped text. ANSI width is understood for alignment, but
    # callers do not wrap live colored regions across lines; help/body text is
    # plain, and generated colored usage is short enough to stay on one line.
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
# <<< slap/util.rb
$stderr = $stdout
def assert_equal(exp, actual)
  raise "expected #{exp.inspect}, got #{actual.inspect}" unless exp == actual
end

argv = ["--name", "Lee", "file"]
options = Slap.parse(argv) do |o|
  o.str "--name", "name"
end

assert_equal "Lee", options[:name]
assert_equal ["file"], options[:_args]
assert_equal ["--name", "Lee", "file"], argv

options = Slap.parse(["-n", "first", "--name", "last"]) do |o|
  o.str "-n", "--name", "name", default: "default"
end

assert_equal "last", options[:name]
assert_equal [], options[:_args]

options = Slap.parse([]) do |o|
  o.naked = false
  o.str "--name", "name", default: "default"
end

assert_equal "default", options[:name]

options = Slap.parse(["file"]) do |o|
  o.naked = false
  o.str "--data", "HTTP POST data", required: false
end

assert_equal nil, options[:data]
assert_equal ["file"], options[:_args]

options = Slap.parse(["--name", "Lee"]) do |o|
  o.str "--name", required: true
end

assert_equal "Lee", options[:name]

options = Slap.parse(["--", "--name"]) do |o|
  o.str "--name"
end

assert_equal ["--name"], options[:_args]

options = Slap.parse(["--count", "-2", "--ratio", "1.5", "--mode", "fast"]) do |o|
  o.int "--count"
  o.float "--ratio"
  o.sym "--mode"
end

assert_equal(-2, options[:count])
assert_equal 1.5, options[:ratio]
assert_equal :fast, options[:mode]

options = Slap.parse(["--count", "2", "--mode", "fast"]) do |o|
  o.int "--count", choices: [1, 2, 3]
  o.sym "--mode", choices: %i[slow fast]
end

assert_equal 2, options[:count]
assert_equal :fast, options[:mode]

options = Slap.parse(["--verbose", "--no-quiet"]) do |o|
  o.bool "--verbose"
  o.bool "--quiet", default: true
end

assert_equal true, options[:verbose]
assert_equal false, options[:quiet]
assert_equal [], options[:_args]

options = Slap.parse(["--no-name=Lee"]) do |o|
  o.bool "--name"
  o.str "--no-name"
end

assert_equal false, options[:name]
assert_equal "Lee", options[:no_name]

options = Slap.parse(["--name", "Lee", "--", "--verbose", "file"]) do |o|
  o.str "--name"
  o.bool "--verbose"
end

assert_equal "Lee", options[:name]
assert_equal false, options[:verbose]
assert_equal ["--verbose", "file"], options[:_args]

options = Slap.parse(["--name=Lee=Smith", "--count=-2"]) do |o|
  o.str "--name"
  o.int "--count"
end

assert_equal "Lee=Smith", options[:name]
assert_equal(-2, options[:count])

options = Slap.parse(["--name="]) do |o|
  o.str "--name"
end

assert_equal "", options[:name]

options = Slap.parse(["-nLee", "-c2"]) do |o|
  o.str "-n", "--name"
  o.int "-c", "--count"
end

assert_equal "Lee", options[:name]
assert_equal 2, options[:count]

options = Slap.parse(["-qv"]) do |o|
  o.bool "-q", "--quiet"
  o.bool "-v", "--verbose"
end

assert_equal true, options[:quiet]
assert_equal true, options[:verbose]

options = Slap.parse(["-qvn", "Lee"]) do |o|
  o.bool "-q", "--quiet"
  o.bool "-v", "--verbose"
  o.str "-n", "--name"
end

assert_equal true, options[:quiet]
assert_equal true, options[:verbose]
assert_equal "Lee", options[:name]

options = Slap.parse(["-qvnLee"]) do |o|
  o.bool "-q", "--quiet"
  o.bool "-v", "--verbose"
  o.str "-n", "--name"
end

assert_equal true, options[:quiet]
assert_equal true, options[:verbose]
assert_equal "Lee", options[:name]

options = Slap.parse(["--name", "Lee", "https://example.test", "file"]) do |o|
  o.str "--name"
  o.positional "<url>", "URL"
end

assert_equal "Lee", options[:name]
assert_equal "https://example.test", options[:url]
assert_equal ["file"], options[:_args]

options = Slap.parse(["--", "https://example.test", "--literal"]) do |o|
  o.positional "<url>", "URL"
end

assert_equal "https://example.test", options[:url]
assert_equal ["--literal"], options[:_args]

options = Slap.parse([""]) { _1.naked = false }
assert_equal [""], options[:_args]

options = Slap.parse(["source.txt", "copy.txt", "extra.txt"]) do |o|
  o.positional "<source>"
  o.positional "<destination>"
end

assert_equal "source.txt", options[:source]
assert_equal "copy.txt", options[:destination]
assert_equal ["extra.txt"], options[:_args]

options = Slap.parse(["--timeout", "5"]) do |o|
  o.int "--timeout <seconds>"
end

assert_equal 5, options[:timeout]

options = Slap.parse(["--name", "", "--text", "--literal", "--foo", "=", "="]) do |o|
  o.str "--name"
  o.str "--text"
  o.str "--foo"
end

assert_equal "", options[:name]
assert_equal "--literal", options[:text]
assert_equal "=", options[:foo]
assert_equal ["="], options[:_args]

#
# type values
#

options = Slap.parse([
  "--name", "Foo", "--method", "post", "--age", "-10",
  "--plus", "+30", "--numeric-symbol", "12345", "--ratio", "+9.4", "--scientific", "4e-21", "--output", "tmp/out.txt", "--verbose",
  "--no-inversed",
]) do |o|
  o.str "--name"
  o.sym "--method"
  o.int "--age"
  o.int "--plus"
  o.sym "--numeric-symbol"
  o.float "--ratio"
  o.float "--scientific"
  o.path "--output"
  o.bool "--verbose"
  o.bool "--quiet"
  o.bool "--inversed", default: true
end

assert_equal "Foo", options[:name]
assert_equal :post, options[:method]
assert_equal(-10, options[:age])
assert_equal 30, options[:plus]
assert_equal :"12345", options[:numeric_symbol]
assert_equal 9.4, options[:ratio]
assert_equal 4e-21, options[:scientific]
assert_equal Pathname.new("tmp/out.txt"), options[:output]
assert_equal true, options[:verbose]
assert_equal false, options[:quiet]
assert_equal false, options[:inversed]

scientific_values = ["4E21", "4.0e21", "-4e21"]
scientific_values.each do |value|
  options = Slap.parse(["--scientific", value]) do |o|
    o.float "--scientific"
  end
  assert_equal Float(value), options[:scientific]
end

#
# defaults
#

options = Slap.parse([]) do |o|
  o.naked = false
  o.str "--str", default: "hello"
  o.int "--int", default: 12
  o.float "--float", default: 1.25
  o.path "--path", default: Pathname.new("tmp/default")
  o.sym "--sym", default: :fast
  o.bool "--bool"
  o.bool "--enabled", default: true
  o.bool "--disabled", default: false
  o.str "--nil", default: nil
end

assert_equal "hello", options[:str]
assert_equal 12, options[:int]
assert_equal 1.25, options[:float]
assert_equal Pathname.new("tmp/default"), options[:path]
assert_equal :fast, options[:sym]
assert_equal false, options[:bool]
assert_equal true, options[:enabled]
assert_equal false, options[:disabled]
assert_equal nil, options[:nil]

#
# choices
#

options = Slap.parse(["--str", "red", "--int", "2", "--float", "2.5", "--path", "tmp/a", "--sym", "fast"]) do |o|
  o.str "--str", choices: %w[red blue]
  o.int "--int", choices: [1, 2]
  o.float "--float", choices: [1.5, 2.5]
  o.path "--path", choices: [Pathname.new("tmp/a"), Pathname.new("tmp/b")]
  o.sym "--sym", choices: %i[slow fast]
end

assert_equal "red", options[:str]
assert_equal 2, options[:int]
assert_equal 2.5, options[:float]
assert_equal Pathname.new("tmp/a"), options[:path]
assert_equal :fast, options[:sym]

# reduce:freeze (do not modify anything below this line)
raise "FAIL" unless options[:sym] == :fast
puts "ok"

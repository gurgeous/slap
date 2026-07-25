require_relative "test_helper"

config = Slap::Config.new
raise "default app_name" unless config.app_name == File.basename($PROGRAM_NAME)
raise "default banner" if config.banner
raise "default help" if config.help
raise "default version" if config.version
raise "default color" if config.color
raise "default naked" unless config.naked

config.app_name = "slap"
config.banner = "Usage: slap"
config.help = "help"
config.version = "1.2.3"
config.color = true
config.naked = false
config.separator "Connection:"
config.sep

raise "set app_name" unless config.app_name == "slap"
raise "set banner" unless config.banner == "Usage: slap"
raise "set help" unless config.help == "help"
raise "set version" unless config.version == "1.2.3"
raise "set color" unless config.color
raise "set naked" if config.naked
raise "separators" unless config.separators == [[0, "Connection:"], [0, ""]]
config.bool("-h", "--help")
config.bool("-v", "--version")
raise "help flag" unless config.flag("-h").key == :help
raise "version flag" unless config.flag("--version").key == :version
raise "missing flag" if config.flag("--missing")

config.prepare!
raise "overridden help" if config.help_flag
raise "overridden version" if config.version_flag

prepared = Slap::Config.new
prepared.version = "1.2.3"
prepared.prepare!
help_flag = prepared.help_flag
version_flag = prepared.version_flag
prepared.prepare!
assert_equal help_flag, prepared.help_flag
assert_equal version_flag, prepared.version_flag
assert_equal 2, prepared.flags.length

# color roundtrips
config.color = true
raise "true color" unless config.color == true
config.color = false
raise "false color" unless config.color == false
config.color = nil
raise "auto color" unless config.color.nil?

flag_config = Slap::Config.new
name = flag_config.str("-n", "--name <person>", "a name", required: true, choices: %w[Lee Pat])
verbose = flag_config.bool("-v", "--verbose", "verbose output")
port = flag_config.int("--http-port")
timeout = flag_config.int("--timeout <seconds>", "request timeout")
url = flag_config.positional "<url>", "URL to fetch"
omitted = flag_config.str "--omitted"
explicit_false = flag_config.str "--explicit-false", required: false

#
# flag checks
#

assert_equal :str, name.kind
assert_equal ["-n", "--name"], name.switches
assert_equal name, flag_config.lookup[:name]
assert_equal name, flag_config.lookup["--name"]
assert_equal "a name", name.help
assert_equal :name, name.key
assert_equal nil, name.default
assert_equal true, name.required?
assert_equal %w[Lee Pat], name.choices
assert_equal "person", name.meta
assert_equal true, name.takes_param?
assert_equal :verbose, verbose.key
assert_equal true, verbose.bool?
assert_equal false, verbose.default
assert_equal nil, Slap::Flag.new(:bool, ["--required-bool"], required: true).default
assert_equal :http_port, port.key
assert_equal nil, port.help
assert_equal :timeout, timeout.key
assert_equal "seconds", timeout.meta
assert_equal true, timeout.takes_param?
assert_equal "str", omitted.meta
assert_equal false, omitted.required?
assert_equal false, explicit_false.required?
assert_equal Slap::Positional, url.class
assert_equal :url, url.key
assert_equal url, flag_config.lookup[:url]
assert_equal "<url>", url.meta
assert_equal "URL to fetch", url.help
assert_equal 6, flag_config.flags.length
assert_equal 1, flag_config.positionals.length

assert_raises(ArgumentError) { flag_config.int "--empty-choices", choices: [] }

options = Slap.parse(["-1", "--2"]) do |o|
  o.bool "-1"
  o.bool "--2"
end
assert_equal true, options[:"1"]
assert_equal true, options[:"2"]

#
# flag errors
#

assert_raises(ArgumentError) { Slap::Flag.new(:unknown, ["--unknown"]) }

begin
  flag_config.str "--name"
  raise "expected duplicate flag error"
rescue ArgumentError
end
assert_equal 6, flag_config.flags.length

assert_raises(ArgumentError) { flag_config.bool "-d", "-d" }
assert_equal 6, flag_config.flags.length

begin
  flag_config.str "--_args"
  raise "expected reserved name error"
rescue ArgumentError
end

begin
  flag_config.str "name"
  raise "expected invalid flag error"
rescue ArgumentError
end

["-word", "-ab"].each do |name|
  assert_raises(ArgumentError) { flag_config.str name }
end

begin
  flag_config.str "--other", required: nil
  raise "expected required error"
rescue ArgumentError
end

assert_raises(ArgumentError) { flag_config.bool "--bad-bool-default", default: "yes" }
assert_raises(ArgumentError) { flag_config.float "--bad-float-default", default: 1 }
assert_raises(ArgumentError) { flag_config.int "--bad-int-default", default: "1" }
assert_raises(ArgumentError) { flag_config.str "--bad-str-default", default: :name }
assert_raises(ArgumentError) { flag_config.sym "--bad-sym-default", default: "name" }
assert_raises(ArgumentError) { flag_config.str "--required-default", required: true, default: "name" }
assert_raises(ArgumentError) { flag_config.bool "--required-bool-default", required: true, default: false }

begin
  flag_config.str "--other", choices: "one"
  raise "expected choices error"
rescue ArgumentError
end

begin
  flag_config.str "--bad-required", required: nil
  raise "expected required nil error"
rescue ArgumentError
end

begin
  flag_config.str "--bad-str", choices: [:red]
  raise "expected str choices error"
rescue ArgumentError
end

begin
  flag_config.int "--bad-int", choices: ["1"]
  raise "expected int choices error"
rescue ArgumentError
end

begin
  flag_config.float "--bad-float", choices: [1]
  raise "expected float choices error"
rescue ArgumentError
end

begin
  flag_config.sym "--bad-sym", choices: ["fast"]
  raise "expected sym choices error"
rescue ArgumentError
end

begin
  flag_config.bool "--quiet <bool>"
  raise "expected bool meta error"
rescue ArgumentError
end

begin
  flag_config.positional "url", "URL"
  raise "expected positional syntax error"
rescue ArgumentError
end

["<>", "<1url>", "<bad-name>", "<url><path>"].each do |meta|
  flag_config.positional meta, "value"
  raise "expected positional name error"
rescue ArgumentError
end

begin
  flag_config.positional("<_args>", "leftovers")
  raise "expected positional reserved name error"
rescue ArgumentError
end

begin
  flag_config.positional "<url>", "URL"
  raise "expected duplicate positional error"
rescue ArgumentError
end

flag_config.bool "--help"
flag_config.bool "-V"
help = flag_config.flags[6]
version = flag_config.flags[7]
assert_equal :help, help.key
assert_equal :V, version.key

begin
  flag_config.str "--url"
  raise "expected positional collision error"
rescue ArgumentError
end

puts "ok"

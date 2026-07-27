require_relative "test_helper"

def help_text(config, width = nil)
  config.prepare!
  Slap::Help.new(config, width).to_s
end

config = Slap::Config.new
config.app_name = "slap"
config.version = "1.2.3"
config.separator "Connection:"
config.str "-H", "--host <name>", "hostname"
config.int "-p", "--port", "port"
config.sep
config.bool "--quiet", "suppress output"
config.positional "<url>", "URL"

expected = "Usage: slap [options] <url>\n\nConnection:\n  -H, --host <name>  hostname\n  -p, --port <int>   port\n\n  --quiet            suppress output\n  -h, --help         Show this message\n  -v, --version      Show version\n"
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
text = Slap::Help.new(color).to_s
line = []
# SPINEL WORKAROUND (spinel_73.rb): Slap-shaped code can lose String#lines.
(0...text.length).each do |idx|
  char = text[idx]
  if char == "\n"
    raise "colored line too wide" if Slap::Util.width(line.join) > 80
    line = []
  else
    line << char
  end
end
raise "colored line too wide" if Slap::Util.width(line.join) > 80

color.color = false
color_off_expected = "Usage: slap [options]\n\nOptions:\n  --host <name>  hostname\n  -h, --help     Show this message\n"
assert_equal color_off_expected, Slap::Help.new(color).to_s

wrap = Slap::Config.new
wrap.app_name = "slap"
wrap.str "--long", "one two three four five six seven eight nine ten eleven twelve thirteen"
wrap_expected = "Usage: slap [options]\n\n  --long <str>  one two three four five six seven eight nine\n                ten eleven twelve thirteen\n  -h, --help    Show this message\n"
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

override = Slap::Config.new
override.app_name = "app"
override.version = "1.0.0"
override.bool "-v", "verbose output"
override_expected = "Usage: app [options]\n\n  -v          verbose output\n  -h, --help  Show this message\n  --version   Show version\n"
assert_equal override_expected, help_text(override)

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

status = nil
error = true
Slap.parse([]) do |o|
  o.app_name = "slap"
  o.exit = ->(value, message) {
    status = value
    error = message
  }
end
assert_equal 0, status
raise "wrong error" if error

puts "ok"

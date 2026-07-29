require_relative "test_helper"

assert File.read("spin.toml").include?("version = \"#{Slap::VERSION}\""), "version mismatch"

# Adapted from ../slop/test/slop_test.rb. Only Slap.parse is retained.
options = Slap.parse(["--name", "Lee"]) do |o|
  o.str "--name"
end

raise "parse failed" unless options[:name] == "Lee"

options = Slap.parse(["--", "--help"]) do |o|
  o.positional "<value>", "literal value"
end

raise "help delimiter failed" unless options[:value] == "--help"

options = Slap.parse(["--", "--version"]) do |o|
  o.version = "1.2.3"
  o.positional "<value>", "literal value"
end

raise "version delimiter failed" unless options[:value] == "--version"

options = Slap.parse(["--help", "--version", "-v"]) do |o|
  o.naked = false
  o.version = "1.2.3"
  o.bool "--help"
  o.bool "--version"
  o.bool "-v"
end

raise "help override failed" unless options[:help]
raise "long version override failed" unless options[:version]
raise "short version override failed" unless options[:v]

puts "ok"

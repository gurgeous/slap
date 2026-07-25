require_relative "test_helper"

def parse_args(args)
  config = Slap::Config.new
  config.naked = false
  yield config
  Slap::Parser.new(config).parse(args)
end

begin
  parse_args(["--gub"]) do |o|
    o.bool "--good"
  end
  raise "expected unknown option error"
rescue Slap::Error => e
  assert_equal "unexpected argument '--gub' found", e.message
end

assert_raises(Slap::Error) do
  parse_args(["--no-name"]) { _1.str "--name" }
end

begin
  parse_args([]) do |o|
    o.str "--name", required: true
  end
  raise "expected required option error"
rescue Slap::Error => e
  assert_equal "required option '--name' is missing", e.message
end

assert_raises(ArgumentError) do
  parse_args([]) { _1.str "--name", default: "Lee", required: true }
end

begin
  parse_args([]) do |o|
    o.bool "--confirm", required: true
  end
  raise "expected required boolean error"
rescue Slap::Error => e
  assert_equal "required option '--confirm' is missing", e.message
end

options = parse_args(["--no-confirm"]) do |o|
  o.bool "--confirm", required: true
end
assert_equal false, options[:confirm]

begin
  parse_args(["--count", "many"]) do |o|
    o.int "--count"
  end
  raise "expected invalid integer error"
rescue Slap::Error => e
  assert_equal "invalid value 'many' for option '--count'", e.message
end

begin
  parse_args(["--name"]) do |o|
    o.str "--name"
  end
  raise "expected missing value error"
rescue Slap::Error => e
  assert_equal "option '--name' requires a value", e.message
end

assert_raises(Slap::Error) do
  parse_args(["-qc"]) do |o|
    o.bool "-q"
    o.str "-c"
  end
end

begin
  parse_args(["--quiet=true"]) do |o|
    o.bool "--quiet"
  end
  raise "expected boolean value error"
rescue Slap::Error => e
  expected = "option '--quiet=true' does not take a value"
  assert_equal expected, e.message
end

begin
  parse_args(["--no-quiet=false"]) do |o|
    o.bool "--quiet"
  end
  raise "expected negated boolean value error"
rescue Slap::Error => e
  expected = "option '--no-quiet=false' does not take a value"
  assert_equal expected, e.message
end

begin
  parse_args(["--mode", "slow"]) do |o|
    o.sym "--mode", choices: %i[fast auto]
  end
  raise "expected choices error"
rescue Slap::Error => e
  expected = "invalid value 'slow' for option '--mode', must be one of fast, auto"
  assert_equal expected, e.message
end

begin
  parse_args(["--style", "bad"]) do |o|
    o.str "--style", choices: %w[plain fancy]
  end
  raise "expected string choices error"
rescue Slap::Error => e
  expected = "invalid value 'bad' for option '--style', must be one of plain, fancy"
  assert_equal expected, e.message
end

begin
  parse_args(["--style=bad"]) do |o|
    o.str "-s", "--style", choices: %w[plain fancy]
  end
  raise "expected inline choices error"
rescue Slap::Error => e
  expected = "invalid value 'bad' for option '--style', must be one of plain, fancy"
  assert_equal expected, e.message
end

begin
  parse_args(["-sbad"]) do |o|
    o.str "-s", "--style", choices: %w[plain fancy]
  end
  raise "expected attached choices error"
rescue Slap::Error => e
  expected = "invalid value 'bad' for option '-s', must be one of plain, fancy"
  assert_equal expected, e.message
end

begin
  parse_args(["-acbad"]) do |o|
    o.bool "-a"
    o.str "-c", choices: %w[red blue]
  end
  raise "expected short choices error"
rescue Slap::Error => e
  expected = "invalid value 'bad' for option '-c', must be one of red, blue"
  assert_equal expected, e.message
end

begin
  parse_args(["--ratio", "many"]) do |o|
    o.float "--ratio"
  end
  raise "expected invalid float error"
rescue Slap::Error => e
  expected = "invalid value 'many' for option '--ratio'"
  assert_equal expected, e.message
end

begin
  parse_args(["-c", "many"]) do |o|
    o.int "-c", "--count"
  end
  raise "expected short integer error"
rescue Slap::Error => e
  expected = "invalid value 'many' for option '-c'"
  assert_equal expected, e.message
end

begin
  parse_args([]) do |o|
    o.naked = false
    o.positional "<url>", "URL"
  end
  raise "expected required positional error"
rescue Slap::Error => e
  expected = "required argument '<url>' is missing"
  assert_equal expected, e.message
end

assert_raises(Slap::Error) do
  parse_args(["source.txt"]) do |o|
    o.positional "<source>"
    o.positional "<destination>"
  end
end

status = nil
error = nil
Slap.parse(["--gub"]) do |o|
  o.app_name = "slap"
  o.exit = ->(value, message) {
    status = value
    error = message
  }
end

raise "wrong exit status" unless status == 1
assert_equal "unexpected argument '--gub' found", error

puts "ok"

require_relative "test_helper"
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
  "--plus", "+30", "--numeric-symbol", "12345", "--ratio", "+9.4", "--scientific", "4e-21", "--verbose",
  "--no-inversed",
]) do |o|
  o.str "--name"
  o.sym "--method"
  o.int "--age"
  o.int "--plus"
  o.sym "--numeric-symbol"
  o.float "--ratio"
  o.float "--scientific"
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
  o.sym "--sym", default: :fast
  o.bool "--bool"
  o.bool "--enabled", default: true
  o.bool "--disabled", default: false
  o.str "--nil", default: nil
end

assert_equal "hello", options[:str]
assert_equal 12, options[:int]
assert_equal 1.25, options[:float]
assert_equal :fast, options[:sym]
assert_equal false, options[:bool]
assert_equal true, options[:enabled]
assert_equal false, options[:disabled]
assert_equal nil, options[:nil]

#
# choices
#

options = Slap.parse(["--str", "red", "--int", "2", "--float", "2.5", "--sym", "fast"]) do |o|
  o.str "--str", choices: %w[red blue]
  o.int "--int", choices: [1, 2]
  o.float "--float", choices: [1.5, 2.5]
  o.sym "--sym", choices: %i[slow fast]
end

assert_equal "red", options[:str]
assert_equal 2, options[:int]
assert_equal 2.5, options[:float]
assert_equal :fast, options[:sym]

puts "ok"

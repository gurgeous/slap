require_relative "test_helper"

# Adapted from ../slop/test/result_test.rb. Slap returns OpenStruct so options
# have method access while retaining [] access for dynamic keys.
options = Slap.parse(["--name", "lee"]) do |o|
  o.version = "1.2.3"
  o.str "--name"
  o.str "--unused", default: "default"
end

assert_equal "lee", options.name
assert_equal "default", options.unused
assert_equal "lee", options[:name]
assert_equal "default", options[:unused]
assert_equal nil, options.missing
assert_equal nil, options[:missing]
raise "expected frozen options" unless options.frozen?
assert_raises(FrozenError) { options[:name] = "bob" }
raise "expected no leftovers" unless options._args.empty?
raise "expected no leftovers" unless options[:_args].empty?
raise "unexpected help" if options.to_h.key?(:help)
raise "unexpected version" if options.to_h.key?(:version)

puts "ok"

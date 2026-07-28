require "slap"

# SPINEL WORKAROUND: `spin test --regen` captures stdout only, while
# `spin test` compares stdout+stderr. Route stderr writes through stdout so
# regenerated snapshots stay valid until https://github.com/matz/spinel/issues/3405
# is fixed. Do not assign `$stderr = $stdout`; see spinel_75.rb.
class TestStderr
  def write(value) = $stdout.write(value)
  def puts(value = "") = $stdout.puts(value)
end

$stderr = TestStderr.new

#
# helpers
#

def assert(value, message = "expected truthy")
  raise message unless value
end

def assert_equal(exp, actual)
  raise "expected #{exp.inspect}, got #{actual.inspect}" unless exp == actual
end

def assert_raises(error_class)
  yield
  raise "expected #{error_class}"
rescue error_class => e
  e
end

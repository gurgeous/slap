require "slap"

# SPINEL WORKAROUND, see spinel_76.md
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

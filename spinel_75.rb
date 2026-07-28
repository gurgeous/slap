# Bug: assigning `$stderr = $stdout` does not route later stderr writes through
# the reassigned stream.
#
# Ruby result:
#   stdout:
#     err
#     out
#   stderr:
#     <empty>
#
# Spinel result:
#   stdout:
#     out
#   stderr:
#     err
#     FAIL (RuntimeError)
#
# Repro:
#   ruby spinel_75.rb > build/ruby-75.out 2> build/ruby-75.err
#   spinel -o build/crash-75 spinel_75.rb
#   build/crash-75 > build/spinel-75.out 2> build/spinel-75.err
#
$stderr = $stdout
$stderr.puts "err"
puts "out"

# keep
raise "FAIL" unless $stderr == $stdout

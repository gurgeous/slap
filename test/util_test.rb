require_relative "test_helper"

blue = "\e[34mblue\e[0m"
assert_equal 5, Slap::Util.width("plain")
assert_equal 4, Slap::Util.width(blue)
assert_equal 4, Slap::Util.width("\e[1;34mblue\e[0m")
assert_equal "", Slap::Util.wrap("", 10)
assert_equal "", Slap::Util.wrap(" \t\r ", 10)
assert_equal "\none", Slap::Util.wrap("\none", 10)
assert_equal "one\n\nthree", Slap::Util.wrap("one\n\nthree", 10)
assert_equal "\n", Slap::Util.wrap("\n", 10)
assert_equal "one two", Slap::Util.wrap("one two", 7)
assert_equal "one two\nthree", Slap::Util.wrap("one two three", 7)
assert_equal "one\ntwo", Slap::Util.wrap("one two", 0)
assert_equal "abcdefgh", Slap::Util.wrap("abcdefgh", 3)
assert_equal "one two", Slap::Util.wrap("  one\t two  ", 20)
assert_equal "#{blue} one\ntwo", Slap::Util.wrap("#{blue} one two", 8)
assert_equal "one two\nthree four", Slap::Util.wrap("one\ttwo\nthree four", 20)
assert_equal "one\n", Slap::Util.wrap("one\n", 20)

puts "ok"

# BUG: after requiring pathname, Slap-shaped code loses String#split in Util.wrap.
# https://github.com/matz/spinel/issues/3401
# Bad line: `require "pathname"` before String#split is called.
# Ruby: wraps text.
# Spinel: raises undefined method split for String.

require "pathname"

class Help
  attr_reader :config
  def banner = Util.wrap(1)
end

module Util
  def self.wrap(str, columns) = str.split(nil).join(" ")
end

text = Util.wrap("one two", 7)

# keep
raise "FAIL #{text.inspect}" unless text == "one two"

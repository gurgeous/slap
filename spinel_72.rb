# BUG: Slap-shaped code loses String#each_char in Util.wrap.
# https://github.com/matz/spinel/issues/3402
# Bad line: `str.each_char` after String#split is avoided.
# Ruby: wraps text.
# Spinel: raises undefined method each_char for String.

def banner
  text = {}
  Util.wrap(text)
end

module Slap
  module Util
    module_function

    def wrap(str, columns)
      lines, words = [], []
      wrap_tokens(str)
        .each do |word|
          words << word
        end
      lines << words
      lines.join("\n")
    end

    def wrap_tokens(str)
      tokens, chars = [], []
      str.each_char do |char|
        chars << char
      end
      tokens << chars.join
    end
  end
end
text = Slap::Util.wrap("one two", 7)

# keep
raise "FAIL #{text.inspect}" unless text == "one two"

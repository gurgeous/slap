#
# Shared helpers
#

module Slap
  module Util
    module_function

    ANSI_RE = /\e\[[\d;]*m/

    # Calculate terminal width, defaulting to 80.
    def termwidth
      width = 80
      if $stdout.tty?
        w = $stdout.winsize[1]
        width = w if w > 0
      end
      width
    end

    # Measure characters while ignoring ANSI control sequences.
    def width(str) = str.gsub(ANSI_RE, "").length

    # Return word-wrapped text. ANSI width is understood for alignment, but
    # callers do not wrap live colored regions across lines; help/body text is
    # plain, and generated colored usage is short enough to stay on one line.
    def wrap(str, columns)
      return "" if str.empty?

      lines, words = [], []
      tokens = wrap_tokens(str)
      tokens.each do |word|
        if word == "\n"
          lines << words.join(" ")
          words = []
          next
        end
        if !words.empty? && width("#{words.join(" ")} #{word}") > columns
          lines << words.join(" ")
          words = []
        end

        words << word
      end
      lines << words.join(" ") unless words.empty?
      lines << "" if tokens.last == "\n"
      lines.join("\n")
    end

    # SPINEL WORKAROUND (spinel_71.rb, spinel_72.rb): Slap-shaped code can lose
    # String#split and String#each_char.
    def wrap_tokens(str)
      tokens, chars = [], []
      (0...str.length).each do |idx|
        char = str[idx]
        if char == "\n"
          tokens << chars.join unless chars.empty?
          chars = []
          tokens << char
        elsif char == " " || char == "\t" || char == "\r"
          tokens << chars.join unless chars.empty?
          chars = []
        else
          chars << char
        end
      end
      tokens << chars.join unless chars.empty?
      tokens
    end
  end
end

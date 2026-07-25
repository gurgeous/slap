#
# A simple color toggle that can format text. If unset infer from stdout.tty.
#

module Slap
  class Color
    attr_reader :enabled
    alias_method :enabled?, :enabled

    def initialize(enabled)
      @enabled = enabled.nil? ? $stdout.tty? : enabled
    end

    # one-liners
    def blue(str) = paint(str, 34)
    def cyan(str) = paint(str, 36)
    def green(str) = paint(str, 32)
    def magenta(str) = paint(str, 35)
    def red(str) = paint(str, 31)
    def yellow(str) = paint(str, 33)

    protected

    def paint(str, code)
      enabled? ? "\e[1;#{code}m#{str}\e[0m" : str
    end
  end
end

# Regexp#match? on an attr-reader array element loses String type.
# https://github.com/matz/spinel/issues/3374

class Flag
  SWITCH_RE = /\A-(\w|-\w[\w-]*)\z/
  attr_reader :switches
  def initialize
    validate
  end
  protected
  def validate
    switches.each do |xxx|
      raise ArgumentError, "invalid switch: #{xxx}" unless xxx.match?(SWITCH_RE)
    end
  end
end

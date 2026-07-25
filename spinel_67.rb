# A multi-class rescue with a case on the captured exception loses the branch.
# https://github.com/matz/spinel/issues/3373

module App
  class HelpRequested < RuntimeError; end
  class Main
    def parse
      raise HelpRequested
    rescue HelpRequested => e
      case e
      when HelpRequested then $events << "help"
      end
    end
  end
end

$events = []
App::Main.new.parse

# reduce:freeze (do not modify anything below this line)
raise "FAIL" unless $events == ["help"]

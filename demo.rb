require "slap"

options = Slap.parse do |o|
  o.app_name = "demo"
  o.version = "0.1.0"

  o.str "-d", "--data", "HTTP POST data"
  o.bool "-L", "--location", "follow redirects"
  o.int "-m", "--max-time <seconds>", "maximum transfer time"

  o.separator
  o.bool "--force", "ignore cached responses"
  o.str "--style <format>", "output style", choices: %w[json xml]

  o.positional "<url>", "URL to fetch"
end

p options

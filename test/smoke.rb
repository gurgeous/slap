require "slap"

options = Slap.parse do |o|
  o.app_name = "smoke"
  o.bool "-v", "--verbose", "verbose output"
  o.int "-n", "--count <n>", "count"
  o.str "-m", "--mode <mode>", "mode", choices: %w[fast slow]
  o.path "-o", "--output <path>", "output path"
  o.positional "<url>", "URL"
end

p options

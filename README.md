[![test](https://github.com/gurgeous/slap/actions/workflows/ci.yml/badge.svg)](https://github.com/gurgeous/slap/actions/workflows/ci.yml)

# Slap

Slap is a [spinel](https://github.com/matz/spinel) package for parsing cli arguments. `slap` combines the best bits from [slop rb](https://github.com/leejarvis/slop) and [clap rs](https://github.com/clap-rs/clap).

### Caution

Both spinel and slap are alpha quality as of July '26. Slap is a proof of concept and flushed out many real spinel bugs. I hope to release slap once spinel is a bit further along.

### Key Features

- auto supports --help, with ansi colors
- auto supports --version
- wraps --help to fit terminal width
- allows long (--hello), short (-x), and smashed (-xyz) arguments
- flags can be `required:`, have `default:`, or have enum `choices:`
- returns OpenStruct (not hash)

If there is interest I can release this as a rubygem, though there are already many great cruby cli gems.

### Installation

```toml
# spin.toml
[dependencies]
slap = { git = "https://github.com/gurgeous/spinel-slap" }
```

### Usage

```ruby
require "slap"

options = Slap.parse do |o|
  o.app_name = "demo"
  o.version = "0.1.0"

  o.str "-d", "--data", "HTTP POST data"
  o.bool "-L", "--location", "follow redirects"
  o.int "-m", "--max-time <seconds>", "maximum transfer time"
  o.path "-o", "--output <filename>", "where to save file"
  o.separator

  o.bool "--force", "ignore cached responses"
  o.str "--style <format>", "output style", choices: %w[json xml]

  o.positional "<url>", "URL to fetch"
end
p options
```

### Demo

`$ demo --help`

<img width="488" height="225" alt="image" src="https://github.com/user-attachments/assets/fa44af7a-f6b0-4e80-9614-6eca77c2e6ab" />

```
$ demo -L -m 8 --style json --force https://example.com
<OpenStruct
  data=nil, location=true, max_time=8, force=true,
  style="json", url="https://example.com", _args=[]
>
```

### Changelog

#### 0.1.0 (unreleased)

- initial release (planned)

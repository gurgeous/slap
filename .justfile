default:
  just --list

check: lint test

fmt:
  bundle exec rubocop -a

lint:
  bundle exec rubocop

demo:
  spinel -I . demo.rb -o build/demo

test:
  just test-cruby
  just test-spinel
  just test-bats
  just banner "done"

test-bats *ARGS:
  just banner "test-bats..."
  spinel -I . test/smoke.rb -o build/test/smoke
  mise exec -- bats {{ARGS}} --print-output-on-failure test/smoke.bats

test-cruby:
  just banner "test-cruby..."
  bin/test-cruby

test-spinel:
  just banner "test-spinel..."
  spin test

test-watch:
  watchexec --clear=reset "just test"

#
# spinel
#

spinel-check:
  bin/spinel-check

# run spinel against one spine bug, or latest bug
spinel-watch *ARGS:
  bin/spinel-watch "{{ARGS}}"

#
# ci
#

ci: spinel-install check

spinel-install:
  if [ -d ../spinel ]; then \
    git -C ../spinel pull; \
  else \
    git clone https://github.com/matz/spinel.git ../spinel; \
  fi
  (cd ../spinel && make deps && make && sudo make install)
  spinel --version

#
# banner
#

set quiet

banner +ARGS:  (_banner '\e[48;2;064;160;043m' ARGS)
warning +ARGS: (_banner '\e[48;2;251;100;011m' ARGS)
fatal +ARGS:   (_banner '\e[48;2;210;015;057m' ARGS)
  exit 1
_banner BG +ARGS:
  printf '\e[38;5;231m{{BOLD+BG}}[%s] %-72s {{NORMAL}}\n' "$(date +%H:%M:%S)" "{{ARGS}}"

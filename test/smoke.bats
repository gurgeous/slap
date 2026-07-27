#!/usr/bin/env bats

setup() {
  ROOT="$BATS_TEST_DIRNAME/.."
  BIN="$ROOT/build/test/smoke"
}

@test "naked" {
  run "$BIN"
  [ "$status" -eq 0 ]
  [ "$output" = "smoke: try 'smoke --help' for more information" ]
}

@test "success" {
  run "$BIN" -v -n 8 --mode fast --output tmp/out.txt https://example.com
  [ "$status" -eq 0 ]
  [[ "$output" == *"verbose=true"* ]]
  [[ "$output" == *"count=8"* ]]
  [[ "$output" == *'mode="fast"'* ]]
  [[ "$output" == *'output=#<Pathname:tmp/out.txt>'* ]]
  [[ "$output" == *'url="https://example.com"'* ]]
}

@test "short flags" {
  run "$BIN" -v -n 8 -m fast -o tmp/out.txt https://example.com
  [ "$status" -eq 0 ]
  [[ "$output" == *"verbose=true"* ]]
  [[ "$output" == *"count=8"* ]]
  [[ "$output" == *'mode="fast"'* ]]
  [[ "$output" == *'output=#<Pathname:tmp/out.txt>'* ]]
}

@test "long flags" {
  run "$BIN" --verbose --count 8 --mode fast --output tmp/out.txt https://example.com
  [ "$status" -eq 0 ]
  [[ "$output" == *"verbose=true"* ]]
  [[ "$output" == *"count=8"* ]]
  [[ "$output" == *'mode="fast"'* ]]
  [[ "$output" == *'output=#<Pathname:tmp/out.txt>'* ]]
}

@test "smashed flags" {
  run "$BIN" -vn 8 --mode fast https://example.com
  [ "$status" -eq 0 ]
  [[ "$output" == *"verbose=true"* ]]
  [[ "$output" == *"count=8"* ]]
  [[ "$output" == *'mode="fast"'* ]]
}

@test "inline long value" {
  run "$BIN" -v --count=8 --mode=fast https://example.com
  [ "$status" -eq 0 ]
  [[ "$output" == *"verbose=true"* ]]
  [[ "$output" == *"count=8"* ]]
  [[ "$output" == *'mode="fast"'* ]]
}

@test "smashed flag with attached value" {
  run "$BIN" -vn8 --mode fast https://example.com
  [ "$status" -eq 0 ]
  [[ "$output" == *"verbose=true"* ]]
  [[ "$output" == *"count=8"* ]]
  [[ "$output" == *'mode="fast"'* ]]
}

@test "smashed flag with trailing attached value" {
  run "$BIN" -vmslow -n 8 https://example.com
  [ "$status" -eq 0 ]
  [[ "$output" == *"verbose=true"* ]]
  [[ "$output" == *"count=8"* ]]
  [[ "$output" == *'mode="slow"'* ]]
}

@test "help" {
  run "$BIN" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: smoke [options] <url>"* ]]
  [[ "$output" == *"-m, --mode <mode>    mode"* ]]
  [[ "$output" == *"-o, --output <path>  output path"* ]]
  [[ "$output" == *"-h, --help           Show this message"* ]]
}

@test "failure" {
  run "$BIN" --mode bogus https://example.com
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid value 'bogus' for option '--mode'"* ]]
  [[ "$output" == *"smoke: try 'smoke --help' for more information"* ]]
}

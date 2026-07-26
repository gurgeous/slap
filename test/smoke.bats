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
  run "$BIN" -v -n 8 --mode fast https://example.com
  [ "$status" -eq 0 ]
  [[ "$output" == *"verbose=true"* ]]
  [[ "$output" == *"count=8"* ]]
  [[ "$output" == *'mode="fast"'* ]]
  [[ "$output" == *'url="https://example.com"'* ]]
}

@test "failure" {
  run "$BIN" --mode bogus https://example.com
  [ "$status" -eq 1 ]
  [[ "$output" == *"invalid value 'bogus' for option '--mode'"* ]]
  [[ "$output" == *"smoke: try 'smoke --help' for more information"* ]]
}

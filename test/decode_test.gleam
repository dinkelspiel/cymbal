import cymbal.{block, string}
import decode.{decode}
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn decode_basic_test() {
  "---
name: Example
version: 1.0.0
"
  |> decode
  |> should.equal(
    block([#("name", string("Example")), #("version", string("1.0.0"))]),
  )
}

import cymbal.{array, block, string}
import decode.{decode}
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn decode_basic_test() {
  "name: Example
version: 1.0.0
map:
  key1: value1
  key2: value2
  nested_map:
    nested_key1: nested_value1
    nested_key2: nested_value2
sequence:
  - value 1
  - value 2"
  |> decode
  |> should.equal(
    Ok(
      block([
        #("name", string("Example")),
        #("version", string("1.0.0")),
        #(
          "map",
          block([
            #("key1", string("value1")),
            #("key2", string("value2")),
            #(
              "nested_map",
              block([
                #("nested_key1", string("nested_value1")),
                #("nested_key2", string("nested_value2")),
              ]),
            ),
          ]),
        ),
        #("sequence", array([string("value 1"), string("value 2")])),
      ]),
    ),
  )
}

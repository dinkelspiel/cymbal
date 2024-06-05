import cymbal.{decode}
import cymbal/decode.{
  Colon, Dash, Indent, Key, Newline, Pipe, RightArrow, Value, tokenize_lines,
}
import cymbal/encode.{array, block, string}
import gleam/string
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn decode_map_test() {
  "---
name: Example
version: 1.0.0
map:
  key1: value1
  key2: value2
  nested_map:
    nested_key1: nested_value1
    nested_key2: nested_value2"
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
      ]),
    ),
  )
}

pub fn decode_sequence_test() {
  "sequence:
  - value 1
  - value 2"
  |> decode
  |> should.equal(
    Ok(block([#("sequence", array([string("value 1"), string("value 2")]))])),
  )
}

pub fn tokenizer_basic_test() {
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
  |> string.split("\n")
  |> tokenize_lines
  |> should.equal([
    Indent(0),
    Key("name"),
    Colon,
    Value("Example"),
    Newline,
    Indent(0),
    Key("version"),
    Colon,
    Value("1.0.0"),
    Newline,
    Indent(0),
    Key("map"),
    Colon,
    Newline,
    Indent(2),
    Key("key1"),
    Colon,
    Value("value1"),
    Newline,
    Indent(2),
    Key("key2"),
    Colon,
    Value("value2"),
    Newline,
    Indent(2),
    Key("nested_map"),
    Colon,
    Newline,
    Indent(4),
    Key("nested_key1"),
    Colon,
    Value("nested_value1"),
    Newline,
    Indent(4),
    Key("nested_key2"),
    Colon,
    Value("nested_value2"),
    Newline,
    Indent(0),
    Key("sequence"),
    Colon,
    Newline,
    Indent(2),
    Dash,
    Value("value 1"),
    Newline,
    Indent(2),
    Dash,
    Value("value 2"),
    Newline,
  ])
}

pub fn tokenizer_block_scalar_test() {
  "folded_description: >
  This is my description
  which will not contain
  any newlines.
literal_description: |
  This is my description
  which will preserve
  each newline."
  |> string.split("\n")
  |> tokenize_lines
  |> should.equal([
    Indent(0),
    Key("folded_description"),
    Colon,
    RightArrow,
    Newline,
    Indent(2),
    Value("This is my description"),
    Newline,
    Indent(2),
    Value("which will not contain"),
    Newline,
    Indent(2),
    Value("any newlines."),
    Newline,
    Indent(0),
    Key("literal_description"),
    Colon,
    Pipe,
    Newline,
    Indent(2),
    Value("This is my description"),
    Newline,
    Indent(2),
    Value("which will preserve"),
    Newline,
    Indent(2),
    Value("each newline."),
    Newline,
  ])
}

import cymbal.{type Yaml, string}
import decode/parser.{parse_tokens}
import decode/tokenizer.{tokenize_lines}
import gleam/io
import gleam/string

pub fn decode(value: String) -> Result(Yaml, String) {
  io.debug(value)
  io.debug(
    string.split(value, "\n")
    |> tokenize_lines
    |> parse_tokens,
  )
  Ok(string("test"))
}

import cymbal/decode/parser.{parse_tokens}
import cymbal/decode/tokenizer.{tokenize_lines}
import cymbal/encode.{en}
import cymbal/yaml.{type Yaml, Array, Block, Bool, Float, Int, String, string}
import gleam/io
import gleam/string

/// Convert a YAML document into a string.
///
pub fn encode(doc: Yaml) -> String {
  let start = case doc {
    Bool(_) | Int(_) | Float(_) | String(_) -> "---\n"
    Array(_) | Block(_) -> "---"
  }

  en(start, 0, doc) <> "\n"
}

/// Convert a string into a YAML document.
///
pub fn decode(value: String) -> Result(Yaml, String) {
  io.debug(value)
  io.debug(
    string.split(value, "\n")
    |> tokenize_lines
    |> parse_tokens,
  )
  Ok(string("test"))
}

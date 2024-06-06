import cymbal/decode.{parse_tokens, tokenize_lines}
import cymbal/encode.{
  type Yaml, Array, Block, Bool, Float, Int, String, en, string,
}
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

/// Convert a YAML document into a string without the document start.
///
pub fn encode_without_document_start(doc: Yaml) -> String {
  en("", 0, doc) <> "\n"
}

/// Convert a string into a YAML document.
///
pub fn decode(value: String) -> Result(Yaml, String) {
  string.split(value, "\n")
  |> tokenize_lines
  |> parse_tokens
}

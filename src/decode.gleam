import cymbal.{type Yaml, string}
import gleam/io

pub fn decode(value: String) -> Result(Yaml, String) {
  io.println(value)
  Ok(string("test"))
}

fn tokenize_lines(value)

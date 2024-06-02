import cymbal.{type Yaml, string}
import gleam/io
import gleam/list
import gleam/string

type Token {
  Test
}

pub fn decode(value: String) -> Result(Yaml, String) {
  io.println(value)
  io.debug(
    string.split(value, "\n")
    |> tokenize_lines,
  )
  Ok(string("test"))
}

fn tokenize_lines(value: List(String)) {
  value
  |> list.map(tokenize_line)
}

fn tokenize_line(line: String) {
  Test
}

import cymbal.{type Yaml, string}
import gleam/io
import gleam/list
import gleam/result
import gleam/string

type Token {
  Dash
  Colon
  Newline
  Key(String)
  Value(String)
  Indent(Int)
}

pub fn decode(value: String) -> Result(Yaml, String) {
  io.debug(value)
  io.debug(
    string.split(value, "\n")
    |> tokenize_lines,
  )
  Ok(string("test"))
}

fn tokenize_lines(value: List(String)) {
  value
  |> list.flat_map(tokenize_line)
}

fn tokenize_line(line: String) {
  let stripped = string.trim(line)
  let indent = count_leading_spaces(line)

  case string.first(stripped) {
    Ok(value) if value == "-" -> {
      [Indent(indent), Dash, Key(string.drop_left(stripped, 2)), Newline]
    }
    Ok(_) ->
      case string.contains(stripped, ": ") {
        True -> [
          Indent(indent),
          Key(
            string.split(stripped, ": ")
            |> list.first
            |> result.unwrap(""),
          ),
          Colon,
          Value(
            string.split(stripped, ": ")
            |> list.rest
            |> result.unwrap([])
            |> string.join(": "),
          ),
          Newline,
        ]
        False ->
          case string.contains(stripped, ":") {
            True -> [
              Indent(indent),
              Key(
                string.split(stripped, ": ")
                |> list.first
                |> result.unwrap(""),
              ),
              Colon,
              Newline,
            ]
            False ->
              panic as string.append("Tokenizer unimplemented for ", line)
          }
      }

    Error(_) -> panic as "Error in tokenizer"
    // _ -> panic as string.append("Tokenizer unimplemented for ", line) 
  }
}

fn count_leading_spaces(line: String) -> Int {
  line
  |> string.split("")
  |> list.take_while(fn(char) { char == " " })
  |> list.length
}

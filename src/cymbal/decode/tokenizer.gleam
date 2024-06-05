import cymbal/decode/types.{Colon, Dash, Indent, Key, Newline, Value}
import cymbal/yaml.{string}
import gleam/list
import gleam/result
import gleam/string

pub fn tokenize_lines(value: List(String)) {
  value
  |> list.flat_map(tokenize_line)
}

fn tokenize_line(line: String) {
  let stripped = string.trim(line)
  let indent = count_leading_spaces(line)

  case string.first(stripped) {
    Ok(value) if value == "-" -> {
      [Indent(indent), Dash, Value(string.drop_left(stripped, 2)), Newline]
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
                string.split(stripped, ":")
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

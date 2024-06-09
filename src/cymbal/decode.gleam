import cymbal/encode.{type Yaml, array, block, string}
import gleam/float
import gleam/int
import gleam/list
import gleam/result
import gleam/string

pub type Token {
  Dash
  Colon
  Newline
  Key(String)
  Value(String)
  Indent(Int)
  Pipe
  RightArrow
}

pub fn tokenize_lines(value: List(String)) {
  let tokens =
    value
    |> list.flat_map(tokenize_line)

  let document_indent_size = get_indent_size(tokens)

  tokens
  |> list.map(fn(a) {
    case a {
      Indent(indent) -> Indent(indent / document_indent_size)
      _ -> a
    }
  })
}

fn get_indent_size(tokens: List(Token)) -> Int {
  case tokens {
    [Indent(indent), ..] if indent > 0 -> indent
    [_, ..rest] -> get_indent_size(rest)
    [] -> 0
  }
}

fn tokenize_line(line: String) {
  let stripped = case list.first(string.split(string.trim(line), " #")) {
    Ok(value) -> value
    Error(_) -> ""
  }
  let indent = count_leading_spaces(line)

  case string.first(stripped) {
    Ok(value) if value == "-" -> {
      case stripped {
        "---" -> []

        _ ->
          case string.contains(stripped, ": ") {
            True -> [
              Indent(indent),
              Dash,
              Key(
                string.split(stripped, ": ")
                |> list.first
                |> result.unwrap("")
                |> string.drop_left(2),
              ),
              Colon,
              case
                string.split(stripped, ": ")
                |> list.rest
                |> result.unwrap([])
                |> string.join(": ")
              {
                ">" -> RightArrow
                "|" -> Pipe
                _ ->
                  Value(
                    string.split(stripped, ": ")
                    |> list.rest
                    |> result.unwrap([])
                    |> string.join(": "),
                  )
              },
              Newline,
            ]
            False ->
              case string.contains(stripped, ":\n") {
                True -> [
                  Indent(indent),
                  Dash,
                  Value(string.drop_left(stripped, 2)),
                  Colon,
                  Newline,
                ]
                False -> [
                  Indent(indent),
                  Dash,
                  Value(string.drop_left(stripped, 2)),
                  Newline,
                ]
              }
          }
      }
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
          case
            string.split(stripped, ": ")
            |> list.rest
            |> result.unwrap([])
            |> string.join(": ")
          {
            ">" -> RightArrow
            "|" -> Pipe
            _ ->
              Value(
                string.split(stripped, ": ")
                |> list.rest
                |> result.unwrap([])
                |> string.join(": "),
              )
          },
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
            False -> [Indent(indent), Value(stripped), Newline]
          }
      }

    Error(_) -> []
  }
}

fn count_leading_spaces(line: String) -> Int {
  line
  |> string.split("")
  |> list.take_while(fn(char) { char == " " })
  |> list.length
}

pub fn parse_tokens(tokens: List(Token)) -> Result(Yaml, String) {
  let #(result, _) = case tokens {
    [Indent(_), Dash, ..] -> parse_array(tokens, 0)
    _ -> parse_block(tokens, 0)
  }

  Ok(result)
}

fn parse_block(tokens: List(Token), indent: Int) -> #(Yaml, List(Token)) {
  let items = []
  parse_block_items(tokens, indent, items)
}

fn parse_block_items(
  tokens: List(Token),
  indent: Int,
  items: List(#(String, Yaml)),
) -> #(Yaml, List(Token)) {
  case tokens {
    [] -> #(block(items), tokens)

    [Indent(current_indent), ..] if current_indent < indent -> #(
      block(items),
      tokens,
    )

    [Indent(current_indent), Key(key), Colon, Value(value), Newline, ..rest] if current_indent
      == indent ->
      parse_block_items(
        rest,
        indent,
        list.append(items, [#(key, parse_value(value))]),
      )

    [Indent(current_indent), Key(key), Colon, Newline, ..rest] if current_indent
      == indent -> {
      let #(nested_block, remaining_tokens) = parse_block(rest, indent + 1)
      parse_block_items(
        remaining_tokens,
        indent,
        list.append(items, [#(key, nested_block)]),
      )
    }

    // TODO: Make the following two cases into one as only the Fold/Keep changes
    [Indent(current_indent), Key(key), Colon, RightArrow, Newline, ..rest] if current_indent
      == indent -> {
      let #(multiline_string, new_tokens) =
        parse_block_scalar(rest, "", current_indent + 1, Fold)

      parse_block_items(
        new_tokens,
        indent,
        list.append(items, [#(key, parse_value(multiline_string))]),
      )
    }

    [Indent(current_indent), Key(key), Colon, Pipe, Newline, ..rest] if current_indent
      == indent -> {
      let #(multiline_string, new_tokens) =
        parse_block_scalar(rest, "", current_indent + 1, Keep)

      parse_block_items(
        new_tokens,
        indent,
        list.append(items, [#(key, parse_value(multiline_string))]),
      )
    }

    [Indent(current_indent), Dash, Value(_), Newline, ..] if current_indent
      == indent -> parse_array(tokens, indent)

    [Indent(current_indent), Dash, Key(_), Colon, Value(_), Newline, ..] if current_indent
      == indent -> parse_array(tokens, indent)

    _ -> #(block(items), tokens)
  }
}

type BlockScalarType {
  Fold
  Keep
}

fn parse_block_scalar(
  tokens: List(Token),
  value: String,
  indent: Int,
  block_type: BlockScalarType,
) -> #(String, List(Token)) {
  case tokens {
    [Indent(current_indent), ..] if current_indent >= indent ->
      case block_type {
        Fold -> {
          let #(line_as_string, new_tokens) =
            tokens_to_string_until_newline(tokens, "", indent)
          parse_block_scalar(
            new_tokens,
            value
              <> case value {
              "" -> ""
              _ -> " "
            }
              <> line_as_string,
            indent,
            block_type,
          )
        }
        Keep -> {
          let #(line_as_string, new_tokens) =
            tokens_to_string_until_newline(tokens, "", indent)
          parse_block_scalar(
            new_tokens,
            value
              <> case value {
              "" -> ""
              _ -> "\n"
            }
              <> line_as_string,
            indent,
            block_type,
          )
        }
      }

    _ -> #(value, tokens)
  }
}

fn tokens_to_string_until_newline(
  tokens: List(Token),
  current_value: String,
  indent: Int,
) -> #(String, List(Token)) {
  case tokens {
    [Indent(current_indent), ..rest] ->
      tokens_to_string_until_newline(
        rest,
        current_value <> create_spaces(current_indent - indent, ""),
        indent,
      )
    [Dash, ..rest] ->
      tokens_to_string_until_newline(rest, current_value <> "-", indent)
    [Colon, Newline, ..rest] ->
      tokens_to_string_until_newline(rest, current_value <> ":\n", indent)
    [Colon, ..rest] ->
      tokens_to_string_until_newline(rest, current_value <> ": ", indent)
    [Key(key), ..rest] ->
      tokens_to_string_until_newline(rest, current_value <> key, indent)
    [Value(value), ..rest] ->
      tokens_to_string_until_newline(rest, current_value <> value, indent)
    [Pipe, Newline, ..rest] ->
      tokens_to_string_until_newline(rest, current_value <> "|\n", indent)
    [Pipe, ..rest] ->
      tokens_to_string_until_newline(rest, current_value <> "| ", indent)
    [RightArrow, ..rest] ->
      tokens_to_string_until_newline(rest, current_value <> ">", indent)
    [Newline, ..rest] -> #(current_value, rest)
    [] -> #(current_value, tokens)
  }
}

fn create_spaces(count: Int, acc: String) -> String {
  case count {
    0 -> acc
    _ -> create_spaces(count - 1, acc <> "  ")
  }
}

fn parse_array(tokens: List(Token), indent: Int) -> #(Yaml, List(Token)) {
  parse_array_items(tokens, indent, [])
}

fn parse_array_items(
  tokens: List(Token),
  indent: Int,
  items: List(Yaml),
) -> #(Yaml, List(Token)) {
  case tokens {
    [] -> #(array(items), tokens)

    [
      Indent(current_indent),
      Dash,
      Key(key),
      Colon,
      Value(value),
      Newline,
      ..rest
    ] -> {
      let #(block, new_tokens) =
        parse_block_items(rest, current_indent + 1, [#(key, parse_value(value))])
      parse_array_items(new_tokens, current_indent, list.append(items, [block]))
    }

    [Indent(_), Dash, Dash, ..] -> {
      panic as "Nested sequences are not implemented"
    }

    [Indent(current_indent), Dash, Value(value), Newline, ..rest] if current_indent
      == indent ->
      parse_array_items(
        rest,
        current_indent,
        list.append(items, [parse_value(value)]),
      )

    _ -> #(array(items), tokens)
  }
}

fn parse_value(value: String) -> Yaml {
  case float.parse(value) {
    Ok(float) -> encode.float(float)
    _ ->
      case int.parse(value) {
        Ok(int) -> encode.int(int)
        _ ->
          case
            octal_to_decimal(string.drop_left(value, 2)),
            string.starts_with(value, "0o")
          {
            Ok(decimal), True -> encode.int(decimal)
            _, _ ->
              case
                value == "false"
                || value == "False"
                || value == "FALSE"
                || value == "true"
                || value == "True"
                || value == "TRUE"
              {
                True -> encode.bool(value == "true")
                _ ->
                  case
                    value == "null"
                    || value == "Null"
                    || value == "NULL"
                    || value == "~"
                  {
                    True -> encode.null()
                    _ ->
                      encode.string(string.replace(
                        string.replace(value, "\"", ""),
                        "'",
                        "",
                      ))
                  }
              }
          }
      }
  }
}

fn octal_digit_to_decimal(octal_char: String) -> Result(Int, String) {
  case octal_char {
    "0" -> Ok(0)
    "1" -> Ok(1)
    "2" -> Ok(2)
    "3" -> Ok(3)
    "4" -> Ok(4)
    "5" -> Ok(5)
    "6" -> Ok(6)
    "7" -> Ok(7)
    _ -> Error("Invalid octal digit")
  }
}

fn octal_to_decimal(octal: String) -> Result(Int, String) {
  let octal_chars = string.split(octal, "")
  let length = list.length(octal_chars)

  list.index_fold(octal_chars, Ok(0), fn(acc, char, index) {
    case acc, octal_digit_to_decimal(char) {
      Ok(acc_value), Ok(digit) -> {
        let position_value =
          digit
          * float.round(result.unwrap(
            int.power(8, int.to_float(length - 1 - index)),
            1.0,
          ))
        Ok(acc_value + position_value)
      }

      Error(e), _ -> Error(e)
      _, Error(e) -> Error(e)
    }
  })
}

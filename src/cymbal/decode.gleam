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

/// Tokenizes all strings in a given list of string as lines in a yaml document
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

/// Returns the first indent in a yaml document that isn't 0
fn get_indent_size(tokens: List(Token)) -> Int {
  case tokens {
    [Indent(indent), ..] if indent > 0 -> indent
    [_, ..rest] -> get_indent_size(rest)
    [] -> 0
  }
}

/// Gets a list of tokens for a given line in a yaml document
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
        _ -> tokenize_sequence_item(stripped, indent)
      }
    }

    Ok(_) -> tokenize_key_value_pair(stripped, indent)
    Error(_) -> []
  }
}

fn count_leading_spaces(line: String) -> Int {
  line
  |> string.split("")
  |> list.take_while(fn(char) { char == " " })
  |> list.length
}

fn get_tokenized_value_or_block_scalar_indicator(stripped: String) {
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
  }
}

/// Tokenize a line that contains a dash at the start
/// 
/// Includes
/// - \- value:
/// - \- value
fn tokenize_sequence_item(stripped: String, indent: Int) {
  let tokenized_sequence_item = case string.contains(stripped, ":\n") {
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
      get_tokenized_value_or_block_scalar_indicator(stripped),
      Newline,
    ]
    False -> tokenized_sequence_item
  }
}

/// Tokenize an entry in a yaml mapping
/// 
/// Includes
/// - key: value
/// - key:
fn tokenize_key_value_pair(stripped: String, indent: Int) {
  case string.contains(stripped, ": ") {
    True -> [
      Indent(indent),
      Key(
        string.split(stripped, ": ")
        |> list.first
        |> result.unwrap(""),
      ),
      Colon,
      get_tokenized_value_or_block_scalar_indicator(stripped),
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
}

pub fn parse_tokens(tokens: List(Token)) -> Result(Yaml, String) {
  let result = case tokens {
    [Indent(_), Dash, ..] -> parse_array(tokens, 0)
    _ -> parse_block(tokens, 0)
  }

  case result {
    Ok(#(yaml, _)) -> Ok(yaml)
    Error(error) -> Error(error)
  }
}

fn parse_block(
  tokens: List(Token),
  indent: Int,
) -> Result(#(Yaml, List(Token)), String) {
  let items = []
  parse_block_items(tokens, indent, items)
}

fn parse_block_items(
  tokens: List(Token),
  indent: Int,
  items: List(#(String, Yaml)),
) -> Result(#(Yaml, List(Token)), String) {
  case tokens {
    [] -> Ok(#(block(items), tokens))

    [Indent(current_indent), ..] if current_indent < indent ->
      Ok(#(block(items), tokens))

    [Indent(current_indent), Key(key), Colon, Value(value), Newline, ..rest] if current_indent
      == indent ->
      parse_block_items(
        rest,
        indent,
        list.append(items, [#(key, parse_value(value))]),
      )

    [Indent(current_indent), Key(key), Colon, Newline, ..rest] if current_indent
      == indent -> {
      case parse_block(rest, indent + 1) {
        Ok(#(nested_block, remaining_tokens)) ->
          parse_block_items(
            remaining_tokens,
            indent,
            list.append(items, [#(key, nested_block)]),
          )
        Error(error) -> Error(error)
      }
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

    _ -> Ok(#(block(items), tokens))
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
    // Check if parsing of the block scalar should continue
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

    // Stop parsing the block scalar
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

fn parse_array(
  tokens: List(Token),
  indent: Int,
) -> Result(#(Yaml, List(Token)), String) {
  parse_array_items(tokens, indent, [])
}

fn parse_array_items(
  tokens: List(Token),
  indent: Int,
  items: List(Yaml),
) -> Result(#(Yaml, List(Token)), String) {
  case tokens {
    [] -> Ok(#(array(items), tokens))

    [
      Indent(current_indent),
      Dash,
      Key(key),
      Colon,
      Value(value),
      Newline,
      ..rest
    ] -> {
      case
        parse_block_items(rest, current_indent + 1, [#(key, parse_value(value))])
      {
        Ok(#(block, new_tokens)) ->
          parse_array_items(
            new_tokens,
            current_indent,
            list.append(items, [block]),
          )
        Error(error) -> Error(error)
      }
    }

    [Indent(_), Dash, Dash, ..] -> Error("Nested sequences are not implemented")

    [Indent(current_indent), Dash, Value(value), Newline, ..rest] if current_indent
      == indent ->
      parse_array_items(
        rest,
        current_indent,
        list.append(items, [parse_value(value)]),
      )

    _ -> Ok(#(array(items), tokens))
  }
}

/// Entry point to parse value, same as running parse_float
fn parse_value(value: String) -> Yaml {
  parse_float(value)
}

fn parse_float(value: String) {
  case float.parse(value) {
    Ok(float) -> encode.float(float)
    _ -> parse_int(value)
  }
}

fn parse_int(value: String) {
  case int.parse(value) {
    Ok(int) -> encode.int(int)
    _ -> parse_octal(value)
  }
}

fn parse_octal(value: String) {
  case
    octal_to_decimal(string.drop_left(value, 2)),
    string.starts_with(value, "0o")
  {
    Ok(decimal), True -> encode.int(decimal)
    _, _ -> parse_hexadecimal(value)
  }
}

fn parse_hexadecimal(value: String) {
  case
    hex_to_decimal(string.drop_left(value, 2)),
    string.starts_with(value, "0x")
  {
    Ok(decimal), True -> encode.int(decimal)
    _, _ -> parse_boolean(value)
  }
}

fn parse_boolean(value: String) {
  case
    value == "false"
    || value == "False"
    || value == "FALSE"
    || value == "true"
    || value == "True"
    || value == "TRUE"
  {
    True -> encode.bool(value == "true")
    _ -> parse_null(value)
  }
}

fn parse_null(value: String) {
  case value == "null" || value == "Null" || value == "NULL" || value == "~" {
    True -> encode.null()
    _ -> parse_string(value)
  }
}

fn parse_string(value: String) {
  encode.string(string.replace(string.replace(value, "\"", ""), "'", ""))
}

fn octal_char_to_decimal(octal_char: String) -> Result(Int, String) {
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
    case acc, octal_char_to_decimal(char) {
      Ok(acc_value), Ok(digit) ->
        Ok(
          acc_value
          + digit
          * float.round(result.unwrap(
            int.power(8, int.to_float(length - 1 - index)),
            1.0,
          )),
        )

      Error(e), _ -> Error(e)
      _, Error(e) -> Error(e)
    }
  })
}

fn hex_to_decimal(hex: String) -> Result(Int, String) {
  let hex_chars = string.split(hex, "")
  let length = list.length(hex_chars)
  let decimal_value =
    list.index_fold(hex_chars, Ok(0), fn(acc, char, index) {
      case acc {
        Ok(value) ->
          case hex_char_to_value(char) {
            Ok(char_value) ->
              Ok(
                value
                + char_value
                * float.round(result.unwrap(
                  int.power(16, int.to_float(length - 1 - index)),
                  1.0,
                )),
              )
            Error(e) -> Error(e)
          }
        Error(e) -> Error(e)
      }
    })
  decimal_value
}

fn hex_char_to_value(hex_char: String) -> Result(Int, String) {
  case hex_char {
    "0" -> Ok(0)
    "1" -> Ok(1)
    "2" -> Ok(2)
    "3" -> Ok(3)
    "4" -> Ok(4)
    "5" -> Ok(5)
    "6" -> Ok(6)
    "7" -> Ok(7)
    "8" -> Ok(8)
    "9" -> Ok(9)
    "a" -> Ok(10)
    "A" -> Ok(10)
    "b" -> Ok(11)
    "B" -> Ok(11)
    "c" -> Ok(12)
    "C" -> Ok(12)
    "d" -> Ok(13)
    "D" -> Ok(13)
    "e" -> Ok(14)
    "E" -> Ok(14)
    "f" -> Ok(15)
    "F" -> Ok(15)
    _ -> Error("Invalid hexadecimal character: " <> hex_char)
  }
}

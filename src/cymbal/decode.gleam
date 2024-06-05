import cymbal/encode.{type Yaml, array, block, string}
import gleam/list.{append}
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
  value
  |> list.flat_map(tokenize_line)
}

fn tokenize_line(line: String) {
  let stripped = string.trim(line)
  let indent = count_leading_spaces(line)

  case string.first(stripped) {
    Ok(value) if value == "-" -> {
      case stripped {
        "---" -> []
        _ -> [
          Indent(indent),
          Dash,
          Value(string.drop_left(stripped, 2)),
          Newline,
        ]
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

pub fn parse_tokens(tokens: List(Token)) -> Result(Yaml, String) {
  let #(result, _) = parse_block(tokens, 0)
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
      parse_block_items(rest, indent, append(items, [#(key, string(value))]))

    [Indent(current_indent), Key(key), Colon, Newline, ..rest] if current_indent
      == indent -> {
      let #(nested_block, remaining_tokens) = parse_block(rest, indent + 2)
      parse_block_items(
        remaining_tokens,
        indent,
        append(items, [#(key, nested_block)]),
      )
    }

    // TODO: Make the following two cases into one as only the Fold/Keep changes
    [Indent(current_indent), Key(key), Colon, RightArrow, Newline, ..rest] if current_indent
      == indent -> {
      let #(multiline_string, new_tokens) =
        parse_block_scalar(rest, "", current_indent + 2, Fold)

      parse_block_items(
        new_tokens,
        indent,
        append(items, [#(key, string(multiline_string))]),
      )
    }

    [Indent(current_indent), Key(key), Colon, Pipe, Newline, ..rest] if current_indent
      == indent -> {
      let #(multiline_string, new_tokens) =
        parse_block_scalar(rest, "", current_indent + 2, Keep)

      parse_block_items(
        new_tokens,
        indent,
        append(items, [#(key, string(multiline_string))]),
      )
    }

    [Indent(current_indent), Dash, Value(_), Newline, ..] if current_indent
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
            string.append(
              string.append(value, case value {
                "" -> ""
                _ -> " "
              }),
              line_as_string,
            ),
            indent,
            block_type,
          )
        }
        Keep -> {
          let #(line_as_string, new_tokens) =
            tokens_to_string_until_newline(tokens, "", indent)
          parse_block_scalar(
            new_tokens,
            string.append(
              string.append(value, case value {
                "" -> ""
                _ -> "\n"
              }),
              line_as_string,
            ),
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
        string.append(current_value, create_spaces(current_indent - indent, "")),
        indent,
      )
    [Dash, ..rest] ->
      tokens_to_string_until_newline(
        rest,
        string.append(current_value, "-"),
        indent,
      )
    [Colon, Value(value), ..rest] ->
      tokens_to_string_until_newline(
        rest,
        string.append(string.append(current_value, ": "), value),
        indent,
      )
    [Colon, ..rest] ->
      tokens_to_string_until_newline(
        rest,
        string.append(current_value, ":"),
        indent,
      )
    [Key(key), ..rest] ->
      tokens_to_string_until_newline(
        rest,
        string.append(current_value, key),
        indent,
      )
    [Value(value), ..rest] ->
      tokens_to_string_until_newline(
        rest,
        string.append(current_value, value),
        indent,
      )
    [Pipe, ..rest] ->
      tokens_to_string_until_newline(
        rest,
        string.append(current_value, "|"),
        indent,
      )
    [RightArrow, ..rest] ->
      tokens_to_string_until_newline(
        rest,
        string.append(current_value, ">"),
        indent,
      )
    [Newline, ..rest] -> #(current_value, rest)
    [] -> #(current_value, tokens)
  }
}

fn create_spaces(count: Int, acc: String) -> String {
  case count {
    0 -> acc
    _ -> create_spaces(count - 1, string.append(acc, " "))
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

    [Indent(_), Dash, Key(_), Colon, Value(_), Newline, ..] -> {
      panic as "Maps in sequences is not implemented"
    }

    [Indent(_), Dash, Dash, ..] -> {
      panic as "Nested sequences are not implemented"
    }

    [Indent(current_indent), Dash, Value(value), Newline, ..rest] if current_indent
      == indent ->
      parse_array_items(rest, current_indent, append(items, [string(value)]))

    _ -> #(array(items), tokens)
  }
}

import cymbal/decode/types.{type Token, Colon, Dash, Indent, Key, Newline, Value}
import cymbal/yaml.{type Yaml, array, block, string}
import gleam/list.{append}

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

    [Indent(current_indent), Dash, Value(_), Newline, ..] if current_indent
      == indent -> parse_array(tokens, indent)
    _ -> #(block(items), tokens)
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

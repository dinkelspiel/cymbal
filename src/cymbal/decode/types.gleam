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

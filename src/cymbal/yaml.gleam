/// A YAML document which can be converted into a string using the `encode`
/// function.
///
pub type Yaml {
  Int(Int)
  Bool(Bool)
  Float(Float)
  String(String)
  Array(List(Yaml))
  Block(List(#(String, Yaml)))
}

/// Create a YAML document from a bool.
///
pub fn bool(i: Bool) -> Yaml {
  Bool(i)
}

/// Create a YAML document from an int.
///
pub fn int(i: Int) -> Yaml {
  Int(i)
}

/// Create a YAML document from a float.
///
pub fn float(i: Float) -> Yaml {
  Float(i)
}

/// Create a YAML document from a string.
///
pub fn string(i: String) -> Yaml {
  String(i)
}

/// Create a YAML document from a list of YAML documents.
///
pub fn array(i: List(Yaml)) -> Yaml {
  Array(i)
}

/// Create a YAML document from a list of named YAML values.
///
pub fn block(i: List(#(String, Yaml))) -> Yaml {
  Block(i)
}

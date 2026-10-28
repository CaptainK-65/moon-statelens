///|
priv struct SuiteTrie {
  children : Map[String, Int32]
  terminal : Int32?
  mut owner : Int32
}

///|
/// Every original case maps to a physical word whose output prefix asserts it.
/// This changes reset scheduling under deterministic Mealy assumptions only.
pub struct RegressionPlan {
  priv suite : RegressionSuite
  priv words : Array[Array[String]]
  priv mapping : Array[Int32]
}

///|
pub fn RegressionSuite::plan(
  self : RegressionSuite,
  compact~ : Bool = true,
) -> RegressionPlan {
  if !compact {
    return {
      suite: self,
      words: self.cases.map(c => c.inputs.copy()),
      mapping: Array::makei(self.cases.length(), i => i),
    }
  }
  // Trie traversal is linear in the total input symbols, apart from map lookup.
  let nodes : Array[SuiteTrie] = [
    { children: Map([]), terminal: None, owner: -1, },
  ]
  for i, c in self.cases {
    let mut node = 0
    for input in c.inputs {
      node = match nodes[node].children.get(input) {
        Some(child) => child
        None => {
          let child = nodes.length()
          nodes[node].children[input] = child
          nodes.push({ children: Map([]), terminal: None, owner: -1, })
          child
        }
      }
    }
    nodes[node] = {
      children: nodes[node].children,
      terminal: Some(i),
      owner: -1,
    }
  }
  let words = []
  let mapping = Array::make(self.cases.length(), -1)
  for i = nodes.length() - 1; i >= 0; i = i - 1 {
    let node = nodes[i]
    if node.children.is_empty() && node.terminal is Some(c) {
      node.owner = words.length()
      words.push(self.cases[c].inputs.copy())
    } else {
      for (_, child) in node.children {
        node.owner = nodes[child].owner
        break
      }
    }
    if node.terminal is Some(c) {
      mapping[c] = node.owner
    }
  }
  { suite: self, words, mapping, }
}

///|
pub fn RegressionPlan::words(self : RegressionPlan) -> Array[Array[String]] {
  self.words.map(w => w.copy())
}

///|
pub fn RegressionPlan::alphabet(self : RegressionPlan) -> Array[String] {
  self.suite.model.alphabet()
}

///|
/// Independently verify each prefix and every expected output position.
pub fn RegressionPlan::validate(self : RegressionPlan) -> Bool raise {
  if self.mapping.length() != self.suite.cases.length() {
    return false
  }
  for i, c in self.suite.cases {
    guard self.words.get(self.mapping[i]) is Some(word) else { return false }
    if word.length() < c.inputs.length() ||
      word[:c.inputs.length()].to_owned() != c.inputs {
      return false
    }
    let output = self.suite.model.trace(word)
    if output[:c.expected.length()].to_owned() != c.expected {
      return false
    }
  }
  true
}

///|
pub fn RegressionPlan::certificate(self : RegressionPlan) -> Json {
  Json::object({
    "format": Json("moonstatelens.prefix-certificate"),
    "version": Json(1),
    "original_cases": Json(self.suite.cases.length()),
    "physical_words": Json(self.words),
    "case_to_word": Json(self.mapping),
    "scope": Json(
      "each original assertion is a prefix of its mapped physical trace; separate fresh stability probes are not compacted",
    ),
  })
}

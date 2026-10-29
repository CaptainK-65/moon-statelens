///|
priv enum TreeNode {
  Leaf(Int32)
  Split(Array[String], Map[Array[String], Int32])
}

///|
priv struct ActiveTree {
  alphabet : Array[String]
  metrics : ActiveMetrics
  accesses : Array[Array[String]]
  leaves : Array[Int32]
  nodes : Array[TreeNode]
  max_states : Int32
  max_prefixes : Int32
  binary_cex : Bool
}

///|
fn ActiveTree::new(
  alphabet : Array[String],
  metrics : ActiveMetrics,
  max_states : Int32,
  max_prefixes : Int32,
  binary_cex : Bool,
) -> ActiveTree {
  metrics.accesses = 1
  metrics.nodes = 1
  {
    alphabet: alphabet.copy(),
    metrics,
    accesses: [[]],
    leaves: [0],
    nodes: [Leaf(0)],
    max_states,
    max_prefixes,
    binary_cex,
  }
}

///|
fn ActiveTree::add_leaf(self : ActiveTree, word : Array[String]) -> Int32 raise {
  if self.accesses.length() >= self.max_states {
    raise LimitExceeded("hypothesis-states")
  }
  if self.accesses.length() >= self.max_prefixes {
    raise LimitExceeded("access-prefixes")
  }
  let state = self.accesses.length()
  self.accesses.push(word.copy())
  self.leaves.push(self.nodes.length())
  self.nodes.push(Leaf(state))
  self.metrics.accesses = self.accesses.length()
  self.metrics.nodes = self.nodes.length()
  state
}

///|
fn ActiveTree::sift(
  self : ActiveTree,
  word : Array[String],
  node : Int32,
  continuation : (Int32) -> Instruction raise,
) -> Instruction raise {
  match self.nodes[node] {
    Leaf(state) => continuation(state)
    Split(suffix, branches) =>
      Ask(word + suffix, outputs => {
        let signature = outputs[word.length():].to_owned()
        match branches.get(signature) {
          Some(child) => self.sift(word, child, continuation)
          None => {
            let state = self.add_leaf(word)
            branches[signature] = self.leaves[state]
            continuation(state)
          }
        }
      })
  }
}

///|
fn ActiveTree::build(self : ActiveTree) -> Instruction raise {
  self.edge(0, 0, [], [])
}

///|
fn ActiveTree::edge(
  self : ActiveTree,
  source : Int32,
  column : Int32,
  row : Array[Transition],
  table : Array[Array[Transition]],
) -> Instruction raise {
  if source == self.accesses.length() {
    let model = Machine::new(self.alphabet, table)
    return Candidate(model, (word, actual) => self.refine(model, word, actual))
  }
  if column == self.alphabet.length() {
    table.push(row)
    return self.edge(source + 1, 0, [], table)
  }
  let word = self.accesses[source] + [self.alphabet[column]]
  Ask(word, outputs => {
    let output = outputs[outputs.length() - 1]
    self.sift(word, 0, target => {
      row.push({ target, output, })
      self.edge(source, column + 1, row, table)
    })
  })
}

///|
fn ActiveTree::refine(
  self : ActiveTree,
  model : Machine,
  word : Array[String],
  actual : Array[String],
) -> Instruction raise {
  if word.length() < 2 {
    raise InvalidArgument("unstable one-step KV counterexample")
  }
  let path = [model.initial]
  for a in word {
    let state = path[path.length() - 1]
    path.push(model.transitions[state][model.input_index(a)].target)
  }
  if self.binary_cex {
    self.binary_split(
      word,
      path,
      0,
      word.length() - 1,
      actual[actual.length() - 1],
    )
  } else {
    self.find_split(word, path, 1, actual[actual.length() - 1])
  }
}

///|
/// Unequal endpoint observations, not a monotonicity assumption. Each query
/// retains an interval with unequal endpoints until an adjacent split remains.
fn ActiveTree::binary_split(
  self : ActiveTree,
  word : Array[String],
  path : Array[Int32],
  low : Int32,
  high : Int32,
  lower_output : String,
) -> Instruction raise {
  if high == low + 1 {
    return self.find_split(word, path, high, lower_output)
  }
  let middle = low + (high - low) / 2
  Ask(self.accesses[path[middle]] + word[middle:].to_owned(), outputs => {
    let observed = outputs[outputs.length() - 1]
    if observed == lower_output {
      self.binary_split(word, path, middle, high, observed)
    } else {
      self.binary_split(word, path, low, middle, lower_output)
    }
  })
}

///|
/// The final output after access(q_i) + word[i:] differs at the two endpoints.
/// Find an adjacent differing pair; its nonempty suffix splits a real leaf.
fn ActiveTree::find_split(
  self : ActiveTree,
  word : Array[String],
  path : Array[Int32],
  index : Int32,
  previous : String,
) -> Instruction raise {
  if index >= word.length() {
    raise InvalidArgument("KV counterexample did not split a state")
  }
  let suffix = word[index:].to_owned()
  let old_state = path[index]
  let old_access = self.accesses[old_state]
  Ask(old_access + suffix, old_outputs => {
    let last = old_outputs[old_outputs.length() - 1]
    if previous == last {
      self.find_split(word, path, index + 1, last)
    } else {
      let new_access = self.accesses[path[index - 1]] + [word[index - 1]]
      let old_signature = old_outputs[old_access.length():].to_owned()
      Ask(new_access + suffix, new_outputs => {
        let signature = new_outputs[new_access.length():].to_owned()
        if signature == old_signature {
          raise InvalidArgument("invalid KV split witness")
        }
        let old_leaf = self.leaves[old_state]
        let copy_leaf = self.nodes.length()
        self.nodes.push(Leaf(old_state))
        self.leaves[old_state] = copy_leaf
        let new_state = self.add_leaf(new_access)
        self.nodes[old_leaf] = Split(
          suffix,
          Map([(old_signature, copy_leaf), (signature, self.leaves[new_state])]),
        )
        self.metrics.discriminators += 1
        self.metrics.nodes = self.nodes.length()
        self.build()
      })
    }
  })
}

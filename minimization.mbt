///|
/// Remove unreachable states and merge observationally equivalent states.
/// The result uses BFS numbering starting at state zero.
pub fn Machine::minimize(self : Machine) -> Machine raise LensError {
  let mut classes = Array::make(self.state_count(), 0)
  for ;; {
    let groups : Map[(Array[String], Array[Int]), Int] = Map([])
    let next = self.transitions.map(row => {
      let signature = (
        row.map(edge => edge.output),
        row.map(edge => classes[edge.target]),
      )
      match groups.get(signature) {
        Some(group) => group
        None => {
          let group = groups.length()
          groups[signature] = group
          group
        }
      }
    })
    if next == classes {
      break
    }
    classes = next
  }
  let reachable = self.access_sequences()
  let ids : Map[Int, Int] = Map([])
  let representatives = []
  for (state, _) in reachable {
    let group = classes[state]
    if !ids.contains(group) {
      ids[group] = representatives.length()
      representatives.push(state)
    }
  }
  let transitions = representatives.map(state => {
    self.transitions[state].map(edge => {
      target: ids[classes[edge.target]],
      output: edge.output,
    })
  })
  Machine::new(self.alphabet, transitions)
}

///|
/// Pairwise distinguishing suffixes for a reachable minimal model. Equivalent
/// states are merged first. Includes epsilon so single-state models test outputs.
pub fn Machine::characterizing_set(
  self : Machine,
) -> Array[Array[String]] raise LensError {
  let model = self.minimize()
  let words : Array[Array[String]] = [[]]
  for left in 0..<model.state_count() {
    for right in (left + 1)..<model.state_count() {
      guard model.distinguish_states(left, right) is Some(word) else {
        raise InvalidArgument("internal error: equivalent minimal states")
      }
      if !words.contains(word) {
        words.push(word)
      }
    }
  }
  words
}

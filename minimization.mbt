///|
/// Remove unreachable states and merge observationally equivalent states.
/// The result uses BFS numbering starting at state zero.
pub fn Machine::minimize(
  self : Machine,
  max_work~ : Int32 = 8000000,
) -> Machine raise LensError {
  if max_work < 1 {
    raise InvalidArgument("minimization work must be positive")
  }
  let mut work = 0
  let round_cost = self.state_count() * self.alphabet.length()
  let mut classes = Array::make(self.state_count(), 0)
  for ;; {
    if round_cost > max_work - work {
      raise LimitExceeded("minimization-work")
    }
    work += round_cost
    let groups : Map[(Array[String], Array[Int32]), Int32] = Map([])
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
  let ids : Map[Int32, Int32] = Map([])
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
/// Pairwise shortest distinguishing suffixes for a reachable minimal model.
/// Includes epsilon so single-state models test outputs. Preparation and witness
/// reconstruction share a work budget; exhaustion never returns a partial set.
pub fn Machine::characterizing_set(
  self : Machine,
  max_work~ : Int32 = 1000000,
) -> Array[Array[String]] raise LensError {
  characterizing_minimal(self.minimize(), max_work~)
}

///|
fn pair_index(left : Int32, right : Int32, count : Int32) -> Int32 {
  let lo = if left < right { left } else { right }
  let hi = if left < right { right } else { left }
  lo * (2 * count - lo - 1) / 2 + hi - lo - 1
}

///|
fn characterizing_minimal(
  model : Machine,
  max_work~ : Int32,
) -> Array[Array[String]] raise LensError {
  if max_work < 1 {
    raise InvalidArgument("characterization work must be positive")
  }
  let count = model.state_count()
  let pairs = count * (count - 1) / 2
  if pairs > max_work / model.alphabet.length() {
    raise LimitExceeded("characterization-work")
  }
  let reverse : Array[Array[(Int32, Int32)]] = Array::makei(pairs, _ => [])
  let action = Array::make(pairs, -1)
  let successor = Array::make(pairs, -1)
  let queue = []
  for left in 0..<count {
    for right in (left + 1)..<count {
      let pair = pair_index(left, right, count)
      for column in 0..<model.alphabet.length() {
        let le = model.transitions[left][column]
        let re = model.transitions[right][column]
        if le.output != re.output {
          if action[pair] < 0 {
            action[pair] = column
            queue.push(pair)
          }
        } else if le.target != re.target {
          reverse[pair_index(le.target, re.target, count)].push((pair, column))
        }
      }
    }
  }
  // Multi-source reverse BFS assigns every pair a shortest witness suffix.
  for head = 0; head < queue.length(); head = head + 1 {
    let pair = queue[head]
    for (previous, column) in reverse[pair] {
      if action[previous] < 0 {
        action[previous] = column
        successor[previous] = pair
        queue.push(previous)
      }
    }
  }
  let words : Array[Array[String]] = [[]]
  let seen : Map[Array[String], Unit] = Map([([], ())])
  let mut work = pairs * model.alphabet.length()
  for pair in 0..<pairs {
    if action[pair] < 0 {
      raise InvalidArgument("internal error: equivalent minimal states")
    }
    let word = []
    let mut cursor = pair
    for ;; {
      if work >= max_work {
        raise LimitExceeded("characterization-work")
      }
      work += 1
      word.push(model.alphabet[action[cursor]])
      cursor = successor[cursor]
      if cursor < 0 {
        break
      }
    }
    if !seen.contains(word) {
      seen[word] = ()
      words.push(word)
    }
  }
  words
}

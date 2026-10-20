///|
/// W/Wp word generation is lazy in the exponential middle-word dimension.
priv struct ConformanceWords {
  model : Machine
  use_identifiers : Bool
  bound : Int32
  global_suffixes : Array[Array[String]]
  identifiers : Array[Array[Array[String]]]
  cover : Array[(Int32, Array[String])]
  difference : Array[(Int32, Array[String])]
  mut middle : WordCursor
  mut word : Array[String]?
  mut prefix_index : Int32
  mut suffix_index : Int32
  mut phase : Int32
}

///|
fn ConformanceWords::new(
  model : Machine,
  bound : Int32,
  use_identifiers~ : Bool,
  max_work~ : Int32,
) -> ConformanceWords raise {
  let global_suffixes = characterizing_minimal(model, max_work~)
  let identifiers = if use_identifiers {
    local_identifiers(model, global_suffixes, max_work)
  } else {
    []
  }
  let access = model.access_sequences()
  let all = access.copy()
  let seen : Map[Array[String], Unit] = Map([])
  for (_, word) in access {
    seen[word] = ()
  }
  let difference = []
  for (state, word) in access {
    for column, edge in model.transitions[state] {
      let extended = word + [model.alphabet[column]]
      if !seen.contains(extended) {
        seen[extended] = ()
        all.push((edge.target, extended))
        difference.push((edge.target, extended))
      }
    }
  }
  {
    model,
    use_identifiers,
    bound,
    global_suffixes,
    identifiers,
    cover: if use_identifiers {
      access
    } else {
      all
    },
    difference,
    middle: WordCursor::new(model.alphabet, bound - model.state_count()),
    word: None,
    prefix_index: 0,
    suffix_index: 0,
    phase: 0,
  }
}

///|
/// Every selected local identifier separates its state from some remaining
/// competitor. Global W separates all pairs, so each completed local set does too.
/// Global preparation and local selection have separately bounded work.
fn local_identifiers(
  model : Machine,
  global : Array[Array[String]],
  max_work : Int32,
) -> Array[Array[Array[String]]] raise {
  let identifiers = []
  let mut work = 0
  for state in 0..<model.state_count() {
    let remaining : Map[Int32, Unit] = Map([])
    for other in 0..<model.state_count() {
      if other != state {
        remaining[other] = ()
      }
    }
    let selected = [[]]
    for word in global {
      if remaining.is_empty() {
        break
      }
      if word.length() > max_work - work {
        raise LimitExceeded("identifier-work")
      }
      work += word.length()
      let expected = model.trace_from(state, word)
      let removed = []
      for (other, _) in remaining {
        if word.length() > max_work - work {
          raise LimitExceeded("identifier-work")
        }
        work += word.length()
        if model.trace_from(other, word) != expected {
          removed.push(other)
        }
      }
      if !removed.is_empty() {
        selected.push(word)
        for other in removed {
          remaining.remove(other) |> ignore
        }
      }
    }
    if !remaining.is_empty() {
      raise InvalidArgument("incomplete local characterization")
    }
    identifiers.push(selected)
  }
  identifiers
}

///|
fn ConformanceWords::next(self : ConformanceWords) -> Array[String]? {
  for ;; {
    if self.phase > (if self.use_identifiers { 1 } else { 0 }) {
      return None
    }
    let prefixes = if self.phase == 0 { self.cover } else { self.difference }
    if prefixes.is_empty() {
      self.phase += 1
      continue
    }
    if self.word is None {
      self.word = self.middle.next()
      if self.word is None {
        self.phase += 1
        self.middle = WordCursor::new(
          self.model.alphabet,
          self.bound - self.model.state_count(),
        )
        self.prefix_index = 0
        self.suffix_index = 0
        continue
      }
    }
    let word = self.word.unwrap()
    if self.prefix_index == prefixes.length() {
      self.word = None
      self.prefix_index = 0
      self.suffix_index = 0
      continue
    }
    let (state, prefix) = prefixes[self.prefix_index]
    let mut reached = state
    for a in word {
      reached = self.model.transitions[reached][self.model.alphabet
        .search(a)
        .unwrap()].target
    }
    let suffixes = if self.phase == 0 {
      self.global_suffixes
    } else {
      self.identifiers[reached]
    }
    if self.suffix_index == suffixes.length() {
      self.prefix_index += 1
      self.suffix_index = 0
      continue
    }
    let suffix = suffixes[self.suffix_index]
    self.suffix_index += 1
    return Some(prefix + word + suffix)
  }
}

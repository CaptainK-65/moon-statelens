///|
priv struct ObservationTable {
  experiment : Experiment
  prefixes : Array[Array[String]]
  suffixes : Array[Array[String]]
  rows : Map[Array[String], Array[Array[String]]]
  max_cells : Int32
  max_symbols : Int32
  max_prefixes : Int32
  max_states : Int32
  mut cells : Int32
  mut symbols : Int32
}

///|
fn ObservationTable::new(
  experiment : Experiment,
  max_cells~ : Int32,
  max_symbols~ : Int32,
  max_prefixes~ : Int32,
  max_states~ : Int32,
) -> ObservationTable {
  {
    experiment,
    prefixes: [[]],
    suffixes: experiment.alphabet.map(input => [input]),
    rows: Map([]),
    max_cells,
    max_symbols,
    max_prefixes,
    max_states,
    cells: 0,
    symbols: 0,
  }
}

///|
fn ObservationTable::row(
  self : ObservationTable,
  prefix : Array[String],
) -> Array[Array[String]] raise {
  match self.rows.get(prefix) {
    Some(row) => row
    None => {
      if self.suffixes.length() > self.max_cells - self.cells {
        raise LimitExceeded("table-cells")
      }
      let mut required_symbols = 0
      for suffix in self.suffixes {
        if suffix.length() > self.max_symbols - self.symbols - required_symbols {
          raise LimitExceeded("table-symbols")
        }
        required_symbols += suffix.length()
      }
      let row = self.suffixes.map(suffix => {
        let outputs = self.experiment.query(prefix + suffix)
        outputs[prefix.length():].to_owned()
      })
      self.cells += self.suffixes.length()
      self.symbols += required_symbols
      self.rows[prefix.copy()] = row
      row
    }
  }
}

///|
fn ObservationTable::add_prefix(
  self : ObservationTable,
  prefix : Array[String],
) -> Unit raise LensError {
  if !self.prefixes.contains(prefix) {
    if self.prefixes.length() >= self.max_prefixes {
      raise LimitExceeded("access-prefixes")
    }
    self.prefixes.push(prefix.copy())
  }
}

///|
// Add one missing closure representative per pass. Counterexamples keep S
// prefix-closed, so every representative remains reachable in the hypothesis.
fn ObservationTable::close_once(self : ObservationTable) -> Bool raise {
  let known : Map[Array[Array[String]], Unit] = Map([])
  for prefix in self.prefixes {
    known[self.row(prefix)] = ()
  }
  if known.length() > self.max_states {
    raise LimitExceeded("hypothesis-states")
  }
  for prefix in self.prefixes {
    for input in self.experiment.alphabet {
      let extended = prefix + [input]
      if !known.contains(self.row(extended)) {
        if known.length() >= self.max_states {
          raise LimitExceeded("hypothesis-states")
        }
        self.add_prefix(extended)
        return false
      }
    }
  }
  true
}

///|
// Equal rows must have equal successor rows for every action. Mealy outputs
// are already observed because E contains every single-letter suffix.
fn ObservationTable::consistent_once(self : ObservationTable) -> Bool raise {
  for i in 0..<self.prefixes.length() {
    for j in (i + 1)..<self.prefixes.length() {
      let left = self.prefixes[i]
      let right = self.prefixes[j]
      if self.row(left) == self.row(right) {
        for input in self.experiment.alphabet {
          let lr = self.row(left + [input])
          let rr = self.row(right + [input])
          if lr != rr {
            for column in 0..<self.suffixes.length() {
              if lr[column] != rr[column] {
                self.suffixes.push([input] + self.suffixes[column])
                self.rows.clear()
                self.cells = 0
                self.symbols = 0
                return false
              }
            }
          }
        }
      }
    }
  }
  true
}

///|
fn ObservationTable::stabilize(self : ObservationTable) -> Unit raise {
  for ;; {
    if !self.close_once() {
      continue
    }
    if !self.consistent_once() {
      continue
    }
    break
  }
}

///|
fn ObservationTable::hypothesis(self : ObservationTable) -> Machine raise {
  let states : Map[Array[Array[String]], Int32] = Map([])
  let representatives : Array[Array[String]] = []
  for prefix in self.prefixes {
    let row = self.row(prefix)
    if !states.contains(row) {
      states[row] = representatives.length()
      representatives.push(prefix)
    }
  }
  if representatives.length() > self.max_states {
    raise LimitExceeded("hypothesis-states")
  }
  let transitions = representatives.map(prefix => {
    self.experiment.alphabet.map(input => {
      let extended = prefix + [input]
      let outputs = self.experiment.query(extended)
      let row = self.row(extended)
      guard states.get(row) is Some(target) else {
        raise InvalidArgument("internal error: table is not closed")
      }
      { target, output: outputs[outputs.length() - 1], }
    })
  })
  Machine::new(self.experiment.alphabet, transitions)
}

///|
fn ObservationTable::refine(
  self : ObservationTable,
  word : Array[String],
) -> Unit raise LensError {
  for end in 1..<=word.length() {
    self.add_prefix(word[:end].to_owned())
  }
}

///|
priv struct ActiveTable {
  alphabet : Array[String]
  metrics : ActiveMetrics
  prefixes : Array[Array[String]]
  suffixes : Array[Array[String]]
  rows : Map[Array[String], Array[Array[String]]]
  max_states : Int32
  max_cells : Int32
  max_symbols : Int32
  max_prefixes : Int32
}

///|
fn ActiveTable::new(
  alphabet : Array[String],
  metrics : ActiveMetrics,
  max_states : Int32,
  max_cells : Int32,
  max_symbols : Int32,
  max_prefixes : Int32,
) -> ActiveTable {
  {
    alphabet: alphabet.copy(),
    metrics,
    prefixes: [[]],
    suffixes: alphabet.map(a => [a]),
    rows: Map([]),
    max_states,
    max_cells,
    max_symbols,
    max_prefixes,
  }
}

///|
fn ActiveTable::add_prefix(
  self : ActiveTable,
  word : Array[String],
) -> Unit raise {
  if !self.prefixes.contains(word) {
    if self.prefixes.length() >= self.max_prefixes {
      raise LimitExceeded("access-prefixes")
    }
    self.prefixes.push(word.copy())
  }
}

///|
fn ActiveTable::fill(self : ActiveTable) -> Instruction raise {
  let relevant = []
  let seen : Map[Array[String], Unit] = Map([])
  for prefix in self.prefixes {
    if !seen.contains(prefix) {
      relevant.push(prefix)
      seen[prefix] = ()
    }
    for a in self.alphabet {
      let extended = prefix + [a]
      if !seen.contains(extended) {
        relevant.push(extended)
        seen[extended] = ()
      }
    }
    if relevant.length() > self.max_cells / self.suffixes.length() {
      raise LimitExceeded("table-cells")
    }
  }
  self.metrics.accesses = self.prefixes.length()
  self.metrics.discriminators = self.suffixes.length()
  self.fill_row(relevant, 0)
}

///|
fn ActiveTable::fill_row(
  self : ActiveTable,
  relevant : Array[Array[String]],
  from : Int32,
) -> Instruction raise {
  let mut index = from
  while index < relevant.length() && self.rows.contains(relevant[index]) {
    index += 1
  }
  if index == relevant.length() {
    return self.stabilize()
  }
  if self.suffixes.length() > self.max_cells - self.metrics.cells {
    raise LimitExceeded("table-cells")
  }
  let mut symbols = 0
  for suffix in self.suffixes {
    if suffix.length() > self.max_symbols - self.metrics.symbols - symbols {
      raise LimitExceeded("table-symbols")
    }
    symbols += suffix.length()
  }
  self.metrics.cells += self.suffixes.length()
  self.metrics.symbols += symbols
  self.fill_column(relevant, index, 0, [])
}

///|
fn ActiveTable::fill_column(
  self : ActiveTable,
  relevant : Array[Array[String]],
  row_index : Int32,
  column : Int32,
  row : Array[Array[String]],
) -> Instruction raise {
  let prefix = relevant[row_index]
  if column == self.suffixes.length() {
    self.rows[prefix] = row
    return self.fill_row(relevant, row_index + 1)
  }
  Ask(prefix + self.suffixes[column], outputs => {
    row.push(outputs[prefix.length():].to_owned())
    self.fill_column(relevant, row_index, column + 1, row)
  })
}

///|
fn ActiveTable::row(
  self : ActiveTable,
  word : Array[String],
) -> Array[Array[String]] {
  self.rows[word]
}

///|
fn ActiveTable::stabilize(self : ActiveTable) -> Instruction raise {
  let known : Map[Array[Array[String]], Int32] = Map([])
  let representatives = []
  for prefix in self.prefixes {
    let row = self.row(prefix)
    if !known.contains(row) {
      known[row] = representatives.length()
      representatives.push(prefix)
    }
  }
  if representatives.length() > self.max_states {
    raise LimitExceeded("hypothesis-states")
  }
  for prefix in self.prefixes {
    for a in self.alphabet {
      let extended = prefix + [a]
      if !known.contains(self.row(extended)) {
        if representatives.length() >= self.max_states {
          raise LimitExceeded("hypothesis-states")
        }
        self.add_prefix(extended)
        return self.fill()
      }
    }
  }
  for i in 0..<self.prefixes.length() {
    for j in (i + 1)..<self.prefixes.length() {
      let left = self.prefixes[i]
      let right = self.prefixes[j]
      if self.row(left) == self.row(right) {
        for a in self.alphabet {
          let lr = self.row(left + [a])
          let rr = self.row(right + [a])
          for column in 0..<self.suffixes.length() {
            if lr[column] != rr[column] {
              self.suffixes.push([a] + self.suffixes[column])
              self.rows.clear()
              self.metrics.cells = 0
              self.metrics.symbols = 0
              return self.fill()
            }
          }
        }
      }
    }
  }
  let transitions = representatives.map(prefix => {
    self.alphabet.mapi((column, a) => {
      target: known[self.row(prefix + [a])],
      output: self.row(prefix)[column][0],
    })
  })
  let model = Machine::new(self.alphabet, transitions)
  Candidate(model, (word, _) => {
    for end in 1..<=word.length() {
      self.add_prefix(word[:end].to_owned())
    }
    self.fill()
  })
}

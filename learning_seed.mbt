///|
/// Reuse experiment structure only. All rows are initially empty and every
/// observation is obtained from the new experiment. Prefix closure is explicit.
fn ActiveTable::initialize_from(
  self : ActiveTable,
  seed : Machine,
) -> Unit raise {
  if seed.alphabet != self.alphabet {
    raise InvalidArgument("historical model alphabet order mismatch")
  }
  let model = seed.minimize()
  let suffixes = model.characterizing_set(max_work=1000000)
  for (_, word) in model.access_sequences() {
    for end in 1..<=word.length() {
      self.add_prefix(word[:end].to_owned())
    }
  }
  for suffix in suffixes {
    if !suffix.is_empty() && !self.suffixes.contains(suffix) {
      self.suffixes.push(suffix.copy())
    }
  }
  if self.suffixes.length() > self.max_cells {
    raise LimitExceeded("seed-table-cells")
  }
}

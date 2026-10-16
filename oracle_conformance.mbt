///|
fn oracle_mismatch(
  model : Machine,
  experiment : Experiment,
  word : Array[String],
) -> Bool raise {
  let expected = model.trace(word)
  let actual = experiment.query(word, bypass_cache=true)
  expected != actual
}

///|
/// Fresh exhaustive experiments through max_depth. Completion is bounded
/// evidence only. max_tests or an experiment limit yields Inconclusive.
pub fn Oracle::exhaustive(
  max_depth : Int32,
  max_tests~ : Int32 = 10000,
) -> Oracle raise LensError {
  if max_depth < 0 || max_depth > 4096 || max_tests < 1 {
    raise InvalidArgument("invalid exhaustive oracle budget")
  }
  Oracle::new((hypothesis, experiment) => {
    let words = WordCursor::new(hypothesis.alphabet, max_depth)
    let mut count = 0
    for ;; {
      guard words.next() is Some(word) else { break }
      if count >= max_tests {
        return Inconclusive("conformance-tests")
      }
      count += 1
      if oracle_mismatch(hypothesis, experiment, word) {
        return Counterexample(word)
      }
    }
    NoCounterexample(
      Budgeted(
        "exhaustive through depth " +
        max_depth.to_string() +
        "; tests=" +
        count.to_string(),
      ),
    )
  })
}

///|
/// Reproducible random-word experiments. Successful completion is never an
/// unconditional equivalence result. The seed is reset for each hypothesis.
pub fn Oracle::random_words(
  seed~ : UInt32 = 1,
  max_length~ : Int32 = 16,
  tests~ : Int32 = 1000,
) -> Oracle raise LensError {
  if max_length < 0 || max_length > 4096 || tests < 1 {
    raise InvalidArgument("invalid random oracle budget")
  }
  Oracle::new((hypothesis, experiment) => {
    let mut state = seed
    for _ in 0..<tests {
      state = state * 1664525U + 1013904223U
      let length = ((state >> 16) % (max_length + 1).reinterpret_as_uint()).reinterpret_as_int()
      let word = []
      for _ in 0..<length {
        state = state * 1664525U + 1013904223U
        word.push(
          hypothesis.alphabet[((state >> 16) %
          hypothesis.alphabet.length().reinterpret_as_uint()).reinterpret_as_int()],
        )
      }
      if oracle_mismatch(hypothesis, experiment, word) {
        return Counterexample(word)
      }
    }
    NoCounterexample(
      Budgeted(
        "random words; seed=" +
        seed.to_string() +
        "; tests=" +
        tests.to_string() +
        "; max_length=" +
        max_length.to_string(),
      ),
    )
  })
}

///|
/// Complete W-method suite P . Sigma^{<=m-n} . W, where P is a transition
/// cover and W characterizes a minimized, reachable hypothesis. Completeness
/// is conditional on the actual SUL satisfying the declared state bound and
/// deterministic, total, resettable Mealy assumptions. Truncation is inconclusive.
pub fn Oracle::w_method(
  state_bound : Int32,
  max_tests~ : Int32 = 100000,
  max_characterization_work~ : Int32 = 1000000,
) -> Oracle raise LensError {
  if state_bound < 1 ||
    state_bound > 4096 ||
    max_tests < 1 ||
    max_characterization_work < 1 {
    raise InvalidArgument("invalid W-method budget")
  }
  Oracle::new((hypothesis, experiment) => {
    let model = hypothesis.minimize()
    if model.state_count() > state_bound {
      return Inconclusive("state-bound-below-hypothesis")
    }
    let suffixes = characterizing_minimal(
      model,
      max_work=max_characterization_work,
    )
    let access = model.access_sequences()
    let cover : Array[Array[String]] = []
    for (_, prefix) in access {
      if !cover.contains(prefix) {
        cover.push(prefix)
      }
      for input in model.alphabet {
        let word = prefix + [input]
        if !cover.contains(word) {
          cover.push(word)
        }
      }
    }
    let middle = WordCursor::new(
      model.alphabet,
      state_bound - model.state_count(),
    )
    let mut count = 0
    for ;; {
      guard middle.next() is Some(word) else { break }
      for prefix in cover {
        for suffix in suffixes {
          if count >= max_tests {
            return Inconclusive("conformance-tests")
          }
          count += 1
          let test_word = prefix + word + suffix
          if oracle_mismatch(model, experiment, test_word) {
            return Counterexample(test_word)
          }
        }
      }
    }
    NoCounterexample(ConditionalStateBound(state_bound))
  })
}

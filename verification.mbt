///|
/// Declarative, suspendable conformance strategies. State-bound methods require
/// deterministic, total, reliably resettable targets and a CORRECT state bound.
pub(all) enum VerificationPlan {
  Exact(Machine)
  Exhaustive(depth~ : Int32, max_tests~ : Int32)
  RandomWords(seed~ : UInt32, max_length~ : Int32, tests~ : Int32)
  WMethod(bound~ : Int32, max_tests~ : Int32, max_work~ : Int32)
  WpMethod(bound~ : Int32, max_tests~ : Int32, max_work~ : Int32)
  Replay(Array[Array[String]])
  Chain(Array[VerificationPlan])
} derive(Debug)

///|
pub extend VerificationPlan with @debug.Debug::{to_repr}

///|
pub(all) struct VerificationStage {
  strategy : String
  tests : Int32
  result : String
} derive(Debug, ToJson)

///|
pub extend VerificationStage with @debug.Debug::{to_repr}

///|
pub extend VerificationStage with ToJson::{to_json}

///|
priv struct StageState {
  strategy : String
  mut tests : Int32
  mut result : String
}

///|
priv enum VerifyInstruction {
  Test(Array[String], (Array[String]) -> VerifyInstruction raise)
  Checked(CheckResult)
}

///|
pub(all) enum VerificationEvent {
  Query(QueryRequest)
  Completed(CheckResult)
} derive(Debug)

///|
pub extend VerificationEvent with @debug.Debug::{to_repr}

///|
pub struct VerificationCursor {
  priv mut instruction : VerifyInstruction
  priv mut serial : Int32
  priv mut pending : Int32?
  priv stages : Array[StageState]
  priv mut failed : Bool
}

///|
pub fn VerificationCursor::new(
  plan : VerificationPlan,
  hypothesis : Machine,
) -> VerificationCursor raise {
  let stages = []
  {
    instruction: prepare_verification(
      copy_plan(plan, 0, [0]),
      hypothesis,
      stages,
      0,
    ),
    serial: 0,
    pending: None,
    stages,
    failed: false,
  }
}

///|
fn copy_plan(
  plan : VerificationPlan,
  depth : Int32,
  count : Array[Int32],
) -> VerificationPlan raise LensError {
  count[0] += 1
  if depth > 16 || count[0] > 64 {
    raise InvalidArgument("verification plan too complex")
  }
  match plan {
    Chain(plans) => Chain(plans.map(p => copy_plan(p, depth + 1, count)))
    Replay(words) => {
      if words.length() > 100000 {
        raise InvalidArgument("too many replay words")
      }
      Replay(
        words.map(word => {
          if word.length() > 4096 {
            raise InvalidArgument("replay word too long")
          }
          word.copy()
        }),
      )
    }
    other => other
  }
}

///|
pub fn VerificationCursor::stages(
  self : VerificationCursor,
) -> Array[VerificationStage] {
  self.stages.map(s => {
    strategy: s.strategy,
    tests: s.tests,
    result: s.result,
  })
}

///|
pub fn VerificationCursor::event(
  self : VerificationCursor,
) -> VerificationEvent raise LensError {
  if self.failed {
    raise InvalidArgument("failed verification cursor")
  }
  match self.instruction {
    Checked(result) => Completed(copy_check(result))
    Test(word, _) => {
      let id = match self.pending {
        Some(id) => id
        None => {
          if self.serial == 2147483647 {
            raise LimitExceeded("verification-identifiers")
          }
          self.serial += 1
          self.pending = Some(self.serial)
          self.serial
        }
      }
      Query({ id, inputs: word.copy(), })
    }
  }
}

///|
fn copy_check(result : CheckResult) -> CheckResult {
  match result {
    Counterexample(word) => Counterexample(word.copy())
    other => other
  }
}

///|
pub fn VerificationCursor::submit(
  self : VerificationCursor,
  id : Int32,
  outputs : Array[String],
) -> Unit raise {
  if self.failed || self.pending != Some(id) {
    raise InvalidArgument("stale verification request")
  }
  guard self.instruction is Test(word, consume) else {
    raise InvalidArgument("verification completed")
  }
  if word.length() != outputs.length() {
    raise InvalidArgument("incomplete verification trace")
  }
  self.pending = None
  errdefer {
    self.failed = true
  }
  self.instruction = consume(outputs.copy())
}

///|
fn log_stage(
  instruction : VerifyInstruction,
  stage : StageState,
) -> VerifyInstruction {
  match instruction {
    Checked(result) => {
      stage.result = match result {
        Counterexample(_) => "counterexample"
        NoCounterexample(_) => "completed"
        Inconclusive(_) => "inconclusive"
      }
      Checked(result)
    }
    Test(word, consume) =>
      Test(word, outputs => {
        stage.tests += 1
        log_stage(consume(outputs), stage)
      })
  }
}

///|
fn run_words(
  model : Machine,
  next : () -> Array[String]?,
  max_tests : Int32,
  evidence : Evidence,
  count : Int32,
) -> VerifyInstruction raise {
  match next() {
    None => Checked(NoCounterexample(evidence))
    Some(word) => {
      if count >= max_tests {
        return Checked(Inconclusive("conformance-tests"))
      }
      let expected = model.trace(word)
      Test(word.copy(), actual => {
        for i in 0..<actual.length() {
          if actual[i] != expected[i] {
            return Checked(Counterexample(word[:i + 1].to_owned()))
          }
        }
        run_words(model, next, max_tests, evidence, count + 1)
      })
    }
  }
}

///|
fn verification_chain(
  plans : Array[VerificationPlan],
  index : Int32,
  model : Machine,
  stages : Array[StageState],
  depth : Int32,
  previous : Evidence,
) -> VerifyInstruction raise {
  if index == plans.length() {
    return Checked(NoCounterexample(previous))
  }
  continue_verification(
    prepare_verification(plans[index], model, stages, depth),
    result => {
      match result {
        NoCounterexample(evidence) =>
          verification_chain(plans, index + 1, model, stages, depth, evidence)
        other => Checked(other)
      }
    },
  )
}

///|
fn continue_verification(
  instruction : VerifyInstruction,
  continuation : (CheckResult) -> VerifyInstruction raise,
) -> VerifyInstruction raise {
  match instruction {
    Checked(result) => continuation(result)
    Test(word, consume) =>
      Test(word, outputs => {
        continue_verification(consume(outputs), continuation)
      })
  }
}

///|
fn prepare_verification(
  plan : VerificationPlan,
  hypothesis : Machine,
  stages : Array[StageState],
  depth : Int32,
) -> VerifyInstruction raise {
  if depth > 16 || stages.length() >= 64 {
    raise InvalidArgument("verification plan too complex")
  }
  if plan is Chain(plans) {
    if plans.is_empty() || plans.length() > 64 {
      raise InvalidArgument("invalid verification chain")
    }
    return verification_chain(
      plans,
      0,
      hypothesis,
      stages,
      depth + 1,
      Budgeted("empty chain"),
    )
  }
  let name = match plan {
    Exact(_) => "exact-reference"
    Exhaustive(..) => "exhaustive"
    RandomWords(..) => "random-words"
    WMethod(..) => "w-method"
    WpMethod(..) => "wp-method"
    Replay(_) => "replay"
    Chain(_) => "chain"
  }
  let stage : StageState = { strategy: name, tests: 0, result: "in-progress", }
  stages.push(stage)
  let instruction = match plan {
    Exact(reference) =>
      match distinguish(hypothesis, reference) {
        Some(diff) => Checked(Counterexample(diff.inputs))
        None => Checked(NoCounterexample(ExactReference))
      }
    Exhaustive(depth~, max_tests~) => {
      if depth < 0 || depth > 4096 || max_tests < 1 {
        raise InvalidArgument("invalid exhaustive budget")
      }
      let words = WordCursor::new(hypothesis.alphabet, depth)
      run_words(
        hypothesis,
        () => words.next(),
        max_tests,
        Budgeted("exhaustive through depth " + depth.to_string()),
        0,
      )
    }
    RandomWords(seed~, max_length~, tests~) => {
      if max_length < 0 || max_length > 4096 || tests < 1 {
        raise InvalidArgument("invalid random budget")
      }
      let random = [seed]
      let remaining = [tests]
      run_words(
        hypothesis,
        () => {
          if remaining[0] == 0 {
            return None
          }
          remaining[0] -= 1
          random[0] = random[0] * 1664525U + 1013904223U
          let length = ((random[0] >> 16) %
          (max_length + 1).reinterpret_as_uint()).reinterpret_as_int()
          let word = []
          for _ in 0..<length {
            random[0] = random[0] * 1664525U + 1013904223U
            word.push(
              hypothesis.alphabet[((random[0] >> 16) %
              hypothesis.alphabet.length().reinterpret_as_uint()).reinterpret_as_int()],
            )
          }
          Some(word)
        },
        tests,
        Budgeted("seeded random words; seed=" + seed.to_string()),
        0,
      )
    }
    Replay(sequences) => {
      if sequences.length() > 100000 {
        raise InvalidArgument("too many replay words")
      }
      let words = sequences.map(word => word.copy())
      let index = [0]
      run_words(
        hypothesis,
        () => {
          if index[0] == words.length() {
            return None
          }
          let word = words[index[0]]
          index[0] += 1
          Some(word)
        },
        100000,
        Budgeted("provided replay words"),
        0,
      )
    }
    WMethod(bound~, max_tests~, max_work~)
    | WpMethod(bound~, max_tests~, max_work~) => {
      if bound < 1 || bound > 4096 || max_tests < 1 || max_work < 1 {
        raise InvalidArgument("invalid state-bound verification budget")
      }
      let model = hypothesis.minimize()
      if model.state_count() > bound {
        Checked(Inconclusive("state-bound-below-hypothesis"))
      } else {
        let words = ConformanceWords::new(
          model,
          bound,
          use_identifiers=plan is WpMethod(..),
          max_work~,
        )
        run_words(
          model,
          () => words.next(),
          max_tests,
          ConditionalStateBound(bound),
          0,
        )
      }
    }
    Chain(_) => abort("chain handled above")
  }
  log_stage(instruction, stage)
}

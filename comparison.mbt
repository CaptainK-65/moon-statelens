///|
/// A replayable difference between two complete models.
pub(all) struct Difference {
  inputs : Array[String]
  left_outputs : Array[String]
  right_outputs : Array[String]
} derive(Eq, Debug, ToJson)

///|
pub extend Difference with Eq::{equal, not_equal}

///|
pub extend Difference with @debug.Debug::{to_repr}

///|
pub extend Difference with ToJson::{to_json}

///|
fn compatible_alphabets(
  left : Machine,
  right : Machine,
) -> Unit raise LensError {
  if left.alphabet.length() != right.alphabet.length() ||
    !left.alphabet.all(input => right.alphabet.contains(input)) {
    raise InvalidArgument("machines must have the same input symbols")
  }
}

///|
/// BFS in the reachable product graph. None is exact observable equivalence
/// of the two supplied complete models, not a theorem about unknown programs.
pub fn distinguish(
  left : Machine,
  right : Machine,
  max_pairs~ : Int32 = 1000000,
) -> Difference? raise LensError {
  compatible_alphabets(left, right)
  distinguish_from(left, left.initial, right, right.initial, max_pairs~)
}

///|
fn distinguish_from(
  left : Machine,
  left_start : Int32,
  right : Machine,
  right_start : Int32,
  max_pairs~ : Int32,
) -> Difference? raise LensError {
  if max_pairs <= 0 {
    raise InvalidArgument("max_pairs must be positive")
  }
  // Parent pointers keep path storage linear in the number of visited pairs.
  let queue = [(left_start, right_start, -1, -1)]
  let seen : Map[(Int32, Int32), Unit] = Map([((left_start, right_start), ())])
  let right_columns = left.alphabet.map(input => right.input_index(input))
  for head = 0; head < queue.length(); head = head + 1 {
    let (ls, rs, _, _) = queue[head]
    for column, input in left.alphabet {
      let le = left.transitions[ls][column]
      let re = right.transitions[rs][right_columns[column]]
      if le.output != re.output {
        let reversed = [input]
        let mut cursor = head
        for ;; {
          let (_, _, parent, action) = queue[cursor]
          if parent < 0 {
            break
          }
          reversed.push(left.alphabet[action])
          cursor = parent
        }
        let inputs = reversed.rev()
        return Some({
          inputs,
          left_outputs: left.trace_from(left_start, inputs),
          right_outputs: right.trace_from(right_start, inputs),
        })
      }
      let pair = (le.target, re.target)
      if !seen.contains(pair) {
        if queue.length() >= max_pairs {
          raise LimitExceeded("product-pairs")
        }
        seen[pair] = ()
        queue.push((le.target, re.target, head, column))
      }
    }
  }
  None
}

///|
/// Distinguish two states of one model. Equivalent states return None.
pub fn Machine::distinguish_states(
  self : Machine,
  left : Int32,
  right : Int32,
) -> Array[String]? raise LensError {
  if left < 0 ||
    right < 0 ||
    left >= self.state_count() ||
    right >= self.state_count() {
    raise InvalidArgument("state out of range")
  }
  distinguish_from(self, left, self, right, max_pairs=1000000).map(diff => {
    diff.inputs
  })
}

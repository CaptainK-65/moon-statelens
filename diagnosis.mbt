///|
/// Bounded differing edges in the reachable product graph. Contexts need not be
/// independent defects. State numbers are never assumed to align.
pub(all) struct ModelDiagnosis {
  differences : Array[Difference]
  complete : Bool
  visited_pairs : Int32
  checked_edges : Int32
  reason : String?
} derive(Debug, ToJson)

///|
pub extend ModelDiagnosis with ToJson::{to_json}

///|
pub extend ModelDiagnosis with @debug.Debug::{to_repr}

///|
pub fn diagnose_models(
  left : Machine,
  right : Machine,
  max_pairs~ : Int32 = 100000,
  max_findings~ : Int32 = 64,
  max_edges~ : Int32 = 1000000,
) -> ModelDiagnosis raise LensError {
  compatible_alphabets(left, right)
  if max_pairs < 1 ||
    max_pairs > 1000000 ||
    max_findings < 1 ||
    max_findings > 10000 ||
    max_edges < 1 {
    raise InvalidArgument("invalid diagnosis budget")
  }
  let queue = [(left.initial, right.initial, -1, -1)]
  let seen : Map[(Int32, Int32), Unit] = Map([
    ((left.initial, right.initial), ()),
  ])
  let right_columns = left.alphabet.map(input => right.input_index(input))
  let differences = []
  let mut checked = 0
  let mut units = 0
  let mut reason : String? = None
  for head = 0; head < queue.length(); head = head + 1 {
    let (ls, rs, _, _) = queue[head]
    for column, input in left.alphabet {
      if checked == max_edges {
        reason = Some("diagnosis-edges")
        break
      }
      checked += 1
      let le = left.transitions[ls][column]
      let re = right.transitions[rs][right_columns[column]]
      if le.output != re.output {
        if differences.length() == max_findings {
          reason = Some("diagnosis-findings")
          break
        }
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
        if reversed.length() > 4096 || reversed.length() > 2000000 - units {
          reason = Some("diagnosis-word-symbols")
          break
        }
        units += reversed.length()
        let inputs = reversed.rev()
        differences.push({
          inputs,
          left_outputs: left.trace(inputs),
          right_outputs: right.trace(inputs),
        })
      }
      let pair = (le.target, re.target)
      if !seen.contains(pair) {
        if queue.length() == max_pairs {
          reason = Some("diagnosis-pairs")
          break
        }
        seen[pair] = ()
        queue.push((le.target, re.target, head, column))
      }
    }
    if reason is Some(_) {
      break
    }
  }
  {
    differences,
    complete: reason is None,
    visited_pairs: queue.length(),
    checked_edges: checked,
    reason,
  }
}

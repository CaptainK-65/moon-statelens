///|
/// A synchronous facade over the same suspendable verification used by async IO.
pub fn Oracle::plan(plan : VerificationPlan) -> Oracle raise LensError {
  let owned = copy_plan(plan, 0, [0])
  Oracle::new((model, experiment) => {
    let cursor = VerificationCursor::new(owned, model)
    for ;; {
      match cursor.event() {
        Query(request) =>
          cursor.submit(
            request.id,
            experiment.query(request.inputs, bypass_cache=true),
          )
        Completed(result) => return result
      }
    }
  })
}

///|
pub fn Oracle::wp_method(
  state_bound : Int32,
  max_tests~ : Int32 = 100000,
  max_characterization_work~ : Int32 = 1000000,
) -> Oracle raise LensError {
  if state_bound < 1 ||
    state_bound > 4096 ||
    max_tests < 1 ||
    max_characterization_work < 1 {
    raise InvalidArgument("invalid Wp-method budget")
  }
  Oracle::plan(
    WpMethod(bound=state_bound, max_tests~, max_work=max_characterization_work),
  )
}

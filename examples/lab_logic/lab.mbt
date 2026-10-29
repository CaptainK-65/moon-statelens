///|
fn bounded_model(value : Json) -> @lens.Machine raise {
  let model = @lens.decode_model(value.stringify(), max_code_units=1000000)
  if model.state_count() > 128 || model.alphabet().length() > 16 {
    fail("browser models support at most 128 states and 16 inputs")
  }
  model
}

///|
/// Browser request protocol. Computation uses the actual portable MoonBit core.
pub fn execute(request : Json) -> Json raise {
  match request {
    {
      "mode": "quota",
      "old_capacity": Number(old, ..),
      "new_capacity": Number(next, ..),
      "queries": Number(budget, ..),
      ..
    } => {
      let a = old.to_int()
      let b = next.to_int()
      let q = budget.to_int()
      if old != a.to_double() ||
        next != b.to_double() ||
        budget != q.to_double() ||
        a < 1 ||
        a > 6 ||
        b < 1 ||
        b > 6 ||
        q < 1 ||
        q > 100000 {
        fail("capacities must be integers 1..6; query budget 1..100000")
      }
      let alphabet = ["acquire", "release"]
      let baseline = @lens.learn(
        @lens.Experiment::new(@limit.quota_system(a), alphabet, max_queries=q),
        @lens.Oracle::wp_method(a + 1),
      )
      let cold = @lens.learn(
        @lens.Experiment::new(@limit.quota_system(b), alphabet, max_queries=q),
        @lens.Oracle::wp_method(b + 1),
      )
      guard baseline.status is Supported(_) && baseline.model is Some(seed) else {
        return Json::object({
          "format": Json("moonstatelens.lab"),
          "version": Json(1),
          "complete": Json(false),
          "baseline": Json(baseline),
          "cold": Json(cold),
        })
      }
      let guided = @lens.learn_with(
        @lens.Experiment::new(@limit.quota_system(b), alphabet, max_queries=q),
        @lens.Oracle::wp_method(b + 1),
        LStar,
        seed~,
      )
      let complete = cold.status is Supported(_) &&
        guided.status is Supported(_)
      let mut confirmation = Json::null()
      if complete {
        if @lens.distinguish(seed, guided.model.unwrap()) is Some(difference) {
          confirmation = @lens.confirm_difference(
              @lens.Experiment::new(@limit.quota_system(a), alphabet),
              @lens.Experiment::new(@limit.quota_system(b), alphabet),
              difference.inputs,
            )
            .map(d => Json(d))
            .unwrap_or(Json::null())
        }
      }
      Json::object({
        "format": Json("moonstatelens.lab"),
        "version": Json(1),
        "complete": Json(complete),
        "request": request,
        "baseline": Json(baseline),
        "cold": Json(cold),
        "guided": Json(guided),
        "confirmed_difference": confirmation,
        "junit": if complete {
          Json(
            @lens.regression_junit(
              seed
              .regression_suite()
              .plan()
              .run(@lens.Experiment::new(@limit.quota_system(b), alphabet)),
            ),
          )
        } else {
          Json::null()
        },
      })
    }
    { "mode": "models", "left": left, "right": right, .. } => {
      let l = bounded_model(left)
      let r = bounded_model(right)
      Json::object({
        "format": Json("moonstatelens.model-analysis"),
        "version": Json(1),
        "scope": Json(
          "exact supplied-model comparison; no actual component execution",
        ),
        "left": Json(l),
        "right": Json(r),
        "difference": @lens.distinguish(l, r, max_pairs=16384)
        .map(d => Json(d))
        .unwrap_or(Json::null()),
      })
    }
    _ => fail("unsupported laboratory request")
  }
}

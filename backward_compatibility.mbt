///|
/// Compare only histories formed from the old input alphabet. Additional new
/// operations are outside this contract. Exact for supplied complete models;
/// this does not certify actual implementations or histories using new inputs.
pub fn backward_compatibility(
  old : Machine,
  next : Machine,
  max_pairs~ : Int32 = 100000,
) -> Json raise {
  let missing = old.alphabet().filter(x => !next.alphabet().contains(x))
  let added = next.alphabet().filter(x => !old.alphabet().contains(x))
  if !missing.is_empty() {
    return Json::object({
      "format": Json("moonstatelens.backward-compatibility"),
      "version": Json(1),
      "status": Json("missing-old-operations"),
      "missing": Json(missing),
      "added": Json(added),
      "scope": Json("supplied models; old input histories only"),
    })
  }
  let columns = old.alphabet().map(x => next.input_index(x))
  let projection = Machine::new(
    old.alphabet(),
    next.table().map(row => columns.map(i => row[i])),
    initial=next.initial_state(),
  )
  let difference = distinguish(old, projection, max_pairs~)
  Json::object({
    "format": Json("moonstatelens.backward-compatibility"),
    "version": Json(1),
    "status": Json(
      if difference is None {
        "compatible-on-old-inputs"
      } else {
        "changed-old-behavior"
      },
    ),
    "added": Json(added),
    "missing": Json(missing),
    "difference": difference.map(d => Json(d)).unwrap_or(Json::null()),
    "scope": Json(
      "exact supplied models; histories using new operations and actual implementation behavior are not certified",
    ),
  })
}

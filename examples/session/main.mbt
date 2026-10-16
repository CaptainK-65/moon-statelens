///|
fn main raise {
  let experiment = @lens.Experiment::new(
    @targets.session_system(),
    @targets.session_alphabet(),
  )
  let result = @lens.learn(experiment, @lens.Oracle::w_method(2))
  println(Json(result.status).stringify())
  println("states=" + result.model.unwrap().state_count().to_string())
  println(Json(result.statistics).stringify(indent=2))
}

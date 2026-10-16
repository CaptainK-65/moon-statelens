///|
fn main raise {
  let experiment = @lens.Experiment::new(
    @adapter.system(),
    @adapter.alphabet(),
    max_queries=200000,
    max_steps=5000000,
  )
  let result = @lens.learn(experiment, @lens.Oracle::w_method(10))
  println(Json(result.status).stringify())
  println("states=" + result.model.unwrap().state_count().to_string())
  println(Json(result.statistics).stringify(indent=2))
}

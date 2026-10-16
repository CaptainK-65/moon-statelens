///|
fn main raise {
  let alphabet = @targets.session_alphabet()
  let report = @lens.compare(
    @lens.Experiment::new(@targets.session_system(), alphabet),
    @lens.Experiment::new(@targets.session_system(buggy=true), alphabet),
    @lens.Oracle::w_method(2),
    @lens.Oracle::w_method(2),
  )
  println(Json(report).stringify(indent=2))
}

///|
fn main raise {
  let left = @lens.Machine::new(["request"], [
    [{ target: 0, output: "Denied", }],
  ])
  let right = @lens.Machine::new(["request"], [
    [{ target: 0, output: "Allowed", }],
  ])
  println(Json(@lens.distinguish(left, right)).stringify(indent=2))
}

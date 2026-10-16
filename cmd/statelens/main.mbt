///|
fn main raise {
  let left = @lens.Machine::new(["request"], [
    [{ target: 0, output: "Denied", }],
  ])
  let right = @lens.Machine::new(["request"], [
    [{ target: 0, output: "Allowed", }],
  ])
  println(@lens.distinguish(left, right).to_json().stringify(indent=2))
}

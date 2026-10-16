///|
/// Reset/step adapter. Callbacks may raise; close is attempted on every physical query.
pub struct System {
  priv reset : () -> Unit raise
  priv step : (String) -> String raise
  priv close : () -> Unit raise
}

///|
pub fn System::new(
  reset~ : () -> Unit raise,
  step~ : (String) -> String raise,
  close? : () -> Unit raise = () => (),
) -> System {
  { reset, step, close, }
}

///|
/// Treat this explicit model as a black box. The learner receives only callbacks.
pub fn Machine::system(self : Machine) -> System {
  let current = [self.initial]
  System::new(reset=() => current[0] = self.initial, step=input => {
    let edge = self.transitions[current[0]][self.input_index(input)]
    current[0] = edge.target
    edge.output
  })
}

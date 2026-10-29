///|
/// Real public API only; capacity is fixed for each resettable experiment.
pub fn quota_system(capacity : Int32) -> @lens.System {
  let instance = [@limit.ConcurrencyLimiter::new(capacity)]
  @lens.System::new(
    reset=() => instance[0] = @limit.ConcurrencyLimiter::new(capacity),
    step=input => {
      match input {
        "acquire" =>
          if instance[0].acquire().is_allowed() {
            "allowed"
          } else {
            "rejected"
          }
        "release" => if instance[0].release() { "released" } else { "empty" }
        _ => raise @lens.UnknownInput(input)
      }
    },
  )
}

///|
/// Clock advances in whole refill periods; only admission is observed. No real
/// sleeping or private fields. Monotonic time must remain below Int overflow.
pub fn token_system() -> @lens.System {
  let clock = [0]
  let instance = [@limit.TokenBucket::new(2, 1, 1000)]
  @lens.System::new(
    reset=() => {
      clock[0] = 0
      instance[0] = @limit.TokenBucket::new(2, 1, 1000)
    },
    step=input => {
      match input {
        "request" =>
          if instance[0].allow_at(clock[0]).is_allowed() {
            "allowed"
          } else {
            "rejected"
          }
        "tick" => {
          if clock[0] > 2147482647 {
            raise @lens.LimitExceeded("virtual-clock")
          }
          clock[0] += 1000
          "advanced"
        }
        _ => raise @lens.UnknownInput(input)
      }
    },
  )
}

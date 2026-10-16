///|
/// Fixed finite alphabet for a real capacity-two LRU cache, with no TTL.
pub fn alphabet() -> Array[String] {
  ["put:a", "put:b", "put:c", "get:a", "get:b", "get:c", "clear"]
}

///|
/// Wrap moonlarder 0.15.0 exclusively through its public API. Values equal
/// their keys; time is fixed at zero and statistics are not observed.
/// The observable LRU abstraction has 1 + 3 + 6 = 10 states.
pub fn system() -> @lens.System {
  let instance : Array[@cache.Larder[String, String]] = [
    @cache.Larder::new(capacity=2, policy=Lru),
  ]
  @lens.System::new(
    reset=() => instance[0] = @cache.Larder::new(capacity=2, policy=Lru),
    step=input => {
      let cache = instance[0]
      match input {
        "put:a" => {
          cache.set("a", "a", now_ms=0L)
          "stored"
        }
        "put:b" => {
          cache.set("b", "b", now_ms=0L)
          "stored"
        }
        "put:c" => {
          cache.set("c", "c", now_ms=0L)
          "stored"
        }
        "get:a" =>
          cache.get("a", now_ms=0L).map(key => "hit:" + key).unwrap_or("miss")
        "get:b" =>
          cache.get("b", now_ms=0L).map(key => "hit:" + key).unwrap_or("miss")
        "get:c" =>
          cache.get("c", now_ms=0L).map(key => "hit:" + key).unwrap_or("miss")
        "clear" => {
          cache.clear()
          "cleared"
        }
        _ => raise @lens.UnknownInput(input)
      }
    },
  )
}

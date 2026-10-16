///|
pub fn session_alphabet() -> Array[String] {
  ["login", "logout", "request"]
}

///|
/// Controlled SDK fixture. The buggy variant deliberately retains credentials
/// after logout; it is not a claim of a vulnerability in a third-party SDK.
pub fn session_system(buggy~ : Bool = false) -> @lens.System {
  let logged_in = [false]
  @lens.System::new(reset=() => logged_in[0] = false, step=input => {
    match input {
      "login" => {
        logged_in[0] = true
        "ok"
      }
      "logout" => {
        if !buggy {
          logged_in[0] = false
        }
        "ok"
      }
      "request" => if logged_in[0] { "allowed" } else { "denied" }
      _ => raise @lens.UnknownInput(input)
    }
  })
}

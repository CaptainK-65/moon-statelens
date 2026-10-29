///|
extern "js" fn request() -> String =
  #| () => globalThis.moonStateLensRequest || '{}'

///|
fn main raise {
  println(@lab.execute(@json.parse(request())).stringify())
}

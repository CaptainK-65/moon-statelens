// Learn more about moon.mod configuration:
// https://docs.moonbitlang.com/en/latest/toolchain/moon/module.html
//
// To add a dependency, run this command in your terminal:
//   moon add moonbitlang/x
//
// Or manually declare it in `import`, for example:
// import {
//   "moonbitlang/x@0.4.6",
// }

name = "CaptainK-65/moon-statelens"

version = "0.2.0"

readme = "README.md"

repository = "https://github.com/CaptainK-65/moon-statelens"

license = "Apache-2.0"

keywords = [ "automata-learning", "mealy", "model-inference", "testing" ]

preferred_target = "wasm"

description = "Active black-box Mealy model learning and replay-confirmed behavioral compatibility checks."

import {
  "jhshuai/moonlarder@0.15.0",
  "moonbitlang/quickcheck@0.15.0",
  "moonbitlang/async@0.22.5",
  "moonbitlang/x@0.5.5",
}

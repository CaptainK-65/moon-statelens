///|
/// Scoped ownership: every physical query starts a fresh protocol process.
/// The callback must not let the AsyncSystem escape this task-group scope.
pub async fn[T] with_jsonl(
  program : String,
  args : Array[String],
  action : async (@runner.AsyncSystem) -> T,
  max_frame_bytes~ : Int32 = 1048576,
  max_stderr_bytes~ : Int32 = 65536,
) -> T {
  let arguments = args.copy()
  @async.with_task_group(group => {
    let active : Array[Channel?] = [None]
    let system = @runner.AsyncSystem::new(
      reset=() => {
        let channel = open_channel(
          group, program, arguments, max_frame_bytes, max_stderr_bytes,
        )
        active[0] = Some(channel)
        if channel.rpc("reset") != "ok" {
          raise @runner.Protocol("reset rejected")
        }
      },
      step=input => {
        guard active[0] is Some(channel) else {
          raise @runner.Protocol("process not started")
        }
        channel.rpc("step", input~)
      },
      close=() => {
        if active[0] is Some(channel) {
          active[0] = None
          if channel.faulted {
            channel.kill()
          } else {
            errdefer channel.kill()
            if channel.rpc("close") != "ok" {
              raise @runner.Protocol("close rejected")
            }
            channel.finish()
          }
        }
      },
    )
    errdefer (if active[0] is Some(channel) {
      @async.protect_from_cancel(() => channel.kill())
    })
    action(system)
  })
}

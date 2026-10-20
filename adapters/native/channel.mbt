///|
priv struct Channel {
  process : @process.Process
  reader : @process.ReadFromProcess
  writer : @process.WriteToProcess
  errors : @process.ReadFromProcess
  diagnostics : Array[Byte]
  max_frame_bytes : Int32
  mut buffered : Array[Byte]
  mut serial : Int32
  mut faulted : Bool
  mut closed : Bool
  mut stderr_overflow : Bool
  mut expected_sql_error : Bool
}

///|
async fn[G] open_channel(
  group : @async.TaskGroup[G],
  program : String,
  args : Array[String],
  max_frame_bytes : Int32,
  max_stderr_bytes : Int32,
  merge_errors~ : Bool = false,
) -> Channel {
  if program.is_empty() ||
    max_frame_bytes < 64 ||
    max_frame_bytes > 16777216 ||
    max_stderr_bytes < 0 ||
    max_stderr_bytes > 16777216 {
    raise @runner.Configuration("invalid process or output limit")
  }
  let (reader, output) = @process.read_from_process()
  errdefer reader.close()
  let (input, writer) = @process.write_to_process()
  errdefer writer.close()
  let (errors, error_output) = @process.read_from_process()
  errdefer errors.close()
  let child = @process.spawn(
    group,
    program,
    args,
    stdin=input,
    stdout=output,
    stderr=if merge_errors { output } else { error_output },
    no_console_window=true,
    cancel_handler=@process.hard_cancel(),
    no_wait=true,
  )
  if merge_errors {
    error_output.close()
  }
  let channel = {
    process: child,
    reader,
    writer,
    errors,
    diagnostics: [],
    max_frame_bytes,
    buffered: [],
    serial: 0,
    faulted: false,
    closed: false,
    stderr_overflow: false,
    expected_sql_error: false,
  }
  if !merge_errors {
    group.spawn_bg(no_wait=true, allow_failure=true, () => {
      while errors.read_some(max_len=4096) is Some(bytes) {
        if bytes.length() > max_stderr_bytes - channel.diagnostics.length() {
          channel.stderr_overflow = true
          channel.faulted = true
          child.cancel()
          break
        }
        for byte in bytes {
          channel.diagnostics.push(byte)
        }
      }
    })
  }
  channel
}

///|
async fn Channel::line(self : Channel) -> String {
  let mut scanned = 0
  for ;; {
    if self.stderr_overflow {
      raise @runner.Protocol("stderr limit exceeded")
    }
    while scanned < self.buffered.length() {
      if self.buffered[scanned] == b'\n' {
        if scanned > self.max_frame_bytes {
          raise @runner.Protocol("frame limit exceeded")
        }
        let bytes = Bytes::from_array(self.buffered[:scanned])
        self.buffered = self.buffered[scanned + 1:].to_owned()
        return @utf8.decode(bytes[:]).trim_end(chars="\r").to_owned()
      }
      scanned += 1
      if scanned > self.max_frame_bytes {
        raise @runner.Protocol("frame limit exceeded")
      }
    }
    guard self.reader.read_some(max_len=4096) is Some(bytes) else {
      if self.stderr_overflow {
        raise @runner.Protocol("stderr limit exceeded")
      }
      raise @runner.Protocol("unexpected process EOF")
    }
    for byte in bytes {
      self.buffered.push(byte)
    }
  }
}

///|
async fn Channel::rpc(
  self : Channel,
  operation : String,
  input~ : String = "",
) -> String {
  errdefer {
    self.faulted = true
  }
  if self.serial == 2147483647 {
    raise @runner.Protocol("request id exhausted")
  }
  self.serial += 1
  let id = self.serial
  let request = Json::object({
      "version": Json(1),
      "id": Json(id),
      "method": Json(operation),
      "input": Json(input),
    }).stringify() +
    "\n"
  if @utf8.encode(request[:]).length() > self.max_frame_bytes {
    raise @runner.Protocol("request frame limit exceeded")
  }
  self.writer.write(request)
  let line = self.line()
  let reply = @json.parse(line) catch {
    _ => raise @runner.Protocol("malformed process JSON")
  }
  guard reply
    is {
      "version": Number(1, ..),
      "id": Number(response_id, ..),
      "ok": True,
      "output": String(output),
      ..
    } &&
    response_id == id.to_double() else {
    raise @runner.Protocol("invalid process response version, id or payload")
  }
  output
}

///|
async fn Channel::kill(self : Channel) -> Unit {
  if self.closed {
    return
  }
  self.closed = true
  self.writer.close()
  self.process.cancel()
  defer {
    self.reader.close()
    self.errors.close()
  }
  @async.protect_from_cancel(() => ignore(self.process.wait()))
}

///|
async fn Channel::finish(self : Channel) -> Unit {
  if self.closed {
    return
  }
  errdefer self.kill()
  self.writer.close()
  let code = self.process.wait()
  if code != 0 {
    raise @runner.Target("process exited with code " + code.to_string())
  }
  if self.stderr_overflow {
    raise @runner.Protocol("stderr limit exceeded")
  }
  // A valid target emits no extra protocol response after the final ack.
  let mut trailing = self.buffered.length()
  while self.reader.read_some(max_len=4096) is Some(bytes) {
    trailing += bytes.length()
    if trailing > 0 {
      raise @runner.Protocol("unsolicited trailing process output")
    }
  }
  if trailing > 0 {
    raise @runner.Protocol("unsolicited trailing process output")
  }
  self.closed = true
  self.reader.close()
  self.errors.close()
}

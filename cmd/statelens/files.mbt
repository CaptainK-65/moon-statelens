///|
async fn read_text(path : String) -> String {
  let file = @fs.open(path, mode=ReadOnly)
  defer file.close()
  let buffer = @buffer.Buffer()
  for ;; {
    guard @io.Reader::read_some(file, max_len=8192) is Some(chunk) else {
      break
    }
    if chunk.length() > 16777216 - buffer.length() {
      raise @lens.LimitExceeded("input-file-bytes")
    }
    buffer.write_bytes(chunk)
  }
  @utf8.decode(buffer.to_bytes())
}

///|
async fn read_model(path : String) -> @lens.Machine {
  @lens.decode_model(read_text(path))
}

///|
async fn write_new(path : String, contents : String) -> Unit {
  @fs.write_file(path, contents, create_mode=CreateNew)
}

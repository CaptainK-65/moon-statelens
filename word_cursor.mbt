///|
// Length/lexicographic word enumeration without materializing exponential layers.
priv struct WordCursor {
  alphabet : Array[String]
  max_length : Int
  digits : Array[Int]
  mut done : Bool
}

///|
fn WordCursor::new(alphabet : Array[String], max_length : Int) -> WordCursor {
  { alphabet, max_length, digits: [], done: false, }
}

///|
fn WordCursor::next(self : WordCursor) -> Array[String]? {
  if self.done {
    return None
  }
  let word = self.digits.map(index => self.alphabet[index])
  let mut carry = true
  for index = self.digits.length() - 1; index >= 0; index = index - 1 {
    if self.digits[index] + 1 < self.alphabet.length() {
      self.digits[index] += 1
      carry = false
      break
    }
    self.digits[index] = 0
  }
  if carry {
    if self.digits.length() >= self.max_length {
      self.done = true
    } else {
      self.digits.push(0)
    }
  }
  Some(word)
}

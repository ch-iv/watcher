import gleeunit
import gleeunit/should
import watcher

pub fn main() {
  gleeunit.main()
}

// gleeunit test functions end in `_test`
pub fn diff_test() {
  let s1 = "a\nb\nc\nd"
  let s2 = "a\nk\nd"

  watcher.calc_diff(Ok("a"), Ok("a"))
  |> should.equal(watcher.NoDiff("a", "a"))

  watcher.calc_diff(Ok(s1), Ok(s2))
  |> should.equal(watcher.Diff("+k\n-b\n-c", s1, s2))
}

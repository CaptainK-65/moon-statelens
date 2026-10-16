///|
/// Invalid inputs, inconsistent observations and explicit resource limits.
pub suberror LensError {
  InvalidArgument(String)
  UnknownInput(String)
  LimitExceeded(String)
} derive(Debug)

///|
pub extend LensError with @debug.Debug::{to_repr}

///|
/// Invalid inputs, inconsistent observations and explicit resource limits.
pub suberror LensError {
  InvalidArgument(String)
  UnknownInput(String)
  LimitExceeded(String)
  InconsistentObservation(
    word~ : Array[String],
    expected~ : Array[String],
    actual~ : Array[String]
  )
} derive(Debug)

///|
pub extend LensError with @debug.Debug::{to_repr}

/// The number of seconds left at which the pre-ride countdown starts
/// announcing each remaining second by voice.
const countdownCueFrom = 5;

/// The last second of the countdown that still gets a voice cue; the "go"
/// at zero comes from the ride start, not from the countdown tick.
const _lastCuedSecond = 1;

/// The number the pre-ride countdown announces when [secondsLeft] seconds
/// remain, or null when that second gets no voice cue.
int? countdownCueFor(int secondsLeft) =>
    _lastCuedSecond <= secondsLeft && secondsLeft <= countdownCueFrom
    ? secondsLeft
    : null;

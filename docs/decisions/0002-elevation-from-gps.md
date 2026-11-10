# 0002 Elevation from the GPS altitude

Issue: #97. Spec: `/lib/domain/elevation.sdd`, `/lib/tracking/tracking.sdd`, `/lib/data/db/db.sdd`.

## Context

Riders want ascent and descent per ride, recorded live and shown in History. Trackpoints hold no altitude
today, so older rides can never get elevation. GPS altitude is noisy: a standing phone drifts by several
metres, and summing every small change would turn a flat ride into hundreds of metres of climbing.
The app has no barometer access and asks for no new permission.

## Decision

- Each recorded fix keeps the platform altitude when the platform reports a valid one. A vertical accuracy
  worse than `25` m counts as invalid; an unknown accuracy is accepted.
- Ascent and descent come from one pure function with two steps: a trailing running median of `5` samples
  removes spikes, then a step counts only once the smoothed altitude has moved `3` m away from the last
  counted level (hysteresis). The same logic runs incrementally for the live value and in one pass at save,
  and both give the same result.
- The result is stored on the ride (`ascent_m`, `descent_m`) when the ride is saved, like the other stats, so
  History never reads trackpoints for it.
- A ride without altitude data shows no elevation at all, never `0 m`.
- The card shows the ascent for skate types and the descent for snowboard and ski, since downhill is what
  snow riders compare; the detail shows both.

## Rejected alternatives

- **Sum every altitude change.** Simple, but noise adds up to false climbing on any ride.
- **A barometer plugin.** More exact on phones that have one, but a new dependency and a second code path per
  platform; revisit if the GPS result proves too coarse on real rides.
- **Elevation from a terrain model by position.** Needs a network service and sends positions elsewhere.
- **Back-filling older rides.** There is no source for their altitude.

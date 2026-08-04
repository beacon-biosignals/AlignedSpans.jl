```@meta
CurrentModule = AlignedSpans
```

# Design Decisions

This page records why AlignedSpans works the way it does, for maintainers and for anyone reimplementing similar functionality elsewhere. It's organized by topic, with references to the pull requests and issues where each decision was made.

## Endpoints and interval representation

We depend on Intervals.jl to represent span endpoints internally, rather than working only in terms of `TimeSpans.jl` ([PR #2](https://github.com/beacon-biosignals/AlignedSpans.jl/pull/2)). Originally ([PR #1](https://github.com/beacon-biosignals/AlignedSpans.jl/pull/1)), converting an `AlignedSpan` to a `TimeSpan` was done by adding one nanosecond to fake an exclusive endpoint, but this wasn't robust across `TimeSpans.jl` versions (v0.2 and v0.3 represent spans differently, and v0.3 wasn't compatible with Onda at the time). `Intervals.jl` lets us represent open and closed endpoints explicitly, so `to_interval` can convert any span-like input (a `TimeSpan`, an `Interval`, or anything else supporting `start`/`stop`) into one closed-closed `Interval{Nanosecond}` before any rounding happens.

We canonicalize every input span to a closed-closed interval before rounding, rather than branching on open vs. closed endpoints inside the rounding logic ([PR #41](https://github.com/beacon-biosignals/AlignedSpans.jl/pull/41)). The earlier approach handled the closed-open case (as produced by `TimeSpan`) with an ad hoc check inside the rounding functions, which missed a case and produced an off-by-one index at some sample rates. Converting to closed-closed once, in `to_interval`, removed the need for that check, at the cost of adding and subtracting a nanosecond in a few places when converting endpoints.

This mismatch between `AlignedSpan`'s indices (inclusive-inclusive) and `TimeSpan`'s endpoints (inclusive-exclusive) is visible directly:

```@repl decisions_endpoints
using AlignedSpans, TimeSpans, Dates

aligned = AlignedSpan(1, 2:3) # indices 2 and 3 are both included

TimeSpan(aligned) # TimeSpans.jl spans exclude their right endpoint: [1s, 3s)
```

## The index -> time conversion convention

For `TimeSpans.start`/`TimeSpans.stop`, we use `start(span) = time_from_index(sample_rate, first_index)` and `stop(span) = time_from_index(sample_rate, last_index + 1)` ([PR #9](https://github.com/beacon-biosignals/AlignedSpans.jl/pull/9)). We considered instead using the time of the last sample plus one nanosecond, but rejected it for two reasons: durations would come out one sample period short of what's expected (5 samples at 1Hz would have duration `4s + 1ns` instead of `5s`), and two adjacent `AlignedSpan`s would not map to two adjacent `TimeSpan`s (there'd be a gap of almost one sample period between them). Taking the stop as the time of the sample after the last one avoids both problems, and matches the inclusive-inclusive convention of Julia's integer indices to the inclusive-exclusive convention Onda/TimeSpans use.

One consequence of this choice: rounding a span down or inward, then converting the result back to a `TimeSpan`, can produce a span that looks like it grew relative to the input. This is expected; see the warning under [Sample index -> Time](@ref) for a worked example. A smaller illustration of the underlying convention:

```@repl decisions_stop
using AlignedSpans, TimeSpans, Dates

aligned = AlignedSpan(1, 2:3) # samples 2 and 3, at 1Hz

TimeSpan(aligned) # starts when sample 2 occurs, stops when sample 4 would occur

duration(aligned) # 2 samples at 1Hz is a sensible 2 seconds, not `1s + 1ns`
```

## Sample rate representation: floating point vs. rational

`AlignedSpan.sample_rate` is stored as `Union{Int64,Rational{Int64}}`, not `Float64` ([PR #44](https://github.com/beacon-biosignals/AlignedSpans.jl/pull/44)). We found that `time_from_index`, which is used throughout AlignedSpans to convert a sample index into a time, was affected by floating point error at at least one common sample rate (180 Hz): the computed nanosecond time for a given index could come out one nanosecond later than it should, tripping an internal consistency check we already had in place ([issue #40](https://github.com/beacon-biosignals/AlignedSpans.jl/issues/40)).

To fix the underlying floating-point issue, we tested candidate implementations of `time_from_index` against an exact reference computed with `BigInt`/`Rational{BigInt}` arithmetic, across a range of sample rates that don't divide evenly into nanoseconds (`180`, `4//3`, `1//3`, `1//30`, `44_000`, ...) ([PR #41](https://github.com/beacon-biosignals/AlignedSpans.jl/pull/41)). Converting the sample rate to a `Rational` and doing the arithmetic in `Int128`/`Rational` matched the exact reference in every case we tried, but repeating that conversion inside every call to `time_from_index`/`index_from_time` was measurably slower. So instead ([PR #44](https://github.com/beacon-biosignals/AlignedSpans.jl/pull/44)), we do the conversion once, when an `AlignedSpan` is constructed: an integer sample rate stays an `Int64`, a sample rate that's already a `Rational` stays as-is, and anything else (typically a `Float64`) is converted with `rationalize`.

This does change the type stored in `sample_rate` for callers who were previously getting a `Float64` there. We decided the correctness and performance benefits were worth it: `sample_rate` was never documented to be a `Float64`, and we judged the chance of downstream code depending on that incidental detail to be small.

The conversion is visible on the constructed `AlignedSpan`:

```@repl decisions_rate
using AlignedSpans

AlignedSpan(180, 1:100).sample_rate # already an Int, kept as-is

AlignedSpan(1 / 30, 1:100).sample_rate # a Float64 gets rationalize'd

AlignedSpan(1 // 30, 1:100).sample_rate # an exact Rational is kept as-is, with no approximation
```

## Rounding modes: why four, and how they're named

We provide four rounding modes because they answer genuinely different questions about which samples a span corresponds to: `RoundSpanDown` matches `TimeSpans.index_from_time`'s existing rounding behavior; `RoundInward` gives exactly the samples that occur within the span; `ConstantSamplesRoundingMode` guarantees a fixed sample count for spans of the same duration; `RoundFullyContainedSampleSpans` treats each sample as covering a span of time rather than an instant. The first two can disagree on the same input:

```@repl decisions_modes
using AlignedSpans, TimeSpans, Dates

span = TimeSpan(Millisecond(1500), Millisecond(2500))

AlignedSpan(1, span, RoundSpanDown) # rounds both endpoints down: 1.5s -> 1s, 2.5s -> 2s

AlignedSpan(1, span, RoundInward) # shrinks until both endpoints land on samples
```

Naming `RoundSpanDown` took a few iterations ([PR #9](https://github.com/beacon-biosignals/AlignedSpans.jl/pull/9)). We initially called it `RoundEndsDown`, with an `EndpointRoundingMode` type, but `RoundDown` is already exported by `Base` for rounding a single value, and reusing it as part of a name for rounding both ends of an interval was judged confusing. We tried `RoundEndpointsDown`, but "endpoint" was still ambiguous about which endpoint. We settled on `SpanRoundingMode`/`RoundSpanDown`, which reads as "the mode that rounds the span down."

`RoundFullyContainedSampleSpans` was added later ([PR #38](https://github.com/beacon-biosignals/AlignedSpans.jl/pull/38)), after `RoundInward` produced a result that a user found surprising ([issue #36](https://github.com/beacon-biosignals/AlignedSpans.jl/issues/36)): rounding a span with `RoundInward` at 1/30Hz could produce an `AlignedSpan` that, once converted back to a `TimeSpan`, extended well past the original input. `RoundInward` was doing exactly what it's documented to do — including every sample whose instant occurs within the span — but that's not the answer you want if you think of each sample as covering a span of time, as with a hypnogram. Rather than changing `RoundInward`'s semantics, we added `RoundFullyContainedSampleSpans` as a separate mode for that case.

## Warnings and asserts for internal invariants

A few places in `interop.jl` check, after rounding, that the rounding did what it was supposed to do, and either raise an error or log a warning if not, depending on `AlignedSpans.ASSERTS_ON[]` (which defaults to `false`) ([PR #37](https://github.com/beacon-biosignals/AlignedSpans.jl/pull/37)). We expect these checks to never fire; if they do, it means there's a bug in AlignedSpans, not in the caller's input. We default to a rate-limited warning rather than an error because AlignedSpans is used in production data pipelines, and we'd rather flag a likely bug loudly than stop a batch job outright. Setting `ASSERTS_ON[] = true` turns these into hard errors, which is useful in testing. These checks are exactly what caught the floating-point issue described above ([issue #40](https://github.com/beacon-biosignals/AlignedSpans.jl/issues/40)).

```@repl decisions_asserts
using AlignedSpans

AlignedSpans.ASSERTS_ON[] # defaults to false: violations warn, they don't throw

AlignedSpans.ASSERTS_ON[] = true # useful in tests, to turn violations into hard failures

AlignedSpans.ASSERTS_ON[] = false # restore the default
```

## Decisions we've deferred

We allow `AlignedSpan`s with indices that don't correspond to any actual sample of a given signal, including negative indices ([issue #15](https://github.com/beacon-biosignals/AlignedSpans.jl/issues/15), [PR #16](https://github.com/beacon-biosignals/AlignedSpans.jl/pull/16)). We initially copied a `sample_time >= 0` check from `TimeSpans.index_from_time`, where it made sense, but an `AlignedSpan` isn't necessarily tied to a specific `Samples` object with a known start and duration — it's a sample-rate-aligned span of time, so restricting it to only ever describe samples that already exist doesn't hold up. (Indexing an out-of-range `AlignedSpan` into an actual `Samples` object still raises a `BoundsError` at that point.)

```@repl decisions_negative
using AlignedSpans

AlignedSpan(1, -5:10) # allowed: this span starts before index 1 of some signal
```

`consecutive_subspans` supports `keep_last=false` so its behavior can match `consecutive_overlapping_subspans` ([PR #19](https://github.com/beacon-biosignals/AlignedSpans.jl/pull/19)), but we haven't extended `keep_last=true` semantics to the overlapping case ([issue #20](https://github.com/beacon-biosignals/AlignedSpans.jl/issues/20)): with overlapping windows, it's not obvious what a shorter last window should mean (if there's 8-fold overlap, do the last 7 windows all get shorter, or just the very last one?). We're leaving this until someone has a concrete use case.

```@repl decisions_keep_last
using AlignedSpans

span = AlignedSpan(1, 1:10)

collect(consecutive_subspans(span, 3)) # keep_last=true (default): last window is shorter

collect(consecutive_subspans(span, 3; keep_last=false)) # drops the short last window instead

collect(consecutive_overlapping_subspans(span, 3, 2)) # overlapping windows only ever come in the "keep_last=false" style
```

We've sketched, but not implemented, `TimeSpans.translate` for `AlignedSpan` ([issue #12](https://github.com/beacon-biosignals/AlignedSpans.jl/issues/12)) and `merge_aligned_spans` ([issue #22](https://github.com/beacon-biosignals/AlignedSpans.jl/issues/22)). The generic `TimeSpans.translate` fallback already works for `AlignedSpan`s, but shifts the time values directly and can change the resulting sample count; an `AlignedSpan`-specific implementation would shift by a number of samples instead, preserving the count:

```@repl decisions_translate
using AlignedSpans, TimeSpans, Dates

span = AlignedSpan(3, 1:10) # 10 samples at 3Hz

n_samples(span)

shifted = TimeSpans.translate(span, Second(1)) # the generic fallback shifts the *time* and returns a TimeSpan

n_samples(AlignedSpan(span.sample_rate, shifted, RoundSpanDown)) # re-rounding isn't guaranteed to match n_samples(span)
```

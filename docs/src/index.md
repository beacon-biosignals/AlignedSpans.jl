```@meta
CurrentModule = AlignedSpans
```

# AlignedSpans

See [API documentation](@ref) for how to construct AlignedSpans, along with some utilities, or below for some examples and motivation.

### Continuous -> Discrete

Continuous timespans can be rounded (or "aligned") to the individual sample values by using the constructor `AlignedSpan`, which takes a `sample_rate`, a `span`, and a description of how to round time endpoints to indices. This constructs an `AlignedSpan` which supports Onda indexing. Internally, an `AlignedSpan` stores indices, not times, and any rounding happens when it is created instead of when indexing into `samples`.

Rounding options:

* `EndpointRoundingMode`: consists of a `RoundingMode` for the `start` and `stop` of the span.
    * The alias `RoundInward = EndpointRoundingMode(RoundUp, RoundDown)`, for example, constructs the largest span such that all samples are entirely contained within `span`.
    * The alias `RoundEndsDown = EndpointRoundingMode(RoundDown, RoundDown)` matches the rounding semantics of `TimeSpans.index_from_time(sample_rate, span)`.
* `ConstantSamplesRoundingMode` consists of a `RoundingMode` for the `start` alone. The `stop` is determined from the `start` plus a number of samples which is a function only of the sampling rate and the `duration` of the span.

Also provides a helper `consecutive_subspans` to partition an `AlignedSpan` into smaller consecutive `AlignedSpans` of equal size (except possibly the last one).

### Discrete -> Continuous 

AlignedSpan's support `TimeSpans.start` and `TimeSpans.stop`, so they can be used a continuous-time spans. The semantics of this are:

> For any index included in an `AlignedSpan`, the time at which the corresponding sample occurred (inclusive) to the time at which the next sample occurred (exclusive) is associated to the continuous-time representation of the span.

As an example, if the sample rate is 1, and indices `2:3` are associated to a `span`, then the associated `TimeSpan` is `TimeSpan(Second(1), Second(3))`. That's because sample 2 occur at time `Second(1)`, and is considered to "last" until sample 3, which occurs at `Second(2)`. Next, sample 3 occurs at time `Second(2)` and is considered to "last" until sample 4, which occurs at `Second(3)`. Therefore, the total span associated to `2:3` is `Second(1)` to `Second(3)`.

This choice of conversion matches the inclusive-inclusive indexing of Julia integer indices to the inclusive-exclusive semantics of TimeSpans.jl, and allows for roundtripping and sensible durations:

```jldoctest
julia> using AlignedSpans, TimeSpans, Dates

julia> aligned = AlignedSpan(1, 2, 3)
AlignedSpan(1.0, 2, 3)

julia> ts = TimeSpan(aligned)
TimeSpan(00:00:01.000000000, 00:00:03.000000000)

julia> aligned == AlignedSpan(1, ts, RoundInward)
true

julia> aligned == AlignedSpan(1, ts, RoundEndsDown)
true

julia> duration(aligned) == duration(ts) == Second(2)
true
```

## Quick example

Let's consider the following `TimeSpan`
```@repl timespan
using TimeSpans, AlignedSpans, Dates

span = TimeSpan(Millisecond(1500), Millisecond(3500))
```

If we have a 1 Hz signal, there are various ways we can index into it using this TimeSpan. One option is to round the endpoints down:
```@repl timespan

down_span = AlignedSpan(1, span, RoundEndsDown)

n_samples(down_span)
```
The second sample of our signal occurs at time 1s (since we have a 1Hz signal that starts at 0s). When we round the starting endpoint down from 1.5s to the nearest sample, we find that sample. This can be seen as "the last sample that occurred before time 1.5s".

Perhaps instead we would like to round the endpoints "inward" to only consider samples occurring with the time span:

```@repl timespan
in_span = AlignedSpan(1, span, RoundInward)
n_samples(in_span)
```

## Motivation

Let's say I want to plot some samples over time, and I have a nice function `plot(::TimeSpan, ::Samples)` to use.

```@repl motivation
using TimeSpans, Onda, Dates
sample_rate = 1 # 1 Hz -> slow to exaggerate the effect
samples = Samples(permutedims(0:10), SamplesInfo("feature", ["a"], "microvolt", 0.5, 0.0, UInt16, sample_rate), false)
span = TimeSpan(Millisecond(1500), Millisecond(4000))
```

Now I want to execute some call

```julia
plot(span, samples[:, span])
```

for some `plot` that understands TimeSpans -- doesn't matter what function, exactly.

What is wrong with this?

Let's take a look at the samples we are plotting:
```@repl motivation
samples[:, span] # TimeSpans v0.2; v0.3 will have one more sample
```
These are three samples that correspond to times 1s, 2s, and 3s. However, what we gave to the `x`-axis of our plotting function is `TimeSpan(Millisecond(1500), Millisecond(3500))`, which starts at 1.5s and goes to 3.5s. In other words, our plot will have an incorrect 0.5s offset!

Note that `plot` is just an example; any function where one is separately passing both a "timespan of interest" and "feature values from that timespan" will have similar issues if one isn't careful about what exactly `samples[:, span]` is doing.

### The fix

Let's take the same setup, with our
```@repl motivation
span
```

This time, we do
```@repl motivation
using AlignedSpans
aligned_span = AlignedSpan(samples.info.sample_rate, span, RoundEndsDown)
samples[:, aligned_span]
```

Here, I get the same `samples`. However, now I have the actual span corresponding to those samples, namely `aligned_span`. So if I call my

```julia
plot(aligned_span, samples[:, aligned_span])
```

I'll have the correct alignment between the points on the x-axis and y-axis.

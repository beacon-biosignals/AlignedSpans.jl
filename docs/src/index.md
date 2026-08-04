```@meta
CurrentModule = AlignedSpans
```

# AlignedSpans

See [API documentation](@ref) for how to construct AlignedSpans, along with some utilities, and [Examples](@ref) for further worked examples.

AlignedSpans, like Onda, primarily treats samples as instants in time (rather than spans), and cares about "which samples have occurred by such and such point in time" rather than "what sample-span is ongoing at such and such point in time". See [`RoundFullyContainedSampleSpans`](@ref) for an exception, an approach that treats samples as spans.

### Time → Sample index

Timespans can be rounded (or "aligned") to the individual sample values by using the constructor `AlignedSpan`, which takes a `sample_rate`, a `span`, and a description of how to round time endpoints to sample indices. This constructs an `AlignedSpan` which supports Onda indexing. Internally, an `AlignedSpan` store sample indices, not times, and any rounding happens when it is created instead of when indexing into `samples`.

Rounding options:

* `SpanRoundingMode`: consists of a `RoundingMode` for the `start` and `stop` of the span.
    * The alias `RoundInward = SpanRoundingMode(RoundUp, RoundDown)`, for example, constructs the largest span such that all samples are entirely contained within `span`.
    * The alias `RoundSpanDown = SpanRoundingMode(RoundDown, RoundDown)` matches the rounding semantics of `TimeSpans.index_from_time(sample_rate, span)`.
* `ConstantSamplesRoundingMode` consists of a `RoundingMode` for the `start` alone. The `stop` is determined from the `start` plus a number of samples which is a function only of the sampling rate and the `duration` of the span.
* `RoundFullyContainedSampleSpans` This is a special rounding mode which differs from the other rounding modes by associating each sample with a _span_ (from the instant the sample occurs until just before the next sample occurs), and rounding inwards to the "sample spans" that are fully contained in the input span.

See [Choosing a rounding mode](@ref) for guidance on which of these to use.

!!! warning
    If the input `span` is not sample-aligned, meaning the `start` and `stop` of the input span are not exact multiples of the sample rate, the results can be non-intuitive at first, since the rounding is relative to the samples themselves rather than to the input span's endpoints. See the warning in [Choosing a rounding mode](@ref) for a worked example.

Also provides a helper `consecutive_subspans` to partition an `AlignedSpan` into smaller consecutive `AlignedSpans` of equal size (except possibly the last one).

### Sample index → Time

AlignedSpan's support `TimeSpans.start` and `TimeSpans.stop`, so they can be used as time spans. The semantics of this are:

> For any index included in an `AlignedSpan`, the time at which the corresponding sample occurred (inclusive) to the time at which the next sample occurred (exclusive) is associated to the time representation of the span.

As an example, if the sample rate is 1, and sample indices `2:3` are associated to a `span`, then the associated `TimeSpan` is `TimeSpan(Second(1), Second(3))`. That's because sample 2 occur at time `Second(1)`, and is considered to "last" until sample 3, which occurs at `Second(2)`. Next, sample 3 occurs at time `Second(2)` and is considered to "last" until sample 4, which occurs at `Second(3)`. Therefore, the total span associated to `2:3` is `Second(1)` to `Second(3)`.

In diagram form, the inclusive interval of sample indices `[2, 3]` is associated inclusive-exclusive interval of seconds, `[1, 3)`:
```
Index       1   [2    3]    4     5
Time (s)    0   [1    2     3)    4
```

This choice of conversion matches the inclusive-inclusive indexing of Julia integer indices to the inclusive-exclusive semantics Onda/TimeSpans use, and allows for roundtripping and sensible durations. Indices `2:3` at a sample rate of 1Hz, and the `TimeSpan` they're associated to:

```@raw html
<div class="aligned-spans-widget" data-scenario="index-to-time" data-results="given"></div>
```

This is verified in code:

```jldoctest
julia> using AlignedSpans, TimeSpans, Dates

julia> aligned = AlignedSpan(1, 2:3)
AlignedSpan(1, 2, 3)

julia> ts = TimeSpan(aligned)
TimeSpan(00:00:01.000000000, 00:00:03.000000000)

julia> aligned == AlignedSpan(1, ts, RoundInward)
true

julia> aligned == AlignedSpan(1, ts, RoundSpanDown)
true

julia> duration(aligned) == duration(ts) == Second(2)
true
```

!!! warning
    For non-integer sample rates, roundtripping perfectly is not always possible. Sample rates that aren't already an `Int` or a `Rational` are converted with `rationalize`; see [Design Decisions](@ref) for why.

!!! warning
    Because the stop of the time representation of an `AlignedSpan` is the time at which the sample _after_ the last included one occurs, rounding a span and then converting it back to a `TimeSpan` can give a result that looks larger than the input. For example, at 1/30Hz, the samples occur at 00:00, 00:30, 01:00, and so on. The span `TimeSpan(0, Second(30) + Nanosecond(1))` contains two samples, the ones at 00:00 and 00:30:

    ```jldoctest
    julia> using TimeSpans, AlignedSpans, Dates

    julia> sample_rate = 1 // 30
    1//30

    julia> input = TimeSpan(0, Second(30) + Nanosecond(1))
    TimeSpan(00:00:00.000000000, 00:00:30.000000001)

    julia> aligned = AlignedSpan(sample_rate, input, RoundInward) # or RoundSpanDown
    AlignedSpan(1//30, 1, 2)

    julia> TimeSpan(aligned)
    TimeSpan(00:00:00.000000000, 00:01:00.000000000)
    ```

    Even though `RoundInward` and `RoundSpanDown` both round the right endpoint down, `TimeSpan(aligned)` is `TimeSpan(0, Second(60))`, not `TimeSpan(0, Second(30) + Nanosecond(1))`. That's because indices 1 and 2 correspond to the time from the first sample until just before the sample that would come after index 2, which occurs at `Second(60)`.

    The shaded region below is the input span; the dots are individual samples at 1/30Hz; the colored bracket is the resulting `AlignedSpan`, converted back to a `TimeSpan`:

    ```@raw html
    <div class="aligned-spans-widget" data-scenario="rounding-grows-span" data-results="RoundInward"></div>
    ```

## Motivation

Let's say I want to plot some samples over time, and I have a nice function `plot(::TimeSpan, ::Samples)` to use.

```@repl motivation
using TimeSpans, Onda, Dates
sample_rate = 1 # 1 Hz → slow to exaggerate the effect
samples = Samples(permutedims(0:10), SamplesInfoV2(; sensor_type="feature", channels=["a"], sample_unit="microvolt", sample_resolution_in_unit=0.5, sample_offset_in_unit=0.0, sample_type=UInt16, sample_rate), false)
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

The shaded region below is the (wrong) span we plotted against; the bracket is the (correct) span the samples actually cover:

```@raw html
<div class="aligned-spans-widget" data-scenario="motivation-offset" data-results="RoundSpanDown"></div>
```

Note that `plot` is just an example; any function where one is separately passing both a "timespan of interest" and "feature values from that timespan" will have similar issues if one isn't careful about what exactly `samples[:, span]` is doing.

### The fix

Let's take the same setup, with our
```@repl motivation
span
```

This time, we do
```@repl motivation
using AlignedSpans
aligned_span = AlignedSpan(samples.info.sample_rate, span, RoundSpanDown)
samples[:, aligned_span]
```

Here, I get the same `samples`. However, now I have the actual span corresponding to those samples, namely `aligned_span`. So if I call my

```julia
plot(aligned_span, samples[:, aligned_span])
```

I'll have the correct alignment between the points on the x-axis and y-axis.

```@meta
CurrentModule = AlignedSpans
```

# Examples

## EEG and other instant-like samples

Most sensor data (EEG voltage traces, and similar) is naturally modeled with each sample as an instant in time: a sample is a single measurement taken at a point in time, not a summary of some span of time. This is the default way AlignedSpans treats samples, so `RoundInward` and `RoundSpanDown` (see [Choosing a rounding mode](@ref)) are the rounding modes to reach for.

Let's consider the following `TimeSpan`
```@repl timespan
using TimeSpans, AlignedSpans, Dates

span = TimeSpan(Millisecond(1500), Millisecond(3500))
```

If we have a 1 Hz signal, there are various ways we can index into it using this TimeSpan. One option is to round the endpoints down:
```@repl timespan

down_span = AlignedSpan(1, span, RoundSpanDown)

n_samples(down_span)
```
The second sample of our signal occurs at time 1s (since we have a 1Hz signal that starts at 0s). When we round the starting endpoint down from 1.5s to the nearest sample, we find that sample. This can be seen as "the last sample that occurred before time 1.5s".

Perhaps instead we would like to round the endpoints "inward" to only consider samples occurring with the time span:

```@repl timespan
in_span = AlignedSpan(1, span, RoundInward)
n_samples(in_span)
```

```@raw html
<div class="aligned-spans-widget" data-scenario="eeg-onda-indexing" data-results="RoundSpanDown,RoundInward"></div>
```

## Hypnograms and other span-like samples

Some signals, like hypnograms, are more naturally thought of as a sequence of spans rather than a sequence of instants: each sample summarizes some region of time (e.g. a 30 second sleep-stage epoch) rather than being measured at a single instant. For these, `RoundFullyContainedSampleSpans` is usually a better fit than `RoundInward`.

```@repl hypnogram
using TimeSpans, AlignedSpans, Dates

sample_rate = 1 // 30

input = TimeSpan(0, Second(30) + Nanosecond(1))

aligned = AlignedSpan(sample_rate, input, RoundFullyContainedSampleSpans)

TimeSpan(aligned)
```

Compare this to rounding the same `input` with `RoundInward`:

```@repl hypnogram
AlignedSpan(sample_rate, input, RoundInward)
```

`RoundInward` includes both the sample at 00:00 and the sample at 00:30, since both occur within `input`. `RoundFullyContainedSampleSpans` includes only the sample at 00:00, since `input` doesn't fully contain the sample-span from 00:30 to 01:00. The filled blocks below are the sample-spans that `RoundFullyContainedSampleSpans` reasons about; the dots are the sample instants that `RoundInward` reasons about:

```@raw html
<div class="aligned-spans-widget" data-scenario="rounding-grows-span" data-results="RoundInward,RoundFullyContainedSampleSpans"></div>
```

## Getting a consistent number of samples across spans

`RoundInward` and `RoundSpanDown` can give a different number of samples for two spans of the same duration, depending on how each span happens to line up with the sample rate. If instead you want every span of a given duration to have the same number of samples, for example when cutting a signal into fixed-size windows, use `ConstantSamplesRoundingMode`:

```@repl windows
using TimeSpans, AlignedSpans, Dates

sample_rate = 3

span1 = TimeSpan(Millisecond(0), Millisecond(700))
span2 = TimeSpan(Millisecond(100), Millisecond(800))
```

For `span1`:

```@repl windows
n_samples(AlignedSpan(sample_rate, span1, RoundInward))
n_samples(AlignedSpan(sample_rate, span1, ConstantSamplesRoundingMode(RoundDown)))
```

```@raw html
<div class="aligned-spans-widget" data-scenario="constant-samples-1" data-results="RoundInward,ConstantSamplesRoundingMode"></div>
```

`span2` has the same duration as `span1`, but starts 100ms later, which changes how it lines up with the sample rate:

```@repl windows
n_samples(AlignedSpan(sample_rate, span2, RoundInward))
n_samples(AlignedSpan(sample_rate, span2, ConstantSamplesRoundingMode(RoundDown)))
```

```@raw html
<div class="aligned-spans-widget" data-scenario="constant-samples-2" data-results="RoundInward,ConstantSamplesRoundingMode"></div>
```

`RoundInward` gives `span1` 3 samples but `span2` only 2, even though they have the same duration; `ConstantSamplesRoundingMode` gives both 2.

## Splitting a span into fixed-size or sliding windows

Once you have an `AlignedSpan`, use `consecutive_subspans` to split it into consecutive, non-overlapping windows, or `consecutive_overlapping_subspans` for sliding windows with a fixed hop between them:

```@repl chunking
using AlignedSpans

span = AlignedSpan(1, 1:10) # 10 samples at 1Hz

collect(consecutive_subspans(span, 3)) # windows of 3 samples; the last one may be shorter
```

```@raw html
<div class="aligned-spans-widget" data-scenario="windowing" data-results="windows"></div>
```

Pass `keep_last=false` to drop that short last window instead, if your downstream code requires every window to have exactly the same number of samples:

```@repl chunking
collect(consecutive_subspans(span, 3; keep_last=false))
```

```@raw html
<div class="aligned-spans-widget" data-scenario="windowing" data-results="windows-keep-last-false"></div>
```

`consecutive_overlapping_subspans` gives sliding windows with a fixed hop between them; it only supports the `keep_last=false` style, since it's not obvious what a partial window should mean once windows overlap:

```@repl chunking
collect(consecutive_overlapping_subspans(span, 3, 2)) # windows of 3 samples, hopping by 2
```

```@raw html
<div class="aligned-spans-widget" data-scenario="windowing" data-results="windows-overlapping"></div>
```

## Spans that start before or run past your recording

An `AlignedSpan` doesn't need to correspond to samples that actually exist in some particular recording: it's a sample-rate-aligned span of time, and can have negative indices or indices beyond the end of any specific signal. This includes rounding a `TimeSpan` whose start time is negative, i.e. before index 1 of whatever it's relative to:

```@repl outofrange
using AlignedSpans, TimeSpans, Dates

AlignedSpan(1238, TimeSpan(Nanosecond(-32), Nanosecond(2)), RoundSpanDown) # the input TimeSpan starts before time 0
```

```@raw html
<div class="aligned-spans-widget" data-scenario="out-of-range-timespan" data-results="RoundSpanDown"></div>
```

The same applies to constructing a span directly from out-of-range indices:

```@repl outofrange
AlignedSpan(1, -5:10) # starts 5 samples before index 1 of some signal
```

```@raw html
<div class="aligned-spans-widget" data-scenario="out-of-range-raw" data-results="given"></div>
```

Indexing a span like this into an actual `Samples` object raises a `BoundsError` once you try, but constructing the `AlignedSpan` itself doesn't require that a signal covering the whole span already exists.

## Shifting a span in time

To shift an `AlignedSpan` while keeping the same number of samples, shift its indices directly rather than converting through a `TimeSpan`:

```@repl shifting
using AlignedSpans, Dates

span = AlignedSpan(3, 1:10) # 10 samples at 3Hz

n = n_samples(span.sample_rate, Second(1)) # number of samples in a 1s shift

shifted = AlignedSpan(span.sample_rate, (span.first_index + n):(span.last_index + n))

n_samples(shifted) == n_samples(span)
```

`TimeSpans.translate(span, Second(1))` also works, but it shifts the underlying time and then re-rounds, which isn't guaranteed to preserve the number of samples. This may be improved in subsequent releases of AlignedSpans.jl.

```@raw html
<div class="aligned-spans-widget" data-scenario="shifting" data-results="original,shifted"></div>
```

## Computing sample counts from compound durations

`n_samples` accepts any `Dates.Period` or `Dates.CompoundPeriod`, so durations built up from mixed units work directly, without converting to a single unit first:

```@repl compound
using AlignedSpans, Dates

n_samples(1e9, Minute(1) + Nanosecond(1))
```

## Passing an exact sample rate

If you know your sample rate exactly, for example `1//30` for a hypnogram sampled every 30 seconds, you can pass that `Rational` directly to `AlignedSpan`. If you instead pass a `Float64`, such as `1/30`, it is converted to the nearest `Rational` using `rationalize`:

```@repl rates
using AlignedSpans

AlignedSpan(1 // 30, 1:100).sample_rate

AlignedSpan(1 / 30, 1:100).sample_rate
```

See [Design Decisions](@ref) for why sample rates are stored as an `Int` or `Rational` rather than a `Float64`.

## Indexing an Onda `Samples` object: TimeSpans vs. AlignedSpans

Onda's `Samples` supports indexing directly with a `TimeSpan`: `samples[:, span]`. Internally, this rounds `span`'s endpoints down to the nearest samples, matching `TimeSpans.index_from_time`. That's exactly what `RoundSpanDown` does too, so indexing with `AlignedSpan(sample_rate, span, RoundSpanDown)` gives identical results to indexing with `span` directly, but also gives you the `AlignedSpan` itself to work with. Indexing with `RoundInward` instead can give you *different* samples, since it answers a different question ("which samples occur entirely within `span`" rather than "round `span`'s endpoints down"):

```@repl onda_indexing
using Onda, TimeSpans, AlignedSpans, Dates

sample_rate = 1 # 1 Hz -> slow to exaggerate the effect
samples = Samples(permutedims(0:10), SamplesInfoV2(; sensor_type="feature", channels=["a"], sample_unit="microvolt", sample_resolution_in_unit=0.5, sample_offset_in_unit=0.0, sample_type=UInt16, sample_rate), false)
span = TimeSpan(Millisecond(1500), Millisecond(3500))

samples[:, span] # indexing directly with a TimeSpan
```

```@repl onda_indexing
samples[:, AlignedSpan(sample_rate, span, RoundSpanDown)] # matches samples[:, span]
```

```@repl onda_indexing
samples[:, AlignedSpan(sample_rate, span, RoundInward)] # does not match: a different set of samples
```

```@raw html
<div class="aligned-spans-widget" data-scenario="eeg-onda-indexing" data-results="RoundSpanDown,RoundInward"></div>
```

If you need to keep track of exactly which span of time your extracted samples correspond to (for example, to plot them against the correct time axis), construct the `AlignedSpan` with `RoundSpanDown` first, and index with that instead of the original `TimeSpan`:

```@repl onda_indexing
aligned_span = AlignedSpan(sample_rate, span, RoundSpanDown)

samples[:, aligned_span] == samples[:, span]

TimeSpan(aligned_span) # the actual span covered by these samples, not `span` itself
```

`span` starts at 1.5s, but the samples returned start at 1s: `TimeSpan(aligned_span)` reflects that, while `span` does not.

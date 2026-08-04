# API documentation

## Choosing a rounding mode

* Use `RoundSpanDown` by default, or whenever you need to match the rounding Onda/TimeSpans already use elsewhere (`TimeSpans.index_from_time(sample_rate, span)`).
* Use `RoundInward` when you need exactly the samples that occur within a span and no others, treating each sample as an instant in time.
* Use `ConstantSamplesRoundingMode` when you need spans of the same duration to always produce the same number of samples, regardless of how they line up with the sample rate (for example, when cutting a signal into fixed-size windows).
* Use `RoundFullyContainedSampleSpans` when each sample represents a span of time rather than an instant (for example, a hypnogram, where each sample is a sleep-stage label covering some number of seconds), and you want only the sample-spans that are fully contained in the input span.

!!! warning
    `RoundInward` and `RoundFullyContainedSampleSpans` can give different results because they answer different questions about the same input span. Consider a 1/30Hz signal and the span `TimeSpan(0, Second(30) + Nanosecond(1))`, which contains the samples at 00:00 and 00:30:

    ```jldoctest
    julia> using TimeSpans, AlignedSpans, Dates

    julia> sample_rate = 1 // 30
    1//30

    julia> input = TimeSpan(0, Second(30) + Nanosecond(1))
    TimeSpan(00:00:00.000000000, 00:00:30.000000001)

    julia> AlignedSpan(sample_rate, input, RoundInward)
    AlignedSpan(1//30, 1, 2)

    julia> AlignedSpan(sample_rate, input, RoundFullyContainedSampleSpans)
    AlignedSpan(1//30, 1, 1)
    ```

    `RoundInward` includes both samples, since both occur within `input`. `RoundFullyContainedSampleSpans` includes only the first one, since `input` doesn't fully contain the sample-span from 00:30 to 01:00. See [Design Decisions](@ref) for why there are four separate rounding modes rather than one mode that tries to handle every case.

```@docs
AlignedSpan
AlignedSpans.SpanRoundingMode
AlignedSpans.RoundSpanDown
AlignedSpans.RoundInward
AlignedSpans.RoundFullyContainedSampleSpans
AlignedSpan(sample_rate, span, mode::SpanRoundingMode)
AlignedSpans.ConstantSamplesRoundingMode
AlignedSpan(sample_rate, span, mode::ConstantSamplesRoundingMode)
consecutive_subspans
consecutive_overlapping_subspans
n_samples
AlignedSpans.indices
```

## Interface for conversion from time spans

In order to support conversion of time `span` types to [`AlignedSpan`](@ref)'s,
three methods may be defined. These are not exported, because they are generally not used directly, but rather defined in order to facilitate use of the [`AlignedSpan`](@ref) constructors.

```@docs
AlignedSpans.start_index_from_time
AlignedSpans.stop_index_from_time
```

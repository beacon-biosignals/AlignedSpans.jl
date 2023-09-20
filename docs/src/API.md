# API documentation

```@docs
AlignedSpan
AlignedSpans.SpanRoundingMode
AlignedSpans.RoundInward
AlignedSpans.RoundSpanDown
AlignedSpan(sample_rate, span, mode::SpanRoundingMode)
AlignedSpans.ConstantSamplesRoundingMode
AlignedSpan(sample_rate, span, mode::ConstantSamplesRoundingMode)
consecutive_subspans
consecutive_overlapping_subspans
n_samples
AlignedSpans.indices
```

## Interface for conversion from continuous time spans

In order to support conversion of continuous time `span` types to [`AlignedSpan`](@ref)'s,
three methods may be defined. These are not exported, because they are generally not used directly, but rather defined in order to facilitate use of the [`AlignedSpan`](@ref) constructors.

```@docs
AlignedSpans.start_index_from_time
AlignedSpans.stop_index_from_time
```

# API Documentation

```@meta
CurrentModule = AlignedSpans
```

## Example

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


## Interface

```@docs
AlignedSpan
AlignedSpans.start_index_from_time
AlignedSpans.stop_index_from_time
AlignedSpans.duration
AlignedSpans.EndpointRoundingMode
AlignedSpans.ConstantSamplesRoundingMode
```

## Utilities

```@docs
n_samples
consecutive_subspans
```

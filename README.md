# AlignedSpans

[![Build Status](https://github.com/ericphanson/AlignedSpans.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/ericphanson/AlignedSpans.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/ericphanson/AlignedSpans.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/ericphanson/AlignedSpans.jl)

## Motivation

Let's say I want to plot some samples over time, and I have a nice function `plot(::TimeSpan, ::Samples)` to use.

```julia
julia> using TimeSpans, Onda, Dates

julia> sample_rate = 1 # 1 Hz -> slow to exaggerate the effect
1

julia> samples =  Samples(permutedims(0:10), SamplesInfo("feature", ["a"], "microvolt", 0.5, 0.0, UInt16, sample_rate), false)
Samples (00:00:11.000000000):
  info.kind: "feature"
  info.channels: ["a"]
  info.sample_unit: "microvolt"
  info.sample_resolution_in_unit: 0.5
  info.sample_offset_in_unit: 0.0
  sample_type(info): UInt16
  info.sample_rate: 1 Hz
  encoded: false
  data:
1×11 reshape(::UnitRange{Int64}, 1, 11) with eltype Int64:
 0  1  2  3  4  5  6  7  8  9  10

julia> span = TimeSpan(Millisecond(1500), Millisecond(3500))
TimeSpan(00:00:01.500000000, 00:00:03.500000000)
```

Now I want to execute some call

```julia
plot(span, samples[:, span]) # for some `plot` that understands TimeSpans -- doesn't matter what
```

What is wrong with this?

Let's take a look at the samples we are plotting:
```julia
julia> samples[:, span]  # post TimeSpans#28 being fixed
Samples (00:00:03.000000000):
  info.kind: "feature"
  info.channels: ["a"]
  info.sample_unit: "microvolt"
  info.sample_resolution_in_unit: 0.5
  info.sample_offset_in_unit: 0.0
  sample_type(info): UInt16
  info.sample_rate: 1 Hz
  encoded: false
  data:
1×3 Matrix{Int64}:
 1  2  3
```
These are three samples that correspond to times 1s, 2s, and 3s. However, what we gave to the `x`-axis of our plotting function is `TimeSpan(Millisecond(1500), Millisecond(3500))`, which starts at 1.5s and goes to 3.5s. In other words, our plot will have an incorrect 0.5s offset!

Note that `plot` is just an example; any function where one is separately passing both a "timespan of interest" and "feature values from that timespan" will have similar issues if one isn't careful about what exactly `samples[:, span]` is doing.

### The fix

Let's take the same setup, with our
```julia
julia> span = TimeSpan(Millisecond(1500), Millisecond(3500))
TimeSpan(00:00:01.500000000, 00:00:03.500000000)
```

But now, I want to be careful, so I do
```julia
julia> aligned_span = AlignedSpan(samples.info.sample_rate, span, RoundDown)
AlignedSpan(00:00:01.000000000, 00:00:03.000000001)

julia> samples[:, aligned_span]
Samples (00:00:03.000000000):
  info.kind: "feature"
  info.channels: ["a"]
  info.sample_unit: "microvolt"
  info.sample_resolution_in_unit: 0.5
  info.sample_offset_in_unit: 0.0
  sample_type(info): UInt16
  info.sample_rate: 1 Hz
  encoded: false
  data:
1×3 Matrix{Int64}:
 1  2  3

```

Here, I get the same `samples`. However, now I have the actual span corresponding to those samples, namely `aligned_span`. So if I call my

```julia
plot(aligned_span, samples[:, aligned_span])
```

I won't have that pesky 0.5s offset.

## Usage

The main object is `AlignedSpan` which takes in a `sample_rate`, a `span`, and a `RoundingMode`. This constructs an `AlignedSpan` which satisfies the TimeSpans.jl interface. Internally, an `AlignedSpan` stores indices, not times,
and any rounding happens when it is created instead of when indexing into `samples`.

 There are three currently implemented options for `RoundingMode`.

* `RoundDown`: this matches the rounding semantics of `TimeSpans.index_from_time(sample_rate, span)`, namely both endpoints of the span are rounded downwards to the nearest sample, and the right-endpoint of the `span` is excluded.
* `RoundInward`: this constructs the largest span (whose endpoints are valid indices) that is entirely contained within `span`.
* `RoundConstantSamples`: this constructs a span such that the number of samples is a function only of the duration of the input `samples` and the sample rate (but not the particular `start` or `stop` of the samples). This is useful for splitting a `samples` into equal parts.

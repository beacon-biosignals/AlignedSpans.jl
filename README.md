# AlignedSpans

[![Build Status](https://github.com/beacon-biosignals/AlignedSpans.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/beacon-biosignals/AlignedSpans.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![codecov](https://codecov.io/gh/beacon-biosignals/AlignedSpans.jl/branch/main/graph/badge.svg?token=2hUEWxFtim)](https://codecov.io/gh/beacon-biosignals/AlignedSpans.jl)

## Usage

The main object is `AlignedSpan` which takes in a `sample_rate`, a `span`, and a description of how to round time endpoints to indices. This constructs an `AlignedSpan` which supports Onda indexing. Internally, an `AlignedSpan` stores indices, not times, and any rounding happens when it is created instead of when indexing into `samples`.

Rounding options:

* `EndpointRoundingMode`: consists of a `RoundingMode` for the `start` and `stop` of the span.
    * The alias `RoundInward = EndpointRoundingMode(RoundUp, RoundDown)`, for example, constructs the largest span (whose endpoints are valid indices) that is entirely contained within `span`.
    * The alias `RoundEndsDown = EndpointRoundingMode(RoundDown, RoundDown)` matches the rounding semantics of `TimeSpans.index_from_time(sample_rate, span)`.
* `ConstantSamplesRoundingMode` consists of a `RoundingMode` for the `start` alone. The `stop` is determined from the `start` plus a number of samples which is a function only of the sampling rate and the `duration` of the span.

Also provides a helper `consecutive_subspans` to partition an `AlignedSpan` into smaller consecutive `AlignedSpans` of equal size (except possibly the last one).


See the documentation for more.

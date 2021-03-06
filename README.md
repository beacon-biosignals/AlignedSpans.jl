# AlignedSpans

[![Build Status](https://github.com/beacon-biosignals/AlignedSpans.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/beacon-biosignals/AlignedSpans.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![codecov](https://codecov.io/gh/beacon-biosignals/AlignedSpans.jl/branch/main/graph/badge.svg?token=2hUEWxFtim)](https://codecov.io/gh/beacon-biosignals/AlignedSpans.jl)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://beacon-biosignals.github.io/AlignedSpans.jl/stable/)
[![](https://img.shields.io/badge/docs-dev-blue.svg)](https://beacon-biosignals.github.io/AlignedSpans.jl/dev/)

## Usage

AlignedSpans converts between continuous time spans and discrete sample indices. Time spans describe a time intervals down to a resolution of 1 ns and are usually provided by TimeSpans.jl. Discrete sample indices are associated to signals sampled at some finite rate (e.g. Onda.jl's `Samples` objects). 

AlignedSpans provides an `AlignedSpan` type which holds integer indices along with a sample rate. An `AlignedSpan` is thus an discrete index, but since it holds the sample rate, it can be used to represent a continuous time span as well, and it supports the TimeSpans.jl interface.

See the [documentation](https://beacon-biosignals.github.io/AlignedSpans.jl/) for more.

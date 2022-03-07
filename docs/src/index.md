```@meta
CurrentModule = AlignedSpans
```

# AlignedSpans

See [API documentation](@ref) for how to construct AlignedSpans, along with some utilities, or below for some examples and motivation.

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

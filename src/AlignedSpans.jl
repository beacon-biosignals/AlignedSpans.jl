module AlignedSpans

using Dates, Intervals, Onda
using TimeSpans: TimeSpans, start, stop, format_duration
using StructTypes, ArrowTypes

export SpanRoundingMode, RoundInward, RoundSpanDown, ConstantSamplesRoundingMode, RoundFullyContainedSampleSpans
export AlignedSpan, consecutive_subspans, n_samples, consecutive_overlapping_subspans

# Make our own method so we can add methods for Intervals without piracy
duration(span) = TimeSpans.duration(span)

#####
##### Types and rounding modes
#####

"""
    SpanRoundingMode(start::RoundingMode, stop::RoundingMode)

Creates a rounding object for [`AlignedSpan`](@ref) to indicate how the `AlignedSpan`'s
endpoints should be determined from a given `span`s endpoints'.
"""
struct SpanRoundingMode
    start::RoundingMode
    stop::RoundingMode
end

"""
    ConstantSamplesRoundingMode(start::RoundingMode)

Creates a rounding object for [`AlignedSpan`](@ref) to indicate the `AlignedSpan`
should be constructed by the `start` and `duration` of the `span`, without regard to its `stop`.

If two `span`s have the same duration, then the resulting `AlignedSpan`'s will have the same
number of samples when constructed with this rounding mode.

See also [`AlignedSpan(sample_rate, span, mode::ConstantSamplesRoundingMode)`](@ref).
"""
struct ConstantSamplesRoundingMode
    start::RoundingMode
end

"""
    RoundInward = SpanRoundingMode(RoundUp, RoundDown)

This is a rounding mode where both ends of the continuous time interval are rounded "inwards"
to construct the largest span of indices such that all samples, as instants of time, occur within the span.

## Example

Consider a signal with sample rate 1 Hz.

```
Index       1   2   3   4   5
Time (s)    0   1   2   3   4
```

Now, consider the time span 1.5s (inclusive) to 2.5s (exclusive).
Using brackets to highlight this span:

```
Index       1   2     3     4   5
Time (s)    0   1  [  2  )  3   4
```

In code, this span is described by

```jldoctest RoundInward
julia> using AlignedSpans, Dates, TimeSpans

julia> ts = TimeSpan(Millisecond(1500), Millisecond(2500))
TimeSpan(00:00:01.500000000, 00:00:02.500000000)
```

The only sample within the span is at index 3. And indeed,
```jldoctest RoundInward
julia> aligned = AlignedSpan(1, ts, RoundInward)
AlignedSpan(1.0, 3, 3)

julia> AlignedSpans.indices(aligned)
3:3
```
gives an `AlignedSpan` with indices `3:3`.
"""
const RoundInward = SpanRoundingMode(RoundUp, RoundDown)

"""
    RoundSpanDown = SpanRoundingMode(RoundDown, RoundDown)

This is a rounding mode where *both* ends of the continuous time interval are rounded
downwards.

## Example

Consider a signal with sample rate 1 Hz.

```
Index       1   2   3   4   5
Time (s)    0   1   2   3   4
```

Now, consider the time span 1.5s (inclusive) to 2.5s (exclusive).
Using brackets to highlight this span:

```
Index       1   2     3     4   5
Time (s)    0   1  [  2  )  3   4
```

In code, this span is described by

```jldoctest RoundSpanDown
julia> using AlignedSpans, Dates, TimeSpans

julia> ts = TimeSpan(Millisecond(1500), Millisecond(2500))
TimeSpan(00:00:01.500000000, 00:00:02.500000000)
```

If we round both ends of the interval down to the nearest sample,
the start of the interval becomes 1s, and the stop of the interval
becomes 2s. Thus, the associated samples are at indices `2:3`. And indeed,
```jldoctest RoundSpanDown
julia> aligned = AlignedSpan(1, ts, RoundSpanDown)
AlignedSpan(1.0, 2, 3)

julia> AlignedSpans.indices(aligned)
2:3
```
gives an `AlignedSpan` with indices `2:3`.
"""
const RoundSpanDown = SpanRoundingMode(RoundDown, RoundDown)

struct RoundingModeFullyContainedSampleSpans end
function Base.getproperty(inw::RoundingModeFullyContainedSampleSpans, property::Symbol)
    property === :start && return RoundUp
    property === :stop && return inw
    # throw the correct error
    getfield(inw, property)
end

"""
    RoundFullyContainedSampleSpans

This is a special rounding mode which differs from the other rounding modes by associating each sample
with a _span_ (from the instant the sample occurs until just before the next sample occurs), and rounding
inwards to the "sample spans" that are fully contained in the input span.

This is in some sense a stricter form of inward rounding than provided by [`RoundInward`](@ref).

## Example

Consider a signal with sample rate 1 Hz.

```
Index       1   2   3   4   5
Time (s)    0   1   2   3   4
```

Normally, we consider each sample to occur at an instant of time. For `RoundFullyContainedSampleSpans`,
we consider the span between a sample occurring and the next sample. (This usually does not make sense for digital sensors,
but can make sense for things like hypnograms in which a sample summarizes some region of time).

Thus, to each index (each sample), we associate a 1s closed-open span of time:
```
Index        1     2     3     4     5
Span (s)    [0   )[1   )[2   )[3   )[4    )
```
The span durations are `1/sample_rate`, which is 1s in this example.

Now, consider the input time span 1.5s (inclusive) to 3.5s (exclusive).
Using brackets to highlight this span:

```
Index        1     2     3     4     5
Span (s)    [0   )[1   )[2   )[3   )[4    )
Time (s)     0     1  [  2     3  )  4
```

This input span contains only one sample-span, namely `[2s, 3s)`. The span from `[1s, 2)` is not fully contained,
nor is the span from `[3s, 4s)`.

Thus, in this scenario, `RoundFullyContainedSampleSpans` would give a single sample, that at index 3, associated to `[2s, 3s)`.

In code, this span is described by

```jldoctest RoundFullyContainedSampleSpans
julia> using AlignedSpans, Dates, TimeSpans

julia> ts = TimeSpan(Millisecond(1500), Millisecond(3500))
TimeSpan(00:00:01.500000000, 00:00:03.500000000)

julia> aligned = AlignedSpan(1, ts, RoundFullyContainedSampleSpans)
AlignedSpan(1.0, 3, 3)

julia> AlignedSpans.indices(aligned)
3:3
```
"""
const RoundFullyContainedSampleSpans = RoundingModeFullyContainedSampleSpans()

"""
    AlignedSpan(sample_rate::Number, first_index::Int, last_index::Int)

Construct an `AlignedSpan` directly from a `sample_rate` and indices.
"""
struct AlignedSpan
    sample_rate::Float64
    first_index::Int64
    last_index::Int64
    function AlignedSpan(sample_rate::Number, first_index::Int, last_index::Int)
        if last_index < first_index
            throw(ArgumentError("Cannot create `AlignedSpan` with right-endpoint (`last_index=$(last_index)`) strictly smaller than left endpoint (`first_index=$(first_index)`)"))
        end
        return new(convert(Float64, sample_rate), first_index, last_index)
    end
    function AlignedSpan(sample_rate::Number, index_range::UnitRange{Int})
        return AlignedSpan(sample_rate, first(index_range), last(index_range))
    end
end

#####
##### Continuous -> discrete interface
#####

# Methods for these API functions are provided in `interop.jl`.

"""
    AlignedSpans.start_index_from_time(sample_rate, span, rounding_mode)

Returns the index of a sample object obtained by rounding the start of `span` according to `rounding_mode`.

See also [`AlignedSpan(sample_rate, span, mode::SpanRoundingMode)`](@ref) and
[`AlignedSpan(sample_rate, span, mode::ConstantSamplesRoundingMode)`](@ref).
"""
function start_index_from_time end

"""
    AlignedSpans.stop_index_from_time(sample_rate, span, rounding_mode)

Returns the index of a sample object obtained by rounding the stop of `span` according to `rounding_mode`.

See also [`AlignedSpan(sample_rate, span, mode::SpanRoundingMode)`](@ref).
"""
function stop_index_from_time end

#####
##### Continuous -> discrete conversions
#####

"""
    AlignedSpan(sample_rate, span, mode::Union{SpanRoundingMode, RoundingModeFullyContainedSampleSpans})

Creates an `AlignedSpan` by rounding the left endpoint according to `mode.start`,
and the right endpoint by `mode.stop`.

If `mode.start==RoundUp`, then the left index of the resulting span is guaranteed
to be inside `span`. This is accomplished by checking if the left endpoint of the span
is exclusive, and if so, incrementing the index after rounding when necessary.

Likewise, if `mode.stop==RoundDown`, then the right index of the resulting span is guaranteed
to be inside `span`. This is accomplished by checking if the right endpoint of the span
is exclusive, and if so, decrementing the index after rounding when necessary.

Note: `span` may be of any type which which provides methods for `AlignedSpans.start_index_from_time` and `AlignedSpans.stop_index_from_time`.

!!! warning
    If the input `span` is not sample-aligned, meaning the `start` and `stop` of the input span are not exact multiples of the sample rate, the results can be non-intuitive at first. Each underlying sample is considered to occur at some instant in time (not, e.g. over a span of duration of `1/sample_rate`), and the rounding is relative to the samples themselves.

    So for example:

    ```jldoctest
    julia> using TimeSpans, AlignedSpans, Dates

    julia> sample_rate = 1/30
    0.03333333333333333

    julia> input = TimeSpan(0, Second(30) + Nanosecond(1))
    TimeSpan(00:00:00.000000000, 00:00:30.000000001)

    julia> aligned = AlignedSpan(sample_rate, input, RoundInward) # or RoundSpanDown
    AlignedSpan(0.03333333333333333, 1, 2)

    julia> TimeSpan(aligned)
    TimeSpan(00:00:00.000000000, 00:01:00.000000000)

    ```

    Even though we have specified `RoundInward` or `RoundSpanDown`, both of which round the right-endpoint down, the resulting sample-aligned `TimeSpan(aligned)` is `TimeSpan(0, Second(60))`.

    How can this be? Clearly `Second(60) > Second(30) + Nanosecond(1)`, so what is going on?

    To understand this, note that at 1/30Hz, the samples occur at 00:00, 00:30, 00:60, and so forth. The original input span
    includes _two_ samples, the one at 00:00 and the one at 00:30. Rounding inward to include only samples that occur within the span means including both samples.

    When converting back to TimeSpans, AlignedSpans canonicalizes `AlignedSpan(1/30, 1, 2)` as `TimeSpan(0, Second(60))`,
    representing these two samples as the time from the first sample until just before the not-included sample-3 (which occurs at `Second(60)`), using that `TimeSpan`'s exclude their right endpoint.

    AlignedSpans could make a different choice to e.g. canonicalize samples to only add an additional nanosecond,
    but that has its own issue (e.g. `TimeSpan(AlignedSpan(sample_rate, 1, 2))` and `TimeSpan(AlignedSpan(sample_rate, 3, 4))` would not be consecutive).
    
"""
function AlignedSpan(sample_rate, span, mode::Union{SpanRoundingMode, RoundingModeFullyContainedSampleSpans})
    first_index = start_index_from_time(sample_rate, span, mode.start)
    last_index = stop_index_from_time(sample_rate, span, mode.stop)
    if last_index < first_index
        throw(ArgumentError("No samples lie within `span`"))
    end
    return AlignedSpan(sample_rate, first_index, last_index)
end

"""
    AlignedSpan(sample_rate, span, mode::ConstantSamplesRoundingMode)

Creates an `AlignedSpan` whose left endpoint is rounded according to `mode.start`,
and whose right endpoint is determined so by the left endpoint and the number of samples,
given by `AlignedSpans.n_samples(sample_rate, duration(span))`.

Interface: `span` may be of any type which which provides a method for [`AlignedSpans.start_index_from_time`](@ref) and `TimeSpans.duration`.

## More detailed information

This is designed so that if `AlignedSpan(sample_rate, span, mode::ConstantSamplesRoundingMode)` is applied to multiple `span`s, with the same `sample_rate`, and the same durations, then the resulting `AlignedSpan`'s will have the same number of samples.

For this reason, we ask for `TimeSpans.duration(span)` to be defined, rather than a `n_samples(span)` function: the idea is that we want to only using the duration and the starting time, rather than the *actual* number of samples in this particular `span`.

In contrast, `AlignedSpan(sample_rate, span, RoundInward)` provides an `AlignedSpan` which includes only (and exactly) the samples which occur within `span`.

If one wants to create a collection of consecutive, non-overlapping, `AlignedSpans` each with the same number of samples, then use [`consecutive_subspans`](@ref) instead.
"""
function AlignedSpan(sample_rate, span, mode::ConstantSamplesRoundingMode)
    first_index = start_index_from_time(sample_rate, span, mode.start)
    n = n_samples(sample_rate, duration(span))
    last_index = first_index + n - 1
    return AlignedSpan(sample_rate, first_index, last_index)
end

include("time_index_conversions.jl")
include("interop.jl")
include("utilities.jl")

end

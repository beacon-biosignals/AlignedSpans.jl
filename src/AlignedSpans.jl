module AlignedSpans

using Dates, Intervals, Onda
using TimeSpans: TimeSpans, start, stop, format_duration
using StructTypes, ArrowTypes

export EndpointRoundingMode, RoundInward, RoundEndsDown, ConstantSamplesRoundingMode
export AlignedSpan, consecutive_subspans, n_samples

struct EndpointRoundingMode
    start::RoundingMode
    stop::RoundingMode
end

struct ConstantSamplesRoundingMode
    start::RoundingMode
end

const RoundInward = EndpointRoundingMode(RoundUp, RoundDown)
const RoundEndsDown = EndpointRoundingMode(RoundDown, RoundDown)

struct AlignedSpan
    sample_rate::Float64
    first_index::Int
    last_index::Int
    function AlignedSpan(sample_rate::Number, first_index::Int, last_index::Int)
        if last_index < first_index
            throw(ArgumentError("Cannot create `AlignedSpan` with right-endpoint (`last_index=$last_index`) strictly smaller than left endpoint (`first_index=$first_index`)"))
        end
        return new(convert(Float64, sample_rate), first_index, last_index)
    end
end

start_time(span::AlignedSpan) = time_from_index(span.sample_rate, span.first_index)
stop_time(span::AlignedSpan) = time_from_index(span.sample_rate, span.last_index) # not exclusive!

function Base.show(io::IO, w::AlignedSpan)
    start_string = TimeSpans.format_duration(start_time(w))
    stop_string = TimeSpans.format_duration(stop_time(w))
    return print(io, "AlignedSpan(", start_string, ", ", stop_string, ')')
end

"""
    start_index_from_time(sample_rate, span, rounding_mode)


Returns the index of a sample object obtained by rounding the start of `span` according to `rounding_mode`.
"""
function start_index_from_time end

"""
    stop_index_from_time(sample_rate, span, rounding_mode)

Returns the index of a sample object obtained by rounding the stop of `span` according to `rounding_mode`.
"""
function stop_index_from_time end

"""
    duration(span)

Return the duration of `span`.
"""
function duration end

duration(interval::Interval{<:TimePeriod}) = last(interval) - first(interval)
duration(span) = stop(span) - start(span)
duration(span::AlignedSpan) = stop_time(span) - start_time(span)

"""
    AlignedSpan(sample_rate, span, mode::EndpointRoundingMode)

Creates an `AlignedSpan` by rounding the left endpoint according to `mode.start`,
and the right endpoint by `mode.stop`.

If `mode.start==RoundUp`, then the left index of the resulting span is guaranteed
to be inside `span`. This is accomplished by checking if the left endpoint of the span
is exclusive, and if so, incrementing the index after rounding when necessary.

Likewise, if `mode.start==RoundDown`, then the right index of the resulting span is guaranteed
to be inside `span`. This is accomplished by checking if the right endpoint of the span
is exclusive, and if so, decrementing the index after rounding when necessary.

Note: `span` may be of any type which which provides methods for `AlignedSpans.start_index_from_time` and `AlignedSpans.stop_index_from_time`.
"""
function AlignedSpan(sample_rate, span, mode::EndpointRoundingMode)
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
and whose right endpoint is determined so by the left endpoint and the total number of samples,
given by `AlignedSpans.n_samples(sample_rate, duration(span))`.

Note: `span` may be of any type which which provides a method for `AlignedSpans.start_index_from_time` and `AlignedSpans.duration`.
"""
function AlignedSpan(sample_rate, span, mode::ConstantSamplesRoundingMode)
    first_index = start_index_from_time(sample_rate, span, mode.start)
    n = n_samples(sample_rate, duration(span))
    last_index = first_index + (n - 1)
    return AlignedSpan(sample_rate, first_index, last_index)
end

include("time_index_conversions.jl")
include("interop.jl")
include("utilities.jl")

end

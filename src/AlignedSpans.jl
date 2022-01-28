module AlignedSpans

using TimeSpans, Dates

export EndpointRoundingMode, RoundInward, RoundEndsDown, ConstantSamplesRoundingMode
export AlignedSpan, consecutive_subspans

struct EndpointRoundingMode
    start::RoundingMode
    stop::RoundingMode
end

struct ConstantSamplesRoundingMode
    start::RoundingMode
end

const RoundInward = EndpointRoundingMode(RoundUp, RoundDown)
const RoundEndsDown = EndpointRoundingMode(RoundDown, RoundDown)

is_start_exclusive(::TimeSpan) = false
is_stop_exclusive(::TimeSpan) = true

# using Intervals
# is_start_exclusive(::Interval{T, L, R}) where {T,L,R} = L == Open
# is_stop_exclusive(::Interval{T, L, R}) where {T,L,R} = R == Open

struct AlignedSpan
    sample_rate::Float64
    i::Int
    j::Int
    function AlignedSpan(sample_rate, i, j)
        if j < i
            throw(ArgumentError("Cannot create `AlignedSpan` with right-endpoint (`j=$j`) strictly smaller than left endpoint (`i=$i`)"))
        end
        return new(sample_rate, i, j)
    end
end

function Base.show(io::IO, w::AlignedSpan)
    start_string = TimeSpans.format_duration(start(w))
    stop_string = TimeSpans.format_duration(stop(w))
    return print(io, "AlignedSpan(", start_string, ", ", stop_string, ')')
end

TimeSpans.istimespan(::AlignedSpan) = true
TimeSpans.start(span::AlignedSpan) = TimeSpans.time_from_index(span.sample_rate, span.i)

function TimeSpans.stop(span::AlignedSpan)
     # TimeSpans has a exclusive stop, so we want to be just past our (inclusive) stopping index
    return TimeSpans.time_from_index(span.sample_rate, span.j) + Nanosecond(1)
end

function TimeSpans.index_from_time(sample_rate, span::AlignedSpan)
    if sample_rate != span.sample_rate
        throw(ArgumentError("The `sample_rate` provided, $(sample_rate) does not match the `span`'s sample rate, $(span.sample_rate)."))
    end
    return (span.i):(span.j)
end

# Interop with `StepRange`
function Base.StepRange(span::AlignedSpan)
    # the rounding here is not ideal
    t = Nanosecond(round(Int, TimeSpans.nanoseconds_per_sample(span.sample_rate)))
    return (span.i * t):t:(span.j * t)
end

function AlignedSpan(r::StepRange{T,S}) where {T<:Period,S<:Period}
    sample_rate = TimeSpans.NS_IN_SEC / Dates.value(convert(Nanosecond, step(r)))
    i = first(r) / step(r)
    j = last(r) / step(r)
    return AlignedSpan(sample_rate, Int(i), Int(j))
end

# Helper to get the index and the rounding error in units of time
function index_and_error_from_time(sample_rate, sample_time::Period, mode::RoundingMode)
    time_in_nanoseconds = Dates.value(convert(Nanosecond, sample_time))
    time_in_nanoseconds >= 0 ||
        throw(ArgumentError("`sample_time` must be >= 0 nanoseconds"))
    time_in_seconds = time_in_nanoseconds / TimeSpans.NS_IN_SEC
    floating_index = time_in_seconds * sample_rate + 1
    index = round(Int, floating_index, mode)
    return index, TimeSpans.time_from_index(sample_rate, index) - sample_time
end

n_samples(aligned::AlignedSpan) = aligned.j - aligned.i + 1

function n_samples(sample_rate, duration::Period)
    duration_in_nanoseconds = Dates.value(convert(Nanosecond, duration))
    duration_in_nanoseconds >= 0 ||
        throw(ArgumentError("`duration` must be >= 0 nanoseconds"))
    duration_in_seconds = duration_in_nanoseconds / TimeSpans.NS_IN_SEC
    n_indices = duration_in_seconds * sample_rate
    return floor(Int, n_indices)
end

function start_index_from_time(sample_rate, span, mode)
    i, error = index_and_error_from_time(sample_rate, start(span), mode)
    if is_start_exclusive(span) && mode == RoundUp && iszero(error)
        i += 1
    end
    return i
end

function stop_index_from_time(sample_rate, span, mode)
    j, error = index_and_error_from_time(sample_rate, stop(span), mode)
    if is_stop_exclusive(span) && mode == RoundDown && iszero(error)
        j -= 1
    end
    return j
end

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
"""
function AlignedSpan(sample_rate, span, mode::EndpointRoundingMode)
    i = start_index_from_time(sample_rate, span, mode.start)
    j = stop_index_from_time(sample_rate, span, mode.stop)
    if j < i
        throw(ArgumentError("No samples lie within `span`"))
    end
    return AlignedSpan(sample_rate, i, j)
end

"""
    AlignedSpan(sample_rate, span, mode::ConstantSamplesRoundingMode)

Creates an `AlignedSpan` whose left endpoint is rounded according to `mode.start`,
and whose right endpoint is determined so by the left endpoint and the total number of samples,
given by `AlignedSpans.n_samples(sample_rate, duration(span))`.
"""
function AlignedSpan(sample_rate, span, mode::ConstantSamplesRoundingMode)
    i = start_index_from_time(sample_rate, span, mode.start)
    n = n_samples(sample_rate, duration(span))
    j = i + (n - 1)
    return AlignedSpan(sample_rate, i, j)
end

"""
    consecutive_subspans(span::AlignedSpan, duration::Period)

Creates an iterator of `AlignedSpan` such that each `AlignedSpan` has consecutive indices
which cover all of the original `span`'s indices. In particular,

* Each span has `n = n_samples(span.sample_rate, duration)` samples, except possibly
the last one, which may have fewer.
* The number of subspans is given by `cld(n_samples(span), n)`
* The number of samples in the last subspan is `r = rem(n_samples(span), n)` unless `r=0`, in which
  case the the last subspan has the same number of samples as the rest, namely `n`.
"""
function consecutive_subspans(span::AlignedSpan, duration::Period)
    n = n_samples(span.sample_rate, duration)
    return consecutive_subspans(span::AlignedSpan, n)
end

function consecutive_subspans(span::AlignedSpan, n::Int)
    i = span.i
    j = span.j
    rate = span.sample_rate
    return (AlignedSpan(rate, first(I), last(I)) for I in Iterators.partition(i:j, n))
end

end

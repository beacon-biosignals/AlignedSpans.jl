module AlignedSpans

using TimeSpans, Dates

export RoundInward, RoundEndsDown, ConstantSamplesRoundingMode
export AlignedSpan

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
            throw(ArgumentError("TODO"))
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
    return TimeSpans.time_from_index(span.sample_rate, span.j) + Nanosecond(1)
end # exclusive stop

function TimeSpans.index_from_time(sample_rate, span::AlignedSpan)
    if sample_rate != span.sample_rate
        throw(ArgumentError("TODO"))
    end
    return (span.i):(span.j)
end

# Interop with `StepRange`
function Base.StepRange(span::AlignedSpan)
    t = Nanosecond(round(Int, TimeSpans.nanoseconds_per_sample(span.sample_rate)))
    return (span.i * t):t:(span.j * t)
end

function AlignedSpan(r::StepRange{T,S}) where {T<:Period,S<:Period}
    inv_sample_rate_in_ns = Dates.value(convert(Nanosecond, step(r)))
    sample_rate = TimeSpans.NS_IN_SEC * inv(inv_sample_rate_in_ns)
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

function round_endpoint(sample_rate, sample_time, mode::RoundingMode{:Down}, exclusive)
    index, error = index_and_error_from_time(sample_rate, sample_time, mode)
    # round down means if we must exclude the point itself by moving to the left
    if exclusive && iszero(error)
        index -= 1
    end
    return index
end

function round_endpoint(sample_rate, sample_time, mode::RoundingMode{:Up}, exclusive)
    index, error = index_and_error_from_time(sample_rate, sample_time, mode)
    # round up means if we must exclude the point itself by moving to the right
    if exclusive && iszero(error)
        index += 1
    end
    return index
end

# Don't care about exclusivity for these modes
const IGNORES_EXCLUSIVITY = Union{RoundingMode{:Nearest},
                                  RoundingMode{:RoundNearestTiesAway},
                                  RoundingMode{:RoundNearestTiesUp},
                                  RoundingMode{:RoundNearestTiesAway}}

function round_endpoint(sample_rate, sample_time, mode::IGNORES_EXCLUSIVITY, exclusive)
    return first(index_and_error_from_time(sample_rate, sample_time, mode))
end

function n_samples(sample_rate, duration::Period)
    i, _ = index_and_error_from_time(sample_rate, duration, RoundDown)
    return i - 1
end

# Returns a subset of the original span, corresponding to the samples it contains
function AlignedSpan(sample_rate, span, mode::EndpointRoundingMode)
    i = round_endpoint(sample_rate, start(span), mode.start, is_start_exclusive(span))
    j = round_endpoint(sample_rate, stop(span), mode.stop, is_stop_exclusive(span))
    if j < i
        throw(ArgumentError("No samples lie within `span`"))
    end
    return AlignedSpan(sample_rate, i, j)
end

# Returns a `span` whose left endpoint is rounded to the nearest sample,
# whose length is always the same number of samples (depending only on the duration, not the position, of the span)
function AlignedSpan(sample_rate, span, mode::ConstantSamplesRoundingMode)
    i, _ = index_and_error_from_time(sample_rate, start(span), mode.start)
    n = n_samples(sample_rate, duration(span))
    j = i + (n - 1)
    return AlignedSpan(sample_rate, i, j)
end

end

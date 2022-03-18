#####
##### Intervals
#####

# Interval -> AlignedSpan
is_start_exclusive(::Interval{T,L,R}) where {T,L,R} = L == Open
is_stop_exclusive(::Interval{T,L,R}) where {T,L,R} = R == Open

function start_index_from_time(sample_rate, interval::Interval,
                               mode::Union{RoundingMode{:Up},RoundingMode{:Down}})
    first_index, error = index_and_error_from_time(sample_rate, first(interval), mode)
    if is_start_exclusive(interval) && mode == RoundUp && iszero(error)
        first_index += 1
    end
    return first_index
end

function stop_index_from_time(sample_rate, interval::Interval,
                              mode::Union{RoundingMode{:Up},RoundingMode{:Down}})
    last_index, error = index_and_error_from_time(sample_rate, last(interval), mode)
    if is_stop_exclusive(interval) && mode == RoundDown && iszero(error)
        last_index -= 1
    end
    return last_index
end

#####
##### Onda
#####

function Onda.column_arguments(samples::Samples, span::AlignedSpan)
    span.sample_rate == samples.info.sample_rate ||
        throw(ArgumentError("Sample rate of `samples` ($(samples.info.sample_rate)) does not match sample rate of `AlignedSpan` argument ($(span.sample_rate))."))
    return indices(span)
end

#####
##### TimeSpans
#####

# We do not support constructing a TimeSpan from an AlignedSpan,
# because we don't have same endpoint exclusivity.
TimeSpans.istimespan(::AlignedSpan) = false

# TimeSpan -> AlignedSpan is supported by passing to Intervals
to_interval(span) = Interval{Nanosecond,Closed,Open}(start(span), stop(span))
to_interval(span::Interval) = span
to_interval(span::AlignedSpan) = Interval(span)

function start_index_from_time(sample_rate, span, mode)
    return start_index_from_time(sample_rate, to_interval(span), mode)
end

function stop_index_from_time(sample_rate, span, mode)
    return stop_index_from_time(sample_rate, to_interval(span), mode)
end

#####
##### StructTypes
#####

StructTypes.StructType(::Type{AlignedSpan}) = StructTypes.Struct()

#####
##### ArrowTypes
#####

const ARROW_ALIGNED_SPAN = Symbol("AlignedSpans.AlignedSpan")
ArrowTypes.arrowname(::Type{AlignedSpan}) = ARROW_ALIGNED_SPAN
ArrowTypes.JuliaType(::Val{ARROW_ALIGNED_SPAN}) = AlignedSpan

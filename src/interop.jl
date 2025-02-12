#####
##### Intervals -> AlignedSpan
#####

is_start_exclusive(::Interval{T,L,R}) where {T,L,R} = L == Open
is_stop_exclusive(::Interval{T,L,R}) where {T,L,R} = R == Open

# Interface methods:
duration(interval::Interval{<:TimePeriod}) = last(interval) - first(interval)

function start_index_from_time(sample_rate, interval::Interval,
                               mode::Union{RoundingMode{:Up},RoundingMode{:Down}})
    first_index, error = index_and_error_from_time(sample_rate, first(interval), mode)
    if is_start_exclusive(interval) && mode == RoundUp && iszero(error)
        first_index += 1
    end

    if mode == RoundUp
        t = time_from_index(sample_rate, first_index)
        # this should *always* be true by construction, and we promise it in the docstring.
        # let's add an assert to verify.
        @assert t >= first(interval)
    end
    return first_index
end

function stop_index_from_time(sample_rate, interval::Interval,
                              mode::Union{RoundingMode{:Up},RoundingMode{:Down}})
    last_index, error = index_and_error_from_time(sample_rate, last(interval), mode)
    if is_stop_exclusive(interval) && mode == RoundDown && iszero(error)
        last_index -= 1
    end

    if mode == RoundDown
        t = time_from_index(sample_rate, last_index)
        # this should *always* be true by construction, and we promise it in the docstring.
        # let's add an assert to verify.
        @assert t <= last(interval)
    end
    return last_index
end

function stop_index_from_time(sample_rate, interval::Interval,
                              ::RoundingModeFullyContainedSampleSpans)
    # here we are in `RoundingModeFullyContainedSampleSpans` which means we treat each sample
    # as a closed-open span starting from each sample to just before the next sample,
    # and we are trying to round down to the last fully-enclosed sample span
    last_index, _ = index_and_error_from_time(sample_rate, last(interval), RoundDown)

    # `time_from_index(sample_rate, last_index + 1)` gives us the _start_ of the next sample
    # we subtract 1 ns to get the (inclusive) _end_ of the span associated to this sample
    end_of_span_time = time_from_index(sample_rate, last_index + 1) - Nanosecond(1)
    # if this end isn't fully included in the interval, then we need to go back one
    if !(end_of_span_time in interval)
        @debug "Decrementing last index to fully fit within span"
        last_index -= 1
    end

    # We should never need to decrement twice, but we will assert this
    end_of_span_time = time_from_index(sample_rate, last_index + 1) - Nanosecond(1)
    @assert end_of_span_time in interval
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
##### TimeSpans <--> AlignedSpan
#####

TimeSpans.istimespan(::AlignedSpan) = true
TimeSpans.start(span::AlignedSpan) = time_from_index(span.sample_rate, span.first_index)
TimeSpans.stop(span::AlignedSpan) = time_from_index(span.sample_rate, span.last_index + 1)

# TimeSpan -> AlignedSpan is supported by passing to Intervals
to_interval(span) = Interval{Nanosecond,Closed,Open}(start(span), stop(span))
to_interval(span::Interval) = span

# Interface methods:

function start_index_from_time(sample_rate, span, mode)
    return start_index_from_time(sample_rate, to_interval(span), mode)
end

function stop_index_from_time(sample_rate, span, mode)
    return stop_index_from_time(sample_rate, to_interval(span), mode)
end

#####
##### Serialization
#####

StructTypes.StructType(::Type{AlignedSpan}) = StructTypes.Struct()

const ARROW_ALIGNED_SPAN = Symbol("AlignedSpans.AlignedSpan")
ArrowTypes.arrowname(::Type{AlignedSpan}) = ARROW_ALIGNED_SPAN
ArrowTypes.JuliaType(::Val{ARROW_ALIGNED_SPAN}) = AlignedSpan

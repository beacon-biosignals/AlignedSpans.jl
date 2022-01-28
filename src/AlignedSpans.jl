module AlignedSpans

using TimeSpans, Dates

export RoundInward, RoundConstantSamples
export AlignedSpan

const RoundInward = RoundingMode{:Inward}()
const RoundConstantSamples = RoundingMode{:ConstantSamples}()

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
TimeSpans.stop(span::AlignedSpan) = TimeSpans.time_from_index(span.sample_rate, span.j) + Nanosecond(1) # exclusive stop

function TimeSpans.index_from_time(sample_rate, span::AlignedSpan)
    if sample_rate != span.sample_rate
        throw(ArgumentError("TODO"))
    end
    return span.i : span.j
end

function float_index_from_time(sample_rate, sample_time)
    time_in_nanoseconds = convert(Nanosecond, sample_time).value
    time_in_nanoseconds >= 0 ||
        throw(ArgumentError("`sample_time` must be >= 0 nanoseconds"))
    time_in_seconds = time_in_nanoseconds / TimeSpans.NS_IN_SEC
    index = time_in_seconds * sample_rate + 1
    return index
end

# Helper to get the index and the rounding error in units of time
function index_and_error_from_time(sample_rate, sample_time::Period, mode::RoundingMode)
    f = float_index_from_time(sample_rate, sample_time)
    index = round(Int, f, mode)
    return index, TimeSpans.time_from_index(sample_rate, index) - sample_time
end

function n_samples(sample_rate, duration::Period)
    i, _ = index_and_error_from_time(sample_rate, duration, RoundDown)
    return i - 1
end

# Returns a subset of the original span, corresponding to the samples it contains
function AlignedSpan(sample_rate, span, ::RoundingMode{:Inward})
    i, _ = index_and_error_from_time(sample_rate, start(span), RoundUp)
    j, error = index_and_error_from_time(sample_rate, stop(span), RoundDown)
    if error == Nanosecond(0)
        # We must exclude the right endpoint
        j -= 1
    end
    if j < i
        throw(ArgumentError("No samples lie within `span`"))
    end
    return AlignedSpan(sample_rate, i, j)
end


# Returns a `span` whose left endpoint is rounded down to the nearest sample,
# whose length is always the same number of samples (depending only on the duration, not the position, of the span)
function AlignedSpan(sample_rate, span, ::RoundingMode{:ConstantSamples})
    i, _ = index_and_error_from_time(sample_rate, start(span), RoundDown)
    n = n_samples(sample_rate, duration(span))
    j = i + (n-1)
    return AlignedSpan(sample_rate, i, j)
end

# Round both endpoints down, excluding the right endpoint.
# Matches the indices from `TimeSpans.index_from_time(sample_rate, span)`
function AlignedSpan(sample_rate, span, ::RoundingMode{:Down})
    i, _ = index_and_error_from_time(sample_rate, start(span), RoundDown)
    j, error = index_and_error_from_time(sample_rate, stop(span), RoundDown)
    if i != j && error == Nanosecond(0)
        # We must exclude the right endpoint
        j -= 1
    end
    return AlignedSpan(sample_rate, i, j)
end

# Piracy to fix https://github.com/beacon-biosignals/TimeSpans.jl/issues/28
function TimeSpans.index_from_time(sample_rate, span)
    aligned = AlignedSpan(sample_rate, span, RoundDown)
    return aligned.i : aligned.j
end

end

module IndicesVsSpans

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

# function exact_index_from_time(sample_rate, sample_time::Period)
#     index, error = index_and_error_from_time(sample_rate, sample_time, RoundNearest)

#     # we allow a 1 ns error, since the TimeSpans's constructor will introduce that
#     if !(abs(error) <= Nanosecond(1))
#         # We recompute `f`, but only on the error path
#         f = float_index_from_time(sample_rate, sample_time)
#         throw(InexactError(:exact_index_from_time, Int, f))
#     end

#     return index
# end

# function exact_index_from_time(sample_rate, span::TimeSpan)
#     i = exact_index_from_time(sample_rate, start(span))
#     j = exact_index_from_time(sample_rate, stop(span))
#     if i != j # do we want this
#         j -= 1
#     end
#     return i:j
# end

function n_samples(sample_rate, duration::Period)
    i, _ = index_and_error_from_time(sample_rate, duration, RoundDown)
    return i - 1
end

# Returns a subset of the original span, corresponding to the samples it contains
function AlignedSpan(sample_rate, span::TimeSpan, ::RoundingMode{:Inward})
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
function AlignedSpan(sample_rate, span::TimeSpan, ::RoundingMode{:ConstantSamples})
    i, _ = index_and_error_from_time(sample_rate, start(span), RoundDown)
    n = n_samples(sample_rate, duration(span))
    j = i + (n-1)
    return AlignedSpan(sample_rate, i, j)
end

# Round both endpoints down, excluding the right endpoint.
# Matches the indices from `TimeSpans.index_from_time(sample_rate, span)`
function AlignedSpan(sample_rate, span::TimeSpan, ::RoundingMode{:Down})
    i, _ = index_and_error_from_time(sample_rate, start(span), RoundDown)
    j, error = index_and_error_from_time(sample_rate, stop(span), RoundDown)
    if i != j && error == Nanosecond(0)
        # We must exclude the right endpoint
        j -= 1
    end
    return AlignedSpan(sample_rate, i, j)
end

end

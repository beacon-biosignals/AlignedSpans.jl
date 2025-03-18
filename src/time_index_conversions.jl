##
# Here, we copy a few definitions from TimeSpans.jl in order to not depend on internals
# https://github.com/beacon-biosignals/TimeSpans.jl/blob/e3c999021336e51a08d118e6defb792e38ac1cc7/src/TimeSpans.jl

const NS_IN_SEC_128 = Int128(Dates.value(Nanosecond(Second(1))))  # Number of nanoseconds in one second

# Tweaked from TimeSpans version: https://github.com/beacon-biosignals/AlignedSpans.jl/pull/2#discussion_r829582819
function time_from_index(sample_rate, sample_index)
    return Nanosecond(cld(Int128(sample_index - 1) * NS_IN_SEC_128, sample_rate))
end
#
##

# Helper to get the index and the rounding error in units of time
function index_from_time(sample_rate, sample_time::Union{Period, Dates.CompoundPeriod}, mode::RoundingMode)
    time_in_nanoseconds = Dates.value(convert(Nanosecond, sample_time))
    # +1 since time 0 corresponds to index 1
    index = Int(div(Int128(time_in_nanoseconds) * sample_rate, NS_IN_SEC_128, mode) + 1)
    return index
end

"""
    n_samples(sample_rate, duration::Union{Period, Dates.CompoundPeriod})

Returns the minimal number of samples that can occur in a span of `duration`.
"""
function n_samples(sample_rate, duration::Union{Period,Dates.CompoundPeriod})
    duration_in_nanoseconds = Dates.value(convert(Nanosecond, duration))
    duration_in_nanoseconds >= 0 ||
        throw(ArgumentError("`duration` must be >= 0 nanoseconds"))
    # -1 to remove the +1 in `index_from_time`; we are a difference in indices (a duration)
    return index_from_time(sample_rate, duration, RoundDown) - 1
end

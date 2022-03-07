##
# Here, we copy a few definitions from TimeSpans.jl in order to not depend on internals
# https://github.com/beacon-biosignals/TimeSpans.jl/blob/e3c999021336e51a08d118e6defb792e38ac1cc7/src/TimeSpans.jl

const NS_IN_SEC = Dates.value(Nanosecond(Second(1)))  # Number of nanoseconds in one second

nanoseconds_per_sample(sample_rate) = inv(sample_rate) * NS_IN_SEC

function time_from_index(sample_rate, sample_index)
    sample_index > 0 || throw(ArgumentError("`sample_index` must be > 0"))
    return Nanosecond(ceil(Int, (sample_index - 1) * nanoseconds_per_sample(sample_rate)))
end
#
##

# Helper to get the index and the rounding error in units of time
function index_and_error_from_time(sample_rate, sample_time::Period, mode::RoundingMode)
    time_in_nanoseconds = Dates.value(convert(Nanosecond, sample_time))
    time_in_nanoseconds >= 0 ||
        throw(ArgumentError("`sample_time` must be >= 0 nanoseconds"))
    time_in_seconds = time_in_nanoseconds / NS_IN_SEC
    floating_index = time_in_seconds * sample_rate + 1
    index = round(Int, floating_index, mode)
    return index, time_from_index(sample_rate, index) - sample_time
end

"""
    n_samples(sample_rate, duration::Period)

Returns the minimal number of samples that can occur in a span of duration `duration`.
"""
function n_samples(sample_rate, duration::Period)
    duration_in_nanoseconds = Dates.value(convert(Nanosecond, duration))
    duration_in_nanoseconds >= 0 ||
        throw(ArgumentError("`duration` must be >= 0 nanoseconds"))
    duration_in_seconds = duration_in_nanoseconds / NS_IN_SEC
    n_indices = duration_in_seconds * sample_rate
    return floor(Int, n_indices)
end

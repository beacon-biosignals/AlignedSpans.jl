# https://github.com/beacon-biosignals/TimeSpans.jl/blob/e3c999021336e51a08d118e6defb792e38ac1cc7/src/TimeSpans.jl#L10
const NS_IN_SEC = Dates.value(Nanosecond(Second(1)))  # Number of nanoseconds in one second

# https://github.com/beacon-biosignals/TimeSpans.jl/blob/e3c999021336e51a08d118e6defb792e38ac1cc7/src/TimeSpans.jl#L186
nanoseconds_per_sample(sample_rate) = inv(sample_rate) * NS_IN_SEC

# https://github.com/beacon-biosignals/TimeSpans.jl/blob/e3c999021336e51a08d118e6defb792e38ac1cc7/src/TimeSpans.jl#L271-L274
function time_from_index(sample_rate, sample_index)
    sample_index > 0 || throw(ArgumentError("`sample_index` must be > 0"))
    return Nanosecond(ceil(Int, (sample_index - 1) * nanoseconds_per_sample(sample_rate)))
end

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

is_start_exclusive(::Interval{T, L, R}) where {T,L,R} = L == Open
is_stop_exclusive(::Interval{T, L, R}) where {T,L,R} = R == Open

start_index_from_time(sample_rate, span, mode) = start_index_from_time(sample_rate, to_interval(span), mode)
function start_index_from_time(sample_rate, interval::Interval, mode)
    i, error = index_and_error_from_time(sample_rate, first(interval), mode)
    if is_start_exclusive(interval) && mode == RoundUp && iszero(error)
        i += 1
    end
    return i
end

stop_index_from_time(sample_rate, span, mode) = stop_index_from_time(sample_rate, to_interval(span), mode)
function stop_index_from_time(sample_rate, interval::Interval, mode)
    j, error = index_and_error_from_time(sample_rate, last(interval), mode)
    if is_stop_exclusive(interval) && mode == RoundDown && iszero(error)
        j -= 1
    end
    return j
end

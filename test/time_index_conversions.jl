
function naive_index_from_time(sample_rate, sample_time)
    # This stepping computation is prone to roundoff error, so we'll work in high precision
    sample_time_in_seconds = big(Dates.value(Nanosecond(sample_time))) //
                             big(TimeSpans.NS_IN_SEC)
    # At time 0, we are at index 1
    t = Rational{BigInt}(0 // 1)
    index = 1
    while true
        # Now step forward in time; one index, and time 1/sample_rate
        t += 1 // sample_rate
        index += 1
        if t > sample_time_in_seconds
            # we just passed it, so previous index is the last one before the time of interest
            return index - 1
        end
    end
end

# Modified from
# https://github.com/beacon-biosignals/TimeSpans.jl/blob/e3c999021336e51a08d118e6defb792e38ac1cc7/test/runtests.jl#L116-L126
@testset "index_and_error_from_time" begin
    for rate in (101 // 2, 1001 // 10, 200, 256, 1, 10)
        for sample_time in
            (Nanosecond(12345), Minute(5), Nanosecond(Minute(5)) + Nanosecond(1),
             Nanosecond(1), Nanosecond(10^6), Nanosecond(6970297031))
            # compute with a very simple algorithm
            index = naive_index_from_time(rate, sample_time)
            # Check against our `TimeSpans.index_from_time`:
            @test index ==
                  AlignedSpans.index_and_error_from_time(rate, sample_time, RoundDown)[1]
            # Works even if `rate` is in Float64 precision:
            @test index ==
                  AlignedSpans.index_and_error_from_time(Float64(rate), sample_time,
                                                         RoundDown)[1]
        end
    end
end

# https://github.com/beacon-biosignals/TimeSpans.jl/blob/e3c999021336e51a08d118e6defb792e38ac1cc7/test/runtests.jl#L93-L96
@testset "time_from_index" begin
    @test_throws ArgumentError AlignedSpans.time_from_index(200, 0)
    @test AlignedSpans.time_from_index(100, 1) == Nanosecond(0)
end

@testset "`n_samples`" begin
    times = [Nanosecond(12345), Minute(5), Nanosecond(Minute(5)) + Nanosecond(1),
             Nanosecond(1), Nanosecond(10^6), Nanosecond(6970297031)]
    append!(times, Nanosecond.(Second(1):Second(1):Second(20)))
    sort!(times)

    for rate in (101 // 2, 1001 // 10, 200, 256, 1, 10)
        for i in 1:length(times), j in (i + 1):length(times)
            span = TimeSpan(times[i], times[j])

            if AlignedSpans.duration(span) < Nanosecond(floor(Int, 10^9 * inv(rate)))
                @test n_samples(rate, AlignedSpans.duration(span)) == 0
                continue
            end

            aligned_span = AlignedSpan(rate, span, RoundInward)
            n = n_samples(aligned_span)
            @test n == length(indices(aligned_span))

            # `n` is the *actual* number of samples, given the whole span
            # `n_samples(rate, AlignedSpans.duration(span))` gives us the minimum
            # number of samples of any span of that duration.
            # Thus, we should have:
            @test n >= n_samples(rate, AlignedSpans.duration(span)) >= n - 1
        end
    end
end

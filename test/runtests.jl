using AlignedSpans
using AlignedSpans: n_samples, indices
using Test
using TimeSpans, Dates, Onda, Intervals
# re-enable once there is a compatible Onda
#using Onda

const ClosedNSInterval = Interval{Nanosecond,Closed,Closed}

function make_test_samples(sample_rate)
    return Samples(permutedims([0:100 10:110]),
                   SamplesInfo(; kind="test", channels=["a", "b"], sample_unit="microvolt",
                               sample_resolution_in_unit=0.5, sample_offset_in_unit=0.0,
                               sample_type=UInt16,
                               sample_rate), false)
end

@testset "AlignedSpans.jl" begin
    @testset "RoundInward" begin
        for span in (TimeSpan(Millisecond(1500), Millisecond(2500)),
                     TimeSpan(Millisecond(1001), Millisecond(2001)),
                     TimeSpan(Millisecond(1001), Millisecond(2999)),
                     TimeSpan(Millisecond(2000), Millisecond(2001)))
            # all spans include only sample 3, at second 2

            aligned = AlignedSpan(1, span, RoundInward)
            # Only sample included inside `span` is sample 3
            @test indices(aligned) == 3:3
            @test Interval(aligned) == ClosedNSInterval(Second(2), Second(2))
        end

        # Does *not* contain any samples
        span = TimeSpan(Millisecond(1999), Millisecond(2000))
        @test_throws ArgumentError("No samples lie within `span`") AlignedSpan(1, span,
                                                                               RoundInward)
    end

    @testset "RoundEndsDown" begin
        for span in (TimeSpan(Millisecond(1500), Millisecond(2500)),
                     TimeSpan(Millisecond(1001), Millisecond(2001)),
                     TimeSpan(Millisecond(1001), Millisecond(2999)))
            aligned = AlignedSpan(1, span, RoundEndsDown)
            # Only sample included inside `span` is sample 3, but we round left endpoint down
            @test indices(aligned) == 2:3
            @test Interval(aligned) ==
                  ClosedNSInterval(Second(1), Second(2))
        end

        span = TimeSpan(Millisecond(2000), Millisecond(2001))
        aligned = AlignedSpan(1, span, RoundEndsDown)
        @test indices(aligned) == 3:3
        @test Interval(aligned) == ClosedNSInterval(Second(2), Second(2))

        span = TimeSpan(Millisecond(1999), Millisecond(2000))
        aligned = AlignedSpan(1, span, RoundEndsDown)
        @test indices(aligned) == 2:2
        @test Interval(aligned) == ClosedNSInterval(Second(1), Second(1))
    end

    @testset "ConstantSamplesRoundingMode" begin
        mode = ConstantSamplesRoundingMode(RoundDown)
        span = TimeSpan(Millisecond(1500), Millisecond(2500))
        aligned = AlignedSpan(1, span, mode)
        inds = indices(aligned)
        @test length(inds) == n_samples(1, duration(span))
        @test inds == 2:2
        for t in 1:100
            translated = translate(span, Second(t))
            aligned = AlignedSpan(1, translated, mode)
            inds = indices(aligned)
            @test length(inds) == n_samples(aligned) == n_samples(1, duration(span))
        end

        span = TimeSpan(Millisecond(1500), Millisecond(2600))
        aligned = AlignedSpan(1, span, mode)
        @test indices(aligned) == 2:2

        # We should get the same number of samples no matter how we translate it
        for t in [Millisecond(1):Millisecond(1):Millisecond(1000);
                  Nanosecond(10):Nanosecond(10):Nanosecond(1000)]
            translated_span = TimeSpans.translate(span, t)
            aligned = AlignedSpan(1, translated_span, mode)
            @test length(indices(aligned)) ==
                  n_samples(aligned) ==
                  length(2:2)
        end
    end

    @testset "Samples indexing" begin
        for sample_rate in [1.0, 0.5, 100.0, 128.33]
            samples = make_test_samples(sample_rate)
            for (i, j) in [1 => 10, 5 => 20, 3 => 6, 78 => 79]
                @test samples[:, AlignedSpan(sample_rate, i, j)] == samples[:, i:j]
                @test_throws ArgumentError samples[:, AlignedSpan(sample_rate + 1, i, j)]
            end
        end
    end

    function test_subspans(aligned, sample_rate, dur)
        subspans = collect(consecutive_subspans(aligned, dur))
        @test length(subspans) == cld(n_samples(aligned), n_samples(sample_rate, dur))
        for i in 1:(length(subspans) - 1)
            @test subspans[i + 1].first_index == subspans[i].last_index + 1 # consecutive indices
            @test n_samples(subspans[i]) == n_samples(sample_rate, dur) # each has as many samples as prescribed by the duration
        end
        r = rem(n_samples(aligned), n_samples(sample_rate, dur)) # last one has the remainder
        if r != 0
            @test n_samples(subspans[end]) == r
        else
            @test n_samples(subspans[end]) == n_samples(sample_rate, dur)
        end
    end

    @testset "consecutive_subspans" begin
        sample_rate = 1
        span = TimeSpan(Second(0), Second(100))
        aligned = AlignedSpan(sample_rate, span, RoundEndsDown)
        @test n_samples(aligned) == 100

        # Special case: duration == inv(sampling rate)
        subspans = consecutive_subspans(aligned, Second(1))
        @test subspans isa Base.Generator
        v = collect(subspans)
        @test length(v) == 100
        for i in 1:100
            @test v[i] == AlignedSpan(sample_rate, i, i) # all one-sample wide
        end

        test_subspans(aligned, sample_rate, Second(1))

        # Other cases
        test_subspans(aligned, sample_rate, Second(9))
        test_subspans(aligned, sample_rate, Millisecond(2500))
        test_subspans(aligned, sample_rate, Millisecond(1111))

        @test_throws ArgumentError consecutive_subspans(aligned, Millisecond(1))
    end
end

# Show we could interop with `StepRange`
function Base.StepRange(span::AlignedSpans.AlignedSpan)
    # the rounding here is not ideal
    t = Nanosecond(round(Int, TimeSpans.nanoseconds_per_sample(span.sample_rate)))
    return (span.first_index * t):t:(span.last_index * t)
end

function AlignedSpan(r::StepRange{T,S}) where {T<:Period,S<:Period}
    sample_rate = TimeSpans.NS_IN_SEC / Dates.value(convert(Nanosecond, step(r)))
    i = first(r) / step(r)
    j = last(r) / step(r)
    return AlignedSpan(sample_rate, Int(i), Int(j))
end

@testset "StepRange roundtripping" begin
    for sample_rate in [1.0, 0.5, 100.0, 128.33]
        for (i, j) in [1 => 10, 5 => 20, 3 => 6, 78 => 79]
            span = AlignedSpan(sample_rate, i, j)
            r = StepRange(span)
            span2 = AlignedSpan(r)
            @test span.first_index == span2.first_index
            @test span.last_index == span2.last_index
            @test span.sample_rate ≈ span2.sample_rate rtol = 1e-7 # annoyingly imprecise...
        end
    end
end

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
            @test index == AlignedSpans.index_and_error_from_time(rate, sample_time, RoundDown)[1]
            # Works even if `rate` is in Float64 precision:
            @test index == AlignedSpans.index_and_error_from_time(Float64(rate), sample_time, RoundDown)[1]
        end
    end
end

using AlignedSpans
using AlignedSpans: n_samples
using Test
using TimeSpans, Dates
# re-enable once there is a compatible Onda
#using Onda

function make_test_samples(sample_rate)
    return Samples(permutedims([0:100 10:110]),
                   SamplesInfo("test", ["a", "b"], "microvolt", 0.5, 0.0, UInt16,
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
            @test TimeSpans.index_from_time(1, aligned) == 3:3
            @test TimeSpan(aligned) == TimeSpan(Second(2), Second(2))
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
            @test TimeSpans.index_from_time(1, aligned) == 2:3
            @test TimeSpan(aligned) ==
                  TimeSpan(Second(1), Nanosecond(Second(2)) + Nanosecond(1))
        end

        span = TimeSpan(Millisecond(2000), Millisecond(2001))
        aligned = AlignedSpan(1, span, RoundEndsDown)
        @test TimeSpans.index_from_time(1, aligned) == 3:3
        @test TimeSpan(aligned) == TimeSpan(Second(2), Second(2))

        span = TimeSpan(Millisecond(1999), Millisecond(2000))
        aligned = AlignedSpan(1, span, RoundEndsDown)
        @test TimeSpans.index_from_time(1, aligned) == 2:2
        @test TimeSpan(aligned) == TimeSpan(Second(1), Second(1))
    end

    @testset "ConstantSamplesRoundingMode" begin
        mode = ConstantSamplesRoundingMode(RoundDown)
        span = TimeSpan(Millisecond(1500), Millisecond(2500))
        aligned = AlignedSpan(1, span, mode)
        inds = TimeSpans.index_from_time(1, aligned)
        @test length(inds) == n_samples(1, duration(span))
        @test inds == 2:2
        for t in 1:100
            translated = translate(span, Second(t))
            aligned = AlignedSpan(1, translated, mode)
            inds = TimeSpans.index_from_time(1, aligned)
            @test length(inds) == n_samples(aligned) == n_samples(1, duration(span))
        end

        span = TimeSpan(Millisecond(1500), Millisecond(2600))
        aligned = AlignedSpan(1, span, mode)
        @test TimeSpans.index_from_time(1, aligned) == 2:2

        # We should get the same number of samples no matter how we translate it
        for t in [Millisecond(1):Millisecond(1):Millisecond(1000);
                  Nanosecond(10):Nanosecond(10):Nanosecond(1000)]
            translated_span = TimeSpans.translate(span, t)
            aligned = AlignedSpan(1, translated_span, mode)
            @test length(TimeSpans.index_from_time(1, aligned)) ==
                  n_samples(aligned) ==
                  length(2:2)
        end
    end

    @testset "StepRange roundtripping" begin
        for sample_rate in [1.0, 0.5, 100.0, 128.33]
            for (i, j) in [1 => 10, 5 => 20, 3 => 6, 78 => 79]
                span = AlignedSpan(sample_rate, i, j)
                r = StepRange(span)
                span2 = AlignedSpan(r)
                @test span.i == span2.i
                @test span.j == span2.j
                @test span.sample_rate ≈ span2.sample_rate rtol = 1e-7 # annoyingly imprecise...
            end
        end
    end
    # Re-enable once there is a compatible Onda
    # @testset "Samples indexing" begin
    #     for sample_rate in [1.0, 0.5, 100.0, 128.33]
    #         samples = make_test_samples(sample_rate)
    #         for (i, j) in [1 => 10, 5 => 20, 3 => 6, 78 => 79]
    #             @test samples[:, AlignedSpan(sample_rate, i, j)] == samples[:, i:j]
    #         end
    #     end
    # end

    function test_subspans(aligned, sample_rate, dur)
        subspans = collect(consecutive_subspans(aligned, dur))
        @test length(subspans) == cld(n_samples(aligned), n_samples(sample_rate, dur))
        for i in 1:(length(subspans) - 1)
            @test subspans[i + 1].i == subspans[i].j + 1 # consecutive indices
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

using AlignedSpans
using AlignedSpans: n_samples, indices
using Test
using TimeSpans, Dates, Onda, Intervals
using JSON3, Arrow
using Aqua

@static if isdefined(Onda, :SignalV2)
    const _SamplesInfo = SamplesInfoV2
    sensor_type_name = :sensor_type
else
    const _SamplesInfo = SamplesInfo
    sensor_type_name = :kind
end

function make_test_samples(sample_rate)
    return Samples(permutedims([0:100 10:110]),
                   _SamplesInfo(; (sensor_type_name => "test",)...,
                                channels=["a", "b"], sample_unit="microvolt",
                                sample_resolution_in_unit=0.5, sample_offset_in_unit=0.0,
                                sample_type=UInt16,
                                sample_rate), false)
end

@testset "AlignedSpans.jl" begin
    @testset "Aqua" begin
        Aqua.test_all(AlignedSpans; ambiguities=false)
    end

    @testset "Construction from indices directly" begin
        @test AlignedSpan(100, 1, 3) == AlignedSpan(100.0, 1, 3)
        @test_throws ArgumentError AlignedSpan(100, 3, 1) # ends before starts
        @test AlignedSpan(100, 1, 200) == AlignedSpan(100, 1:200)
        @test_throws ArgumentError AlignedSpan(100, 3:1) # ends before starts with range constructor
    end

    @testset "RoundInward" begin
        for span in (TimeSpan(Millisecond(1500), Millisecond(2500)),
                     TimeSpan(Millisecond(1001), Millisecond(2001)),
                     TimeSpan(Millisecond(1001), Millisecond(2999)),
                     TimeSpan(Millisecond(2000), Millisecond(2001)))
            # all spans include only sample 3, at second 2

            aligned = AlignedSpan(1, span, RoundInward)
            # Only sample included inside `span` is sample 3
            @test indices(aligned) == 3:3

            @test TimeSpan(aligned) == TimeSpan(Second(2), Second(3))
        end

        # Does *not* contain any samples
        span = TimeSpan(Millisecond(1999), Millisecond(2000))
        @test_throws ArgumentError("No samples lie within `span`") AlignedSpan(1, span,
                                                                               RoundInward)
    end

    @testset "RoundSpanDown" begin
        for span in (TimeSpan(Millisecond(1500), Millisecond(2500)),
                     TimeSpan(Millisecond(1001), Millisecond(2001)),
                     TimeSpan(Millisecond(1001), Millisecond(2999)))
            aligned = AlignedSpan(1, span, RoundSpanDown)
            # Only sample included inside `span` is sample 3, but we round left endpoint down
            @test indices(aligned) == 2:3

            @test TimeSpan(aligned) == TimeSpan(Second(1), Second(3))
        end

        span = TimeSpan(Millisecond(2000), Millisecond(2001))
        aligned = AlignedSpan(1, span, RoundSpanDown)
        @test indices(aligned) == 3:3

        span = TimeSpan(Millisecond(1999), Millisecond(2000))
        aligned = AlignedSpan(1, span, RoundSpanDown)
        @test indices(aligned) == 2:2

        # Test that we can pass an `AlignedSpan` back into the constructor
        @test AlignedSpan(1, aligned, RoundSpanDown) == aligned
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

        for span in (TimeSpan(Millisecond(1500), Millisecond(2600)),
                     Interval{Nanosecond,Closed,Open}(Millisecond(1500), Millisecond(2600)))
            aligned = AlignedSpan(1, span, mode)
            @test indices(aligned) == 2:2
        end

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

    include("interop.jl")
    include("time_index_conversions.jl")
    include("utilities.jl")
end

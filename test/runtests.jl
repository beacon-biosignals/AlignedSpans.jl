using AlignedSpans
using AlignedSpans: n_samples, indices
using Test
using TimeSpans, Dates, Onda, Intervals
using JSON3, Arrow
using Aqua

function make_test_samples(sample_rate)
    return Samples(permutedims([0:100 10:110]),
                   SamplesInfo(; kind="test", channels=["a", "b"], sample_unit="microvolt",
                               sample_resolution_in_unit=0.5, sample_offset_in_unit=0.0,
                               sample_type=UInt16,
                               sample_rate), false)
end

# Interop with `StepRange`
function Base.StepRange(span::AlignedSpan)
    # the rounding here is not ideal
    t = Nanosecond(round(Int, TimeSpans.nanoseconds_per_sample(span.sample_rate)))
    return (span.i * t):t:(span.j * t)
end

function AlignedSpan(r::StepRange{T,S}) where {T<:Period,S<:Period}
    sample_rate = TimeSpans.NS_IN_SEC / Dates.value(convert(Nanosecond, step(r)))
    i = first(r) / step(r)
    j = last(r) / step(r)
    return AlignedSpan(sample_rate, Int(i), Int(j))
end

@testset "AlignedSpans.jl" begin
    @testset "Aqua" begin
        Aqua.test_all(AlignedSpans; ambiguities=false)
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

    @testset "RoundEndsDown" begin
        for span in (TimeSpan(Millisecond(1500), Millisecond(2500)),
                     TimeSpan(Millisecond(1001), Millisecond(2001)),
                     TimeSpan(Millisecond(1001), Millisecond(2999)))
            aligned = AlignedSpan(1, span, RoundEndsDown)
            # Only sample included inside `span` is sample 3, but we round left endpoint down
            @test indices(aligned) == 2:3

            @test TimeSpan(aligned) == TimeSpan(Second(1), Second(3))
        end

        span = TimeSpan(Millisecond(2000), Millisecond(2001))
        aligned = AlignedSpan(1, span, RoundEndsDown)
        @test indices(aligned) == 3:3

        span = TimeSpan(Millisecond(1999), Millisecond(2000))
        aligned = AlignedSpan(1, span, RoundEndsDown)
        @test indices(aligned) == 2:2
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

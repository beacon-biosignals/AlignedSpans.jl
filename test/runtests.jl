using IndicesVsSpans
using Test
using TimeSpans, Dates

@testset "IndicesVsSpans.jl" begin
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
        @test_throws ArgumentError("No samples lie within `span`") AlignedSpan(1, span, RoundInward)
        
    end

    @testset "RoundConstantSamples" begin
        span = TimeSpan(Millisecond(1500), Millisecond(2500))
        aligned = AlignedSpan(1, span, RoundConstantSamples)
        inds = TimeSpans.index_from_time(1, aligned)
        @test length(inds) == IndicesVsSpans.n_samples(1, duration(span))
        @test inds == 2:2
        for t = 1:100
            translated = translate(span, Second(t))
            aligned = AlignedSpan(1, translated, RoundConstantSamples)
            inds = TimeSpans.index_from_time(1, aligned)
            @test length(inds) == IndicesVsSpans.n_samples(1, duration(span))
        end

        span = TimeSpan(Millisecond(1500), Millisecond(2600))
        aligned = AlignedSpan(1, span, RoundConstantSamples)
        @test TimeSpans.index_from_time(1, aligned) == 2:2

        # We should get the same number of samples no matter how we translate it
        for t in [Millisecond(1):Millisecond(1):Millisecond(1000); Nanosecond(10):Nanosecond(10):Nanosecond(1000)]
            translated_span = TimeSpans.translate(span, t)
            aligned = AlignedSpan(1, translated_span, RoundConstantSamples)
            @test length(TimeSpans.index_from_time(1, aligned)) == length(2:2)
        end
    end
end

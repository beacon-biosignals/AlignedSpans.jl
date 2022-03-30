#####
##### StepRange
#####

# Show we could interop with `StepRange`, which is another contender for a TimeSpans alternative
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

#####
##### TimeSpans
#####

@testset "TimeSpans roundtripping" begin
    for sample_rate in [1.0, 0.5, 100.0, 128.33]
        # AlignedSpan -> TimeSpan -> AlignedSpan
        for (i, j) in [1 => 10, 5 => 20, 3 => 6, 78 => 79]
            for mode in (RoundEndsDown, RoundInward, ConstantSamplesRoundingMode(RoundDown))
                as = AlignedSpan(sample_rate, i, j)
                ts = TimeSpan(as)

                # We don't perfectly roundtrip with sample rate 128.33 for two of the rounding modes.
                # However, if we widen the timespan by 1 nanosecond, we can roundtrip in that case.
                # So let's test that, at least.
                if sample_rate == 128.33
                    if mode == RoundInward
                        ts = TimeSpan(max(Nanosecond(0), start(as) - Nanosecond(1)),
                                      stop(as))
                    elseif mode == ConstantSamplesRoundingMode(RoundDown)
                        ts = TimeSpan(start(as), stop(as) + Nanosecond(1))
                    end
                end

                rt = AlignedSpan(sample_rate, ts, mode)
                @test as == rt
            end
        end
    end
end

@test TimeSpans.istimespan(AlignedSpan(1, 1, 1))

#####
##### Onda
#####

@testset "Samples indexing" begin
    for sample_rate in [1.0, 0.5, 100.0, 128.33]
        samples = make_test_samples(sample_rate)
        for (i, j) in [1 => 10, 5 => 20, 3 => 6, 78 => 79]
            @test samples[:, AlignedSpan(sample_rate, i, j)] == samples[:, i:j]
            @test_throws ArgumentError samples[:, AlignedSpan(sample_rate + 1, i, j)]
        end
    end
end

#####
##### JSON/Arrow
#####

spans = [AlignedSpan(1.0, 5, 10), AlignedSpan(111.345, 500, 10000)]
@testset "JSON3 roundtripping" begin
    @test JSON3.read(JSON3.write(spans), Vector{AlignedSpan}) == spans
end

@testset "Arrow roundtripping" begin
    @test Arrow.Table(Arrow.tobuffer((; spans))).spans == spans
end

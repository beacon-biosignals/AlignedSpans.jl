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
    aligned = AlignedSpan(sample_rate, span, RoundSpanDown)
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

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

    # Ends at the end
    @test subspans[end].last_index == aligned.last_index

    # all test w/ `keep_last=false`
    test_subspans_skip_last(aligned, sample_rate, dur)
    return nothing
end

function test_subspans_skip_last(aligned, sample_rate, dur)
    @show aligned, sample_rate, dur
    subspans = collect(consecutive_subspans(aligned, dur; keep_last=false))
    @test length(subspans) == fld(n_samples(aligned), n_samples(sample_rate, dur))
    for i in 1:(length(subspans) - 1)
        @test subspans[i + 1].first_index == subspans[i].last_index + 1 # consecutive indices
        @test n_samples(subspans[i]) == n_samples(sample_rate, dur) # each has as many samples as prescribed by the duration
    end

    # Does not necessarily end all the way at the end, but gets within `n`
    @test aligned.last_index - n_samples(sample_rate, dur) <= subspans[end].last_index <=
          aligned.last_index
    return nothing
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

@testset "consecutive_overlapping_subspans" begin
    # when window_duration == hop duration and window_duration fits into
    # samples_span exactly n times, the output of consecutive_overlapping_subspans
    # should equal that of consecutive_subspans
    samples_span = AlignedSpan(128, 1, 128 * 120)
    window_samples = 10 * 128
    subspans = consecutive_overlapping_subspans(samples_span, window_samples,
                                                window_samples)
    og_subspans = consecutive_subspans(samples_span, window_samples)
    @test all(collect(subspans) .== collect(og_subspans))

    # Check w/ Period's
    subspans2 = consecutive_overlapping_subspans(samples_span, Second(10),
                                                 Second(10))
    @test all(collect(subspans) .== collect(subspans2))

    # when window_duration == hop duration but window_duration does not
    # fit evenly into samples_span, consecutive_subspans will return a
    # last AlignedSpan with n_samples < n_samples(window_duration), whereas
    # consecutive_overlapping_subspans will omit the last window and only
    # return AlignedSpans with n_samples = n_samples(window_duration)
    window_samples = 11 * 128
    subspans = consecutive_overlapping_subspans(samples_span, window_samples,
                                                window_samples)
    og_subspans = consecutive_subspans(samples_span, window_samples)
    c_subspans = collect(subspans)
    @test length(collect(og_subspans)) - 1 == length(c_subspans)
    @test all(n_samples.(c_subspans) .== window_samples)

    # Check w/ Period's
    subspans2 = consecutive_overlapping_subspans(samples_span, Second(11),
                                                 Second(11))
    @test all(collect(subspans) .== collect(subspans2))

    # when hop_samples < window_samples
    window_samples = 10 * 128
    hop_samples = 5 * 128
    n_complete_windows = fld((n_samples(samples_span) - window_samples), hop_samples) + 1
    subspans = consecutive_overlapping_subspans(samples_span, window_samples, hop_samples)
    c_subspans = collect(subspans)
    @test length(c_subspans) == n_complete_windows
    @test all(n_samples.(c_subspans) .== window_samples)

    # Check w/ Period's
    subspans2 = consecutive_overlapping_subspans(samples_span, Second(10),
                                                 Second(5))
    @test all(collect(subspans) .== collect(subspans2))

    # hop_samples < windows_samples and window_samples does not fit exactly into
    # samples_span
    window_samples = 11 * 128
    hop_samples = 5 * 128
    n_complete_windows = fld((n_samples(samples_span) - window_samples), hop_samples) + 1
    subspans = consecutive_overlapping_subspans(samples_span, window_samples, hop_samples)
    c_subspans = collect(subspans)
    @test length(c_subspans) == n_complete_windows
    @test all(n_samples.(c_subspans) .== window_samples)

    # Check w/ Period's
    subspans2 = consecutive_overlapping_subspans(samples_span, Second(11),
                                                 Second(5))
    @test all(collect(subspans) .== collect(subspans2))
end

"""
    AlignedSpans.indices(span::AlignedSpan) -> UnitRange{Int64}

Returns the sample indices associated to an `AlignedSpan`.
"""
indices(span::AlignedSpan) = (span.first_index):(span.last_index)

"""
    n_samples(aligned::AlignedSpan)

Returns the number of samples present in the span `aligned`.
"""
n_samples(aligned::AlignedSpan) = length(indices(aligned))

"""
    consecutive_subspans(span::AlignedSpan, duration::Period; keep_last=true)
    consecutive_subspans(span::AlignedSpan, n::Int; keep_last=true)

Creates an iterator of `AlignedSpan` such that each `AlignedSpan` has consecutive indices
which cover the original `span`'s indices (when `keep_last=true`).

If `keep_last=true` (the default behavior), then the last span may have fewer samples than the others, and

* Each span has `n` samples (which is calculated as `n_samples(span.sample_rate, duration)` if `duration::Period` is supplied), except possibly
the last one, which may have fewer.
* The number of subspans is given by `cld(n_samples(span), n)`,
* The number of samples in the last subspan is `r = rem(n_samples(span), n)` unless `r=0`, in which
case the the last subspan has the same number of samples as the rest, namely `n`.
* All of the indices of `span` are guaranteed to be covered by exactly one subspan

If `keep_last=false`, then all spans will have the same number of samples:
* Each span has `n` samples (which is calculated as `n_samples(span.sample_rate, duration)` if `duration::Period` is supplied)
* The number of subspans is given by `fld(n_samples(span), n)`
* The last part of the `span`'s indices may not be covered (when we can't fit in another subspan of length `n`)
"""
function consecutive_subspans(span::AlignedSpan, duration::Period; keep_last=true)
    n = n_samples(span.sample_rate, duration)
    return consecutive_subspans(span::AlignedSpan, n; keep_last)
end

function consecutive_subspans(span::AlignedSpan, n::Int; keep_last=true)
    index_groups = Iterators.partition((span.first_index):(span.last_index), n)
    if !keep_last
        r = rem(n_samples(span), n)
        if r != 0
            # Drop the last element
            grps = Iterators.take(index_groups, fld(n_samples(span), n))
            return (AlignedSpan(span.sample_rate, first(I), last(I)) for I in grps)
        end
    end
    return (AlignedSpan(span.sample_rate, first(I), last(I)) for I in index_groups)
end

"""
    consecutive_overlapping_subspans(span::AlignedSpan, duration::Period,
                                     hop_duration::Period)
    consecutive_overlapping_subspans(span::AlignedSpan, n::Int, m::Int)

Create an iterator of `AlignedSpan` such that each `AlignedSpan` has
`n` (calculated as `n_samples(span.sample_rate, duration)` if `duration::Period` is supplied) samples, shifted by
`m` (calculated as `n_samples(span.sample_rate, hop_duration)` if `hop_duration::Period` is supplied) samples between
consecutive spans.

!!! warning
    When `n_samples(span)` is not an integer multiple of `n`, only AlignedSpans with `n`
    samples will be returned. This is analgous to `consecutive_subspans` with `keep_last=false`, which is not the default behavior for `consecutive_subspans`.

Note: If `hop_duration` cannot be represented as an integer number of samples,
rounding will occur to ensure that all output AlignedSpans will have the
same number of samples. When rounding occurs, the output hop_duration will be:
`Nanosecond(n_samples(samp_rate, hop_duration) / samp_rate * 1e9)`
"""
function consecutive_overlapping_subspans(span::AlignedSpan, duration::Period,
                                          hop_duration::Period)
    n = n_samples(span.sample_rate, duration)
    m = n_samples(span.sample_rate, hop_duration)
    return consecutive_overlapping_subspans(span::AlignedSpan, n, m)
end

function consecutive_overlapping_subspans(span::AlignedSpan, n::Int, m::Int)
    index_groups = Iterators.partition((span.first_index):(span.last_index - n + 1),
                                       m)
    return (AlignedSpan(span.sample_rate, first(I), first(I) + n - 1)
            for I in index_groups)
end

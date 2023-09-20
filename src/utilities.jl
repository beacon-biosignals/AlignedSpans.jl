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
    consecutive_subspans(span::AlignedSpan, n_window_samples::Int; keep_last=true)

Creates an iterator of `AlignedSpan` such that each `AlignedSpan` has consecutive indices
which cover the original `span`'s indices (when `keep_last=true`).

If `keep_last=true` (the default behavior), then the last span may have fewer samples than the others, and

* Each span has `n_window_samples` samples (which is calculated as `n_samples(span.sample_rate, duration)` if `duration::Period` is supplied), except possibly
the last one, which may have fewer.
* The number of subspans is given by `cld(n_samples(span), n_window_samples)`,
* The number of samples in the last subspan is `r = rem(n_samples(span), n_window_samples)` unless `r=0`, in which
case the the last subspan has the same number of samples as the rest, namely `n_window_samples`.
* All of the indices of `span` are guaranteed to be covered by exactly one subspan

If `keep_last=false`, then all spans will have the same number of samples:
* Each span has `n_window_samples` samples (which is calculated as `n_samples(span.sample_rate, duration)` if `duration::Period` is supplied)
* The number of subspans is given by `fld(n_samples(span), n_window_samples)`
* The last part of the `span`'s indices may not be covered (when we can't fit in another subspan of length `n_window_samples`)
"""
function consecutive_subspans(span::AlignedSpan, duration::Period; keep_last=true)
    n_window_samples = n_samples(span.sample_rate, duration)
    return consecutive_subspans(span::AlignedSpan, n_window_samples; keep_last)
end

function consecutive_subspans(span::AlignedSpan, n_window_samples::Int; keep_last=true)
    index_groups = Iterators.partition((span.first_index):(span.last_index), n_window_samples)
    if !keep_last
        r = rem(n_samples(span), n_window_samples)
        if r != 0
            # Drop the last element
            grps = Iterators.take(index_groups, fld(n_samples(span), n_window_samples))
            return (AlignedSpan(span.sample_rate, first(I), last(I)) for I in grps)
        end
    end
    return (AlignedSpan(span.sample_rate, first(I), last(I)) for I in index_groups)
end

"""
    consecutive_overlapping_subspans(span::AlignedSpan, duration::Period,
                                     hop_duration::Period)
    consecutive_overlapping_subspans(span::AlignedSpan, n_window_samples::Int, n_hop_samples::Int)

Create an iterator of `AlignedSpan` such that each `AlignedSpan` has
`n_window_samples` (calculated as `n_samples(span.sample_rate, duration)` if `duration::Period` is supplied) samples, shifted by
`n_hop_samples` (calculated as `n_samples(span.sample_rate, hop_duration)` if `hop_duration::Period` is supplied) samples between
consecutive spans.

!!! warning
    When `n_samples(span)` is not an integer multiple of `n_window_samples`, only AlignedSpans with `n_window_samples`
    samples will be returned. This is analgous to `consecutive_subspans` with `keep_last=false`, which is not the default behavior for `consecutive_subspans`.

Note: If `hop_duration` cannot be represented as an integer number of samples,
rounding will occur to ensure that all output AlignedSpans will have the
same number of samples. When rounding occurs, the output hop_duration will be:
`Nanosecond(n_samples(samp_rate, hop_duration) / samp_rate * 1e9)`
"""
function consecutive_overlapping_subspans(span::AlignedSpan, duration::Period,
                                          hop_duration::Period)
    n_window_samples = n_samples(span.sample_rate, duration)
    n_hop_samples = n_samples(span.sample_rate, hop_duration)
    return consecutive_overlapping_subspans(span::AlignedSpan, n_window_samples, n_hop_samples)
end

function consecutive_overlapping_subspans(span::AlignedSpan, n_window_samples::Int, n_hop_samples::Int)
    index_groups = Iterators.partition((span.first_index):(span.last_index - n_window_samples + 1),
                                       n_hop_samples)
    return (AlignedSpan(span.sample_rate, first(I), first(I) + n_window_samples - 1)
            for I in index_groups)
end

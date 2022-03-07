indices(span::AlignedSpan) = (span.first_index):(span.last_index)

"""
    n_samples(aligned::AlignedSpan)

Returns the number of samples present in the span `aligned`.
"""
n_samples(aligned::AlignedSpan) = aligned.last_index - aligned.first_index + 1

"""
    consecutive_subspans(span::AlignedSpan, duration::Period)

Creates an iterator of `AlignedSpan` such that each `AlignedSpan` has consecutive indices
which cover all of the original `span`'s indices. In particular,

* Each span has `n = n_samples(span.sample_rate, duration)` samples, except possibly
the last one, which may have fewer.
* The number of subspans is given by `cld(n_samples(span), n)`
* The number of samples in the last subspan is `r = rem(n_samples(span), n)` unless `r=0`, in which
  case the the last subspan has the same number of samples as the rest, namely `n`.
"""
function consecutive_subspans(span::AlignedSpan, duration::Period)
    n = n_samples(span.sample_rate, duration)
    return consecutive_subspans(span::AlignedSpan, n)
end

function consecutive_subspans(span::AlignedSpan, n::Int)
    first_index = span.first_index
    last_index = span.last_index
    rate = span.sample_rate
    return (AlignedSpan(rate, first(I), last(I)) for I in
                                                     Iterators.partition(first_index:last_index,
                                                                         n))
end

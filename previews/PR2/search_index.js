var documenterSearchIndex = {"docs":
[{"location":"#API-Documentation","page":"API Documentation","title":"API Documentation","text":"","category":"section"},{"location":"","page":"API Documentation","title":"API Documentation","text":"CurrentModule = AlignedSpans","category":"page"},{"location":"#Example","page":"API Documentation","title":"Example","text":"","category":"section"},{"location":"","page":"API Documentation","title":"API Documentation","text":"Let's consider the following TimeSpan","category":"page"},{"location":"","page":"API Documentation","title":"API Documentation","text":"using TimeSpans, AlignedSpans, Dates\n\nspan = TimeSpan(Millisecond(1500), Millisecond(3500))","category":"page"},{"location":"","page":"API Documentation","title":"API Documentation","text":"If we have a 1 Hz signal, there are various ways we can index into it using this TimeSpan. One option is to round the endpoints down:","category":"page"},{"location":"","page":"API Documentation","title":"API Documentation","text":"\ndown_span = AlignedSpan(1, span, RoundEndsDown)\n\nn_samples(down_span)","category":"page"},{"location":"","page":"API Documentation","title":"API Documentation","text":"The second sample of our signal occurs at time 1s (since we have a 1Hz signal that starts at 0s). When we round the starting endpoint down from 1.5s to the nearest sample, we find that sample. This can be seen as \"the last sample that occurred before time 1.5s\".","category":"page"},{"location":"","page":"API Documentation","title":"API Documentation","text":"Perhaps instead we would like to round the endpoints \"inward\" to only consider samples occurring with the time span:","category":"page"},{"location":"","page":"API Documentation","title":"API Documentation","text":"in_span = AlignedSpan(1, span, RoundInward)\nn_samples(in_span)","category":"page"},{"location":"#Interface","page":"API Documentation","title":"Interface","text":"","category":"section"},{"location":"","page":"API Documentation","title":"API Documentation","text":"AlignedSpan\nAlignedSpans.start_index_from_time\nAlignedSpans.stop_index_from_time\nAlignedSpans.duration\nAlignedSpans.EndpointRoundingMode\nAlignedSpans.ConstantSamplesRoundingMode","category":"page"},{"location":"#AlignedSpans.AlignedSpan","page":"API Documentation","title":"AlignedSpans.AlignedSpan","text":"AlignedSpan(sample_rate, span, mode::EndpointRoundingMode)\n\nCreates an AlignedSpan by rounding the left endpoint according to mode.start, and the right endpoint by mode.stop.\n\nIf mode.start==RoundUp, then the left index of the resulting span is guaranteed to be inside span. This is accomplished by checking if the left endpoint of the span is exclusive, and if so, incrementing the index after rounding when necessary.\n\nLikewise, if mode.start==RoundDown, then the right index of the resulting span is guaranteed to be inside span. This is accomplished by checking if the right endpoint of the span is exclusive, and if so, decrementing the index after rounding when necessary.\n\nNote: span may be of any type which which provides methods for AlignedSpans.start_index_from_time and AlignedSpans.stop_index_from_time.\n\n\n\n\n\nAlignedSpan(sample_rate, span, mode::ConstantSamplesRoundingMode)\n\nCreates an AlignedSpan whose left endpoint is rounded according to mode.start, and whose right endpoint is determined so by the left endpoint and the total number of samples, given by AlignedSpans.n_samples(sample_rate, duration(span)).\n\nNote: span may be of any type which which provides a method for AlignedSpans.start_index_from_time and AlignedSpans.duration.\n\n\n\n\n\n","category":"type"},{"location":"#AlignedSpans.start_index_from_time","page":"API Documentation","title":"AlignedSpans.start_index_from_time","text":"start_index_from_time(sample_rate, span, rounding_mode)\n\nReturns the index of a sample object obtained by rounding the start of span according to rounding_mode.\n\n\n\n\n\n","category":"function"},{"location":"#AlignedSpans.stop_index_from_time","page":"API Documentation","title":"AlignedSpans.stop_index_from_time","text":"stop_index_from_time(sample_rate, span, rounding_mode)\n\nReturns the index of a sample object obtained by rounding the stop of span according to rounding_mode.\n\n\n\n\n\n","category":"function"},{"location":"#AlignedSpans.duration","page":"API Documentation","title":"AlignedSpans.duration","text":"duration(span)\n\nReturn the duration of span.\n\n\n\n\n\n","category":"function"},{"location":"#AlignedSpans.EndpointRoundingMode","page":"API Documentation","title":"AlignedSpans.EndpointRoundingMode","text":"EndpointRoundingMode(start::RoundingMode, stop::RoundingMode)\n\nCreates a rounding object for AlignedSpan to indicate how the AlignedSpan's endpoints should be determined from a given spans endpoints'.\n\n\n\n\n\n","category":"type"},{"location":"#AlignedSpans.ConstantSamplesRoundingMode","page":"API Documentation","title":"AlignedSpans.ConstantSamplesRoundingMode","text":"ConstantSamplesRoundingMode(start::RoundingMode)\n\nCreates a rounding object for AlignedSpan to indicate the AlignedSpan should be constructed by the start and duration of the span, without regard to its stop.\n\nIf two spans have the same duration, then the resulting AlignedSpan's will have the same number of samples when constructed with this rounding mode.\n\n\n\n\n\n","category":"type"},{"location":"#Utilities","page":"API Documentation","title":"Utilities","text":"","category":"section"},{"location":"","page":"API Documentation","title":"API Documentation","text":"n_samples\nAlignedSpans.indices\nconsecutive_subspans","category":"page"},{"location":"#AlignedSpans.n_samples","page":"API Documentation","title":"AlignedSpans.n_samples","text":"n_samples(sample_rate, duration::Period)\n\nReturns the minimal number of samples that can occur in a span of duration duration.\n\n\n\n\n\nn_samples(aligned::AlignedSpan)\n\nReturns the number of samples present in the span aligned.\n\n\n\n\n\n","category":"function"},{"location":"#AlignedSpans.indices","page":"API Documentation","title":"AlignedSpans.indices","text":"indices(span::AlignedSpan) -> UnitRange{Int64}\n\nReturns the sample indices associated to an AlignedSpan.\n\n\n\n\n\n","category":"function"},{"location":"#AlignedSpans.consecutive_subspans","page":"API Documentation","title":"AlignedSpans.consecutive_subspans","text":"consecutive_subspans(span::AlignedSpan, duration::Period)\n\nCreates an iterator of AlignedSpan such that each AlignedSpan has consecutive indices which cover all of the original span's indices. In particular,\n\nEach span has n = n_samples(span.sample_rate, duration) samples, except possibly\n\nthe last one, which may have fewer.\n\nThe number of subspans is given by cld(n_samples(span), n)\nThe number of samples in the last subspan is r = rem(n_samples(span), n) unless r=0, in which case the the last subspan has the same number of samples as the rest, namely n.\n\n\n\n\n\n","category":"function"}]
}

var documenterSearchIndex = {"docs":
[{"location":"","page":"Introduction","title":"Introduction","text":"CurrentModule = AlignedSpans","category":"page"},{"location":"#AlignedSpans","page":"Introduction","title":"AlignedSpans","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"See API documentation for how to construct AlignedSpans, along with some utilities, or below for some examples and motivation.","category":"page"},{"location":"#Continuous-Discrete","page":"Introduction","title":"Continuous -> Discrete","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"Continuous timespans can be rounded (or \"aligned\") to the individual sample values by using the constructor AlignedSpan, which takes a sample_rate, a span, and a description of how to round time endpoints to indices. This constructs an AlignedSpan which supports Onda indexing. Internally, an AlignedSpan stores indices, not times, and any rounding happens when it is created instead of when indexing into samples.","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"Rounding options:","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"SpanRoundingMode: consists of a RoundingMode for the start and stop of the span.\nThe alias RoundInward = SpanRoundingMode(RoundUp, RoundDown), for example, constructs the largest span such that all samples are entirely contained within span.\nThe alias RoundSpanDown = SpanRoundingMode(RoundDown, RoundDown) matches the rounding semantics of TimeSpans.index_from_time(sample_rate, span).\nConstantSamplesRoundingMode consists of a RoundingMode for the start alone. The stop is determined from the start plus a number of samples which is a function only of the sampling rate and the duration of the span.","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"Also provides a helper consecutive_subspans to partition an AlignedSpan into smaller consecutive AlignedSpans of equal size (except possibly the last one).","category":"page"},{"location":"#Discrete-Continuous","page":"Introduction","title":"Discrete -> Continuous","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"AlignedSpan's support TimeSpans.start and TimeSpans.stop, so they can be used a continuous-time spans. The semantics of this are:","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"For any index included in an AlignedSpan, the time at which the corresponding sample occurred (inclusive) to the time at which the next sample occurred (exclusive) is associated to the continuous-time representation of the span.","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"As an example, if the sample rate is 1, and indices 2:3 are associated to a span, then the associated TimeSpan is TimeSpan(Second(1), Second(3)). That's because sample 2 occur at time Second(1), and is considered to \"last\" until sample 3, which occurs at Second(2). Next, sample 3 occurs at time Second(2) and is considered to \"last\" until sample 4, which occurs at Second(3). Therefore, the total span associated to 2:3 is Second(1) to Second(3).","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"In diagram form, the inclusive interval of indices [2, 3] is associated inclusive-exclusive interval of seconds, [1, 3):","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"Index       1   [2    3]    4     5\nTime (s)    0   [1    2     3)    4","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"This choice of conversion matches the inclusive-inclusive indexing of Julia integer indices to the inclusive-exclusive semantics of TimeSpans.jl, and allows for roundtripping and sensible durations:","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"julia> using AlignedSpans, TimeSpans, Dates\n\njulia> aligned = AlignedSpan(1, 2, 3)\nAlignedSpan(1.0, 2, 3)\n\njulia> ts = TimeSpan(aligned)\nTimeSpan(00:00:01.000000000, 00:00:03.000000000)\n\njulia> aligned == AlignedSpan(1, ts, RoundInward)\ntrue\n\njulia> aligned == AlignedSpan(1, ts, RoundSpanDown)\ntrue\n\njulia> duration(aligned) == duration(ts) == Second(2)\ntrue","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"warning: Warning\nFor non-integer sample rates, roundtripping perfectly is not always possible.","category":"page"},{"location":"#Note-on-roundtripping","page":"Introduction","title":"Note on roundtripping","text":"","category":"section"},{"location":"#Quick-example","page":"Introduction","title":"Quick example","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"Let's consider the following TimeSpan","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"using TimeSpans, AlignedSpans, Dates\n\nspan = TimeSpan(Millisecond(1500), Millisecond(3500))","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"If we have a 1 Hz signal, there are various ways we can index into it using this TimeSpan. One option is to round the endpoints down:","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"\ndown_span = AlignedSpan(1, span, RoundSpanDown)\n\nn_samples(down_span)","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"The second sample of our signal occurs at time 1s (since we have a 1Hz signal that starts at 0s). When we round the starting endpoint down from 1.5s to the nearest sample, we find that sample. This can be seen as \"the last sample that occurred before time 1.5s\".","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"Perhaps instead we would like to round the endpoints \"inward\" to only consider samples occurring with the time span:","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"in_span = AlignedSpan(1, span, RoundInward)\nn_samples(in_span)","category":"page"},{"location":"#Motivation","page":"Introduction","title":"Motivation","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"Let's say I want to plot some samples over time, and I have a nice function plot(::TimeSpan, ::Samples) to use.","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"using TimeSpans, Onda, Dates\nsample_rate = 1 # 1 Hz -> slow to exaggerate the effect\nsamples = Samples(permutedims(0:10), SamplesInfoV2(; sensor_type=\"feature\", channels=[\"a\"], sample_unit=\"microvolt\", sample_resolution_in_unit=0.5, sample_offset_in_unit=0.0, sample_type=UInt16, sample_rate), false)\nspan = TimeSpan(Millisecond(1500), Millisecond(4000))","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"Now I want to execute some call","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"plot(span, samples[:, span])","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"for some plot that understands TimeSpans – doesn't matter what function, exactly.","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"What is wrong with this?","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"Let's take a look at the samples we are plotting:","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"samples[:, span] # TimeSpans v0.2; v0.3 will have one more sample","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"These are three samples that correspond to times 1s, 2s, and 3s. However, what we gave to the x-axis of our plotting function is TimeSpan(Millisecond(1500), Millisecond(3500)), which starts at 1.5s and goes to 3.5s. In other words, our plot will have an incorrect 0.5s offset!","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"Note that plot is just an example; any function where one is separately passing both a \"timespan of interest\" and \"feature values from that timespan\" will have similar issues if one isn't careful about what exactly samples[:, span] is doing.","category":"page"},{"location":"#The-fix","page":"Introduction","title":"The fix","text":"","category":"section"},{"location":"","page":"Introduction","title":"Introduction","text":"Let's take the same setup, with our","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"span","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"This time, we do","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"using AlignedSpans\naligned_span = AlignedSpan(samples.info.sample_rate, span, RoundSpanDown)\nsamples[:, aligned_span]","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"Here, I get the same samples. However, now I have the actual span corresponding to those samples, namely aligned_span. So if I call my","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"plot(aligned_span, samples[:, aligned_span])","category":"page"},{"location":"","page":"Introduction","title":"Introduction","text":"I'll have the correct alignment between the points on the x-axis and y-axis.","category":"page"},{"location":"API/#API-documentation","page":"API Documentation","title":"API documentation","text":"","category":"section"},{"location":"API/","page":"API Documentation","title":"API Documentation","text":"AlignedSpan\nAlignedSpans.SpanRoundingMode\nAlignedSpans.RoundInward\nAlignedSpans.RoundSpanDown\nAlignedSpan(sample_rate, span, mode::SpanRoundingMode)\nAlignedSpans.ConstantSamplesRoundingMode\nAlignedSpan(sample_rate, span, mode::ConstantSamplesRoundingMode)\nconsecutive_subspans\nconsecutive_overlapping_subspans\nn_samples\nAlignedSpans.indices","category":"page"},{"location":"API/#AlignedSpans.AlignedSpan","page":"API Documentation","title":"AlignedSpans.AlignedSpan","text":"AlignedSpan(sample_rate::Number, first_index::Int, last_index::Int)\n\nConstruct an AlignedSpan directly from a sample_rate and indices.\n\n\n\n\n\n","category":"type"},{"location":"API/#AlignedSpans.SpanRoundingMode","page":"API Documentation","title":"AlignedSpans.SpanRoundingMode","text":"SpanRoundingMode(start::RoundingMode, stop::RoundingMode)\n\nCreates a rounding object for AlignedSpan to indicate how the AlignedSpan's endpoints should be determined from a given spans endpoints'.\n\n\n\n\n\n","category":"type"},{"location":"API/#AlignedSpans.RoundInward","page":"API Documentation","title":"AlignedSpans.RoundInward","text":"RoundInward = SpanRoundingMode(RoundUp, RoundDown)\n\nThis is a rounding mode where both ends of the continuous time interval are rounded \"inwards\" to construct the largest span of indices such that all samples are entirely contained within it.\n\nExample\n\nConsider a signal with sample rate 1 Hz.\n\nIndex       1   2   3   4   5\nTime (s)    0   1   2   3   4\n\nNow, consider the time span 1.5s (inclusive) to 2.5s (exclusive). Using brackets to highlight this span:\n\nIndex       1   2     3     4   5\nTime (s)    0   1  [  2  )  3   4\n\nIn code, this span is described by\n\njulia> using AlignedSpans, Dates, TimeSpans\n\njulia> ts = TimeSpan(Millisecond(1500), Millisecond(2500))\nTimeSpan(00:00:01.500000000, 00:00:02.500000000)\n\nThe only sample within the span is at index 3. And indeed,\n\njulia> aligned = AlignedSpan(1, ts, RoundInward)\nAlignedSpan(1.0, 3, 3)\n\njulia> AlignedSpans.indices(aligned)\n3:3\n\ngives an AlignedSpan with indices 3:3.\n\n\n\n\n\n","category":"constant"},{"location":"API/#AlignedSpans.RoundSpanDown","page":"API Documentation","title":"AlignedSpans.RoundSpanDown","text":"RoundSpanDown = SpanRoundingMode(RoundDown, RoundDown)\n\nThis is a rounding mode where both ends of the continuous time interval are rounded downwards.\n\nExample\n\nConsider a signal with sample rate 1 Hz.\n\nIndex       1   2   3   4   5\nTime (s)    0   1   2   3   4\n\nNow, consider the time span 1.5s (inclusive) to 2.5s (exclusive). Using brackets to highlight this span:\n\nIndex       1   2     3     4   5\nTime (s)    0   1  [  2  )  3   4\n\nIn code, this span is described by\n\njulia> using AlignedSpans, Dates, TimeSpans\n\njulia> ts = TimeSpan(Millisecond(1500), Millisecond(2500))\nTimeSpan(00:00:01.500000000, 00:00:02.500000000)\n\nIf we round both ends of the interval down to the nearest sample, the start of the interval becomes 1s, and the stop of the interval becomes 2s. Thus, the associated samples are at indices 2:3. And indeed,\n\njulia> aligned = AlignedSpan(1, ts, RoundSpanDown)\nAlignedSpan(1.0, 2, 3)\n\njulia> AlignedSpans.indices(aligned)\n2:3\n\ngives an AlignedSpan with indices 2:3.\n\n\n\n\n\n","category":"constant"},{"location":"API/#AlignedSpans.AlignedSpan-Tuple{Any, Any, SpanRoundingMode}","page":"API Documentation","title":"AlignedSpans.AlignedSpan","text":"AlignedSpan(sample_rate, span, mode::SpanRoundingMode)\n\nCreates an AlignedSpan by rounding the left endpoint according to mode.start, and the right endpoint by mode.stop.\n\nIf mode.start==RoundUp, then the left index of the resulting span is guaranteed to be inside span. This is accomplished by checking if the left endpoint of the span is exclusive, and if so, incrementing the index after rounding when necessary.\n\nLikewise, if mode.start==RoundDown, then the right index of the resulting span is guaranteed to be inside span. This is accomplished by checking if the right endpoint of the span is exclusive, and if so, decrementing the index after rounding when necessary.\n\nNote: span may be of any type which which provides methods for AlignedSpans.start_index_from_time and AlignedSpans.stop_index_from_time.\n\n\n\n\n\n","category":"method"},{"location":"API/#AlignedSpans.ConstantSamplesRoundingMode","page":"API Documentation","title":"AlignedSpans.ConstantSamplesRoundingMode","text":"ConstantSamplesRoundingMode(start::RoundingMode)\n\nCreates a rounding object for AlignedSpan to indicate the AlignedSpan should be constructed by the start and duration of the span, without regard to its stop.\n\nIf two spans have the same duration, then the resulting AlignedSpan's will have the same number of samples when constructed with this rounding mode.\n\nSee also AlignedSpan(sample_rate, span, mode::ConstantSamplesRoundingMode).\n\n\n\n\n\n","category":"type"},{"location":"API/#AlignedSpans.AlignedSpan-Tuple{Any, Any, ConstantSamplesRoundingMode}","page":"API Documentation","title":"AlignedSpans.AlignedSpan","text":"AlignedSpan(sample_rate, span, mode::ConstantSamplesRoundingMode)\n\nCreates an AlignedSpan whose left endpoint is rounded according to mode.start, and whose right endpoint is determined so by the left endpoint and the number of samples, given by AlignedSpans.n_samples(sample_rate, duration(span)).\n\nInterface: span may be of any type which which provides a method for AlignedSpans.start_index_from_time and TimeSpans.duration.\n\nMore detailed information\n\nThis is designed so that if AlignedSpan(sample_rate, span, mode::ConstantSamplesRoundingMode) is applied to multiple spans, with the same sample_rate, and the same durations, then the resulting AlignedSpan's will have the same number of samples.\n\nFor this reason, we ask for TimeSpans.duration(span) to be defined, rather than a n_samples(span) function: the idea is that we want to only using the duration and the starting time, rather than the actual number of samples in this particular span.\n\nIn contrast, AlignedSpan(sample_rate, span, RoundInward) provides an AlignedSpan which includes only (and exactly) the samples contained within span.\n\nIf one wants to create a collection of consecutive, non-overlapping, AlignedSpans each with the same number of samples, then use consecutive_subspans instead.\n\n\n\n\n\n","category":"method"},{"location":"API/#AlignedSpans.consecutive_subspans","page":"API Documentation","title":"AlignedSpans.consecutive_subspans","text":"consecutive_subspans(span::AlignedSpan, duration::Period; keep_last=true)\nconsecutive_subspans(span::AlignedSpan, n_window_samples::Int; keep_last=true)\n\nCreates an iterator of AlignedSpan such that each AlignedSpan has consecutive indices which cover the original span's indices (when keep_last=true).\n\nIf keep_last=true (the default behavior), then the last span may have fewer samples than the others, and\n\nEach span has n_window_samples samples (which is calculated as n_samples(span.sample_rate, duration) if duration::Period is supplied), except possibly\n\nthe last one, which may have fewer.\n\nThe number of subspans is given by cld(n_samples(span), n_window_samples),\nThe number of samples in the last subspan is r = rem(n_samples(span), n_window_samples) unless r=0, in which\n\ncase the the last subspan has the same number of samples as the rest, namely n_window_samples.\n\nAll of the indices of span are guaranteed to be covered by exactly one subspan\n\nIf keep_last=false, then all spans will have the same number of samples:\n\nEach span has n_window_samples samples (which is calculated as n_samples(span.sample_rate, duration) if duration::Period is supplied)\nThe number of subspans is given by fld(n_samples(span), n_window_samples)\nThe last part of the span's indices may not be covered (when we can't fit in another subspan of length n_window_samples)\n\n\n\n\n\n","category":"function"},{"location":"API/#AlignedSpans.consecutive_overlapping_subspans","page":"API Documentation","title":"AlignedSpans.consecutive_overlapping_subspans","text":"consecutive_overlapping_subspans(span::AlignedSpan, duration::Period,\n                                 hop_duration::Period)\nconsecutive_overlapping_subspans(span::AlignedSpan, n_window_samples::Int, n_hop_samples::Int)\n\nCreate an iterator of AlignedSpan such that each AlignedSpan has n_window_samples (calculated as n_samples(span.sample_rate, duration) if duration::Period is supplied) samples, shifted by n_hop_samples (calculated as n_samples(span.sample_rate, hop_duration) if hop_duration::Period is supplied) samples between consecutive spans.\n\nwarning: Warning\nWhen n_samples(span) is not an integer multiple of n_window_samples, only AlignedSpans with n_window_samples samples will be returned. This is analgous to consecutive_subspans with keep_last=false, which is not the default behavior for consecutive_subspans.\n\nNote: If hop_duration cannot be represented as an integer number of samples, rounding will occur to ensure that all output AlignedSpans will have the same number of samples. When rounding occurs, the output hop_duration will be: Nanosecond(n_samples(samp_rate, hop_duration) / samp_rate * 1e9)\n\n\n\n\n\n","category":"function"},{"location":"API/#AlignedSpans.n_samples","page":"API Documentation","title":"AlignedSpans.n_samples","text":"n_samples(sample_rate, duration::Union{Period, Dates.CompoundPeriod})\n\nReturns the minimal number of samples that can occur in a span of duration.\n\n\n\n\n\nn_samples(aligned::AlignedSpan)\n\nReturns the number of samples present in the span aligned.\n\n\n\n\n\n","category":"function"},{"location":"API/#AlignedSpans.indices","page":"API Documentation","title":"AlignedSpans.indices","text":"AlignedSpans.indices(span::AlignedSpan) -> UnitRange{Int64}\n\nReturns the sample indices associated to an AlignedSpan.\n\n\n\n\n\n","category":"function"},{"location":"API/#Interface-for-conversion-from-continuous-time-spans","page":"API Documentation","title":"Interface for conversion from continuous time spans","text":"","category":"section"},{"location":"API/","page":"API Documentation","title":"API Documentation","text":"In order to support conversion of continuous time span types to AlignedSpan's, three methods may be defined. These are not exported, because they are generally not used directly, but rather defined in order to facilitate use of the AlignedSpan constructors.","category":"page"},{"location":"API/","page":"API Documentation","title":"API Documentation","text":"AlignedSpans.start_index_from_time\nAlignedSpans.stop_index_from_time","category":"page"},{"location":"API/#AlignedSpans.start_index_from_time","page":"API Documentation","title":"AlignedSpans.start_index_from_time","text":"AlignedSpans.start_index_from_time(sample_rate, span, rounding_mode)\n\nReturns the index of a sample object obtained by rounding the start of span according to rounding_mode.\n\nSee also AlignedSpan(sample_rate, span, mode::SpanRoundingMode) and AlignedSpan(sample_rate, span, mode::ConstantSamplesRoundingMode).\n\n\n\n\n\n","category":"function"},{"location":"API/#AlignedSpans.stop_index_from_time","page":"API Documentation","title":"AlignedSpans.stop_index_from_time","text":"AlignedSpans.stop_index_from_time(sample_rate, span, rounding_mode)\n\nReturns the index of a sample object obtained by rounding the stop of span according to rounding_mode.\n\nSee also AlignedSpan(sample_rate, span, mode::SpanRoundingMode).\n\n\n\n\n\n","category":"function"}]
}

# Generates docs/src/assets/generated/aligned-spans-widget-data.js, consumed
# by docs/src/assets/aligned-spans-widget.js to render the visualization
# widgets embedded in the docs.
#
# Every number here comes from actually calling AlignedSpans/TimeSpans code
# (never hand-computed), so the widget can never show something that
# disagrees with the real package behavior -- including the precision
# nuances (Rational sample rates, etc.) that are the whole point of some of
# these scenarios. The JS side does no rounding/time-conversion math at all;
# it only positions and highlights boxes based on the numbers generated here.

using AlignedSpans, TimeSpans, Dates, JSON

# A single AlignedSpan's index range and its TimeSpan, as plain JSON-able data.
function entry(aligned::AlignedSpan)
    ts = TimeSpan(aligned)
    return Dict(
        "first_index" => aligned.first_index,
        "last_index" => aligned.last_index,
        "timespan_start_ns" => Dates.value(TimeSpans.start(ts)),
        "timespan_stop_ns" => Dates.value(TimeSpans.stop(ts)),
    )
end

# Precomputed {index, time_ns} pairs covering `indices`, with `pad` samples
# of padding on the low end and `pad + 1` on the high end (the extra sample
# on the high end lets the renderer draw the "next sample" boundary needed
# for span-style, e.g. RoundFullyContainedSampleSpans, rendering).
function window_for(sample_rate, indices; pad=2)
    lo = minimum(indices) - pad
    hi = maximum(indices) + pad + 1
    return [
        Dict("index" => i, "time_ns" => Dates.value(AlignedSpans.time_from_index(sample_rate, i)))
        for i in lo:hi
    ]
end

function span_dict(ts::TimeSpan)
    return Dict(
        "start_ns" => Dates.value(TimeSpans.start(ts)),
        "stop_ns" => Dates.value(TimeSpans.stop(ts)),
    )
end

all_indices(aligneds) = vcat([[a.first_index, a.last_index] for a in aligneds]...)

scenarios = Dict{String, Any}()

# "Sample index -> Time", index.md / decisions.md: plain index range, no rounding.
let
    rate = 1
    aligned = AlignedSpan(rate, 2:3)
    scenarios["index-to-time"] = Dict(
        "sample_rate" => string(rate),
        "input_span" => nothing,
        "window" => window_for(rate, [2, 3]),
        "results" => Dict("given" => [entry(aligned)]),
    )
end

# The "span looks larger after rounding" warning, index.md; also the
# hypnograms section, examples.md.
let
    rate = 1 // 30
    input = TimeSpan(0, Second(30) + Nanosecond(1))
    modes = Dict(
        "RoundInward" => AlignedSpan(rate, input, RoundInward),
        "RoundSpanDown" => AlignedSpan(rate, input, RoundSpanDown),
        "RoundFullyContainedSampleSpans" => AlignedSpan(rate, input, RoundFullyContainedSampleSpans),
    )
    scenarios["rounding-grows-span"] = Dict(
        "sample_rate" => string(rate),
        "input_span" => span_dict(input),
        "window" => window_for(rate, all_indices(values(modes))),
        "results" => Dict(k => [entry(v)] for (k, v) in modes),
    )
end

# EEG / instant-like samples and Onda-indexing sections, examples.md;
# "Rounding modes: why four" section, decisions.md uses a shorter span --
# see "decisions-modes-example" below.
let
    rate = 1
    input = TimeSpan(Millisecond(1500), Millisecond(3500))
    modes = Dict(
        "RoundSpanDown" => AlignedSpan(rate, input, RoundSpanDown),
        "RoundInward" => AlignedSpan(rate, input, RoundInward),
    )
    scenarios["eeg-onda-indexing"] = Dict(
        "sample_rate" => string(rate),
        "input_span" => span_dict(input),
        "window" => window_for(rate, all_indices(values(modes))),
        "results" => Dict(k => [entry(v)] for (k, v) in modes),
    )
end

# Motivation section, index.md: the plotting-offset example.
let
    rate = 1
    input = TimeSpan(Millisecond(1500), Millisecond(4000))
    aligned = AlignedSpan(rate, input, RoundSpanDown)
    scenarios["motivation-offset"] = Dict(
        "sample_rate" => string(rate),
        "input_span" => span_dict(input),
        "window" => window_for(rate, [aligned.first_index, aligned.last_index]),
        "results" => Dict("RoundSpanDown" => [entry(aligned)]),
    )
end

# "Rounding modes: why four, and how they're named", decisions.md.
let
    rate = 1
    input = TimeSpan(Millisecond(1500), Millisecond(2500))
    modes = Dict(
        "RoundSpanDown" => AlignedSpan(rate, input, RoundSpanDown),
        "RoundInward" => AlignedSpan(rate, input, RoundInward),
    )
    scenarios["decisions-modes-example"] = Dict(
        "sample_rate" => string(rate),
        "input_span" => span_dict(input),
        "window" => window_for(rate, all_indices(values(modes))),
        "results" => Dict(k => [entry(v)] for (k, v) in modes),
    )
end

# "Getting a consistent number of samples across spans", examples.md: two
# same-duration spans, one scenario each so both can be shown side by side.
for (name, input) in (
        "constant-samples-1" => TimeSpan(Millisecond(0), Millisecond(700)),
        "constant-samples-2" => TimeSpan(Millisecond(100), Millisecond(800)),
    )
    rate = 3
    modes = Dict(
        "RoundInward" => AlignedSpan(rate, input, RoundInward),
        "ConstantSamplesRoundingMode" => AlignedSpan(rate, input, ConstantSamplesRoundingMode(RoundDown)),
    )
    scenarios[name] = Dict(
        "sample_rate" => string(rate),
        "input_span" => span_dict(input),
        "window" => window_for(rate, all_indices(values(modes))),
        "results" => Dict(k => [entry(v)] for (k, v) in modes),
    )
end

# "Splitting a span into fixed-size or sliding windows", examples.md;
# `keep_last` deferred-decision entry, decisions.md.
let
    rate = 1
    base = AlignedSpan(rate, 1:10)
    windows = collect(consecutive_subspans(base, 3))
    windows_keep_last_false = collect(consecutive_subspans(base, 3; keep_last=false))
    windows_overlapping = collect(consecutive_overlapping_subspans(base, 3, 2))
    all_spans = vcat(windows, windows_keep_last_false, windows_overlapping)
    scenarios["windowing"] = Dict(
        "sample_rate" => string(rate),
        "input_span" => nothing,
        "window" => window_for(rate, all_indices(all_spans)),
        "results" => Dict(
            "windows" => [entry(w) for w in windows],
            "windows-keep-last-false" => [entry(w) for w in windows_keep_last_false],
            "windows-overlapping" => [entry(w) for w in windows_overlapping],
        ),
    )
end

# "Spans that start before or run past your recording", examples.md: direct
# out-of-range index construction (no rounding involved).
let
    rate = 1
    aligned = AlignedSpan(rate, -5:10)
    scenarios["out-of-range-raw"] = Dict(
        "sample_rate" => string(rate),
        "input_span" => nothing,
        "window" => window_for(rate, [aligned.first_index, aligned.last_index]),
        "results" => Dict("given" => [entry(aligned)]),
    )
end

# Negative-`sample_time` deferred-decision entry, decisions.md; issue #15's
# original MWE (constructing from a TimeSpan with a negative start time).
let
    rate = 1238
    input = TimeSpan(Nanosecond(-32), Nanosecond(2))
    aligned = AlignedSpan(rate, input, RoundSpanDown)
    scenarios["out-of-range-timespan"] = Dict(
        "sample_rate" => string(rate),
        "input_span" => span_dict(input),
        "window" => window_for(rate, [aligned.first_index, aligned.last_index]),
        "results" => Dict("RoundSpanDown" => [entry(aligned)]),
    )
end

# "Shifting a span in time", examples.md; `TimeSpans.translate`
# deferred-decision entry, decisions.md.
let
    rate = 3
    original = AlignedSpan(rate, 1:10)
    n = n_samples(rate, Second(1))
    shifted = AlignedSpan(rate, (original.first_index + n):(original.last_index + n))
    scenarios["shifting"] = Dict(
        "sample_rate" => string(rate),
        "input_span" => nothing,
        "window" => window_for(rate, all_indices([original, shifted])),
        "results" => Dict(
            "original" => [entry(original)],
            "shifted" => [entry(shifted)],
        ),
    )
end

generated_dir = joinpath(@__DIR__, "src", "assets", "generated")
mkpath(generated_dir)
open(joinpath(generated_dir, "aligned-spans-widget-data.js"), "w") do io
    write(io, "// Generated by docs/widget_data.jl -- do not edit, and do not commit.\n")
    write(io, "window.ALIGNED_SPANS_SCENARIOS = ")
    JSON.print(io, scenarios)
    write(io, ";\n")
end

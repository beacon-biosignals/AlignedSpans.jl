// Renders the `.aligned-spans-widget` elements embedded in the AlignedSpans.jl
// docs. This file does no rounding/time-conversion math of its own: every
// number it draws (sample times, resulting index ranges, resulting
// TimeSpans) comes from `window.ALIGNED_SPANS_SCENARIOS`, generated at
// doc-build time by docs/widget_data.jl using the real AlignedSpans package.
// This file only positions and colors boxes based on those numbers.
(function () {
    "use strict";

    var NAMED_COLORS = {
        RoundSpanDown: "#2b6cb0",
        RoundInward: "#c05621",
        RoundFullyContainedSampleSpans: "#2f855a",
        ConstantSamplesRoundingMode: "#805ad5",
        given: "#4a5568",
        original: "#2b6cb0",
        shifted: "#c05621",
    };
    var PALETTE = ["#2b6cb0", "#c05621", "#2f855a", "#805ad5", "#b83280", "#b7791f"];

    function colorFor(groupName, indexInList, listLength) {
        if (listLength > 1) {
            return PALETTE[indexInList % PALETTE.length];
        }
        return NAMED_COLORS[groupName] || PALETTE[0];
    }

    function isSpanStyle(groupName) {
        return /FullyContained/i.test(groupName);
    }

    function formatNs(ns) {
        var s = ns / 1e9;
        var str = s.toFixed(3).replace(/\.?0+$/, "");
        if (str === "" || str === "-") {
            str = "0";
        }
        return str + "s";
    }

    function el(tag, className, style) {
        var e = document.createElement(tag);
        if (className) e.className = className;
        if (style) {
            for (var k in style) {
                if (Object.prototype.hasOwnProperty.call(style, k)) {
                    e.style[k] = style[k];
                }
            }
        }
        return e;
    }

    // Builds the list of {name, range, color} entries to draw, from the
    // scenario's `results` and the requested group names.
    function activeRanges(scenario, groupNames) {
        var out = [];
        groupNames.forEach(function (name) {
            var list = scenario.results[name];
            if (!list) return;
            list.forEach(function (range, i) {
                out.push({
                    name: name,
                    label: list.length > 1 ? name + " #" + (i + 1) : name,
                    range: range,
                    color: colorFor(name, i, list.length),
                    spanStyle: isSpanStyle(name),
                });
            });
        });
        return out;
    }

    function drawFigure(scenario, groupNames) {
        var window_ = scenario.window;
        var ranges = activeRanges(scenario, groupNames);

        var minT = Math.min.apply(
            null,
            window_.map(function (w) {
                return w.time_ns;
            })
        );
        var maxT = Math.max.apply(
            null,
            window_.map(function (w) {
                return w.time_ns;
            })
        );
        if (scenario.input_span) {
            minT = Math.min(minT, scenario.input_span.start_ns);
            maxT = Math.max(maxT, scenario.input_span.stop_ns);
        }
        ranges.forEach(function (r) {
            minT = Math.min(minT, r.range.timespan_start_ns);
            maxT = Math.max(maxT, r.range.timespan_stop_ns);
        });
        if (maxT === minT) {
            maxT = minT + 1;
        }

        var pad = 24;
        var width = Math.max(420, window_.length * 46);
        var innerWidth = width - 2 * pad;

        function xFor(t) {
            return pad + ((t - minT) / (maxT - minT)) * innerWidth;
        }

        var figure = el("div", "asw-figure", { width: width + "px" });

        // Input span band.
        if (scenario.input_span) {
            var x0 = xFor(scenario.input_span.start_ns);
            var x1 = xFor(scenario.input_span.stop_ns);
            var band = el("div", "asw-input-span", {
                left: x0 + "px",
                width: Math.max(2, x1 - x0) + "px",
            });
            figure.appendChild(band);
            var spanLabel = el("div", "asw-input-span-label", { left: x0 + "px" });
            spanLabel.textContent =
                "input span: [" + formatNs(scenario.input_span.start_ns) + ", " + formatNs(scenario.input_span.stop_ns) + ")";
            figure.appendChild(spanLabel);
        }

        // Sample-as-span bands (e.g. RoundFullyContainedSampleSpans).
        var byIndex = {};
        window_.forEach(function (w) {
            byIndex[w.index] = w.time_ns;
        });
        ranges
            .filter(function (r) {
                return r.spanStyle;
            })
            .forEach(function (r) {
                for (var i = r.range.first_index; i <= r.range.last_index; i++) {
                    if (byIndex[i] === undefined || byIndex[i + 1] === undefined) continue;
                    var bx0 = xFor(byIndex[i]);
                    var bx1 = xFor(byIndex[i + 1]);
                    var b = el("div", "asw-span-band", {
                        left: bx0 + "px",
                        width: Math.max(2, bx1 - bx0) + "px",
                        background: r.color,
                        borderLeft: "2px solid " + r.color,
                    });
                    figure.appendChild(b);
                }
            });

        // Axis track.
        figure.appendChild(el("div", "asw-track"));

        // Dots + index/time labels.
        function colorForIndex(idx) {
            var c = null;
            ranges.forEach(function (r) {
                if (idx >= r.range.first_index && idx <= r.range.last_index) {
                    c = r.color;
                }
            });
            return c;
        }
        window_.forEach(function (w) {
            var x = xFor(w.time_ns);
            var c = colorForIndex(w.index);
            var dot = el("div", "asw-dot", { left: x + "px" });
            if (c) {
                dot.style.background = c;
                dot.style.borderColor = c;
            }
            figure.appendChild(dot);

            var idxLabel = el("div", "asw-index-label", { left: x + "px" });
            idxLabel.textContent = String(w.index);
            figure.appendChild(idxLabel);

            var tLabel = el("div", "asw-tick-label", { left: x + "px" });
            tLabel.textContent = formatNs(w.time_ns);
            figure.appendChild(tLabel);
        });

        // Result brackets (the resulting TimeSpan for each active group).
        // Each group gets its own row, tall enough that the label text of one
        // row doesn't run into the bracket line of the next.
        var BRACKET_ROW_HEIGHT = 34;
        var BRACKET_FIRST_Y = 116;
        ranges.forEach(function (r, i) {
            var bx0 = xFor(r.range.timespan_start_ns);
            var bx1 = xFor(r.range.timespan_stop_ns);
            var y = BRACKET_FIRST_Y + i * BRACKET_ROW_HEIGHT;
            var bracket = el("div", "asw-bracket", {
                left: bx0 + "px",
                width: Math.max(2, bx1 - bx0) + "px",
                top: y + "px",
                background: r.color,
            });
            figure.appendChild(bracket);
            var label = el("div", "asw-bracket-label", {
                left: bx0 + "px",
                top: y + 6 + "px",
                color: r.color,
            });
            label.textContent =
                r.label + ": [" + formatNs(r.range.timespan_start_ns) + ", " + formatNs(r.range.timespan_stop_ns) + ")";
            figure.appendChild(label);
        });

        figure.style.height = BRACKET_FIRST_Y + ranges.length * BRACKET_ROW_HEIGHT + 10 + "px";

        return { figure: figure, ranges: ranges };
    }

    function drawLegend(scenario, ranges) {
        var legend = el("div", "asw-legend");
        var rate = el("div", "asw-legend-item");
        rate.innerHTML = "<strong>sample rate:</strong>&nbsp;" + scenario.sample_rate + " Hz";
        legend.appendChild(rate);
        ranges.forEach(function (r) {
            var item = el("div", "asw-legend-item");
            var swatch = el("span", "asw-swatch", { background: r.color });
            item.appendChild(swatch);
            var text = el("span");
            text.textContent =
                r.label + ": indices " + r.range.first_index + ":" + r.range.last_index;
            item.appendChild(text);
            legend.appendChild(item);
        });
        return legend;
    }

    function render(container, scenarioName, groupNames) {
        var data = window.ALIGNED_SPANS_SCENARIOS || {};
        var scenario = data[scenarioName];
        var target = container.querySelector(".asw-render-target");
        target.innerHTML = "";
        if (!scenario) {
            target.textContent = "Unknown scenario: " + scenarioName;
            return;
        }
        if (!groupNames || groupNames.length === 0) {
            groupNames = Object.keys(scenario.results);
        }
        var built = drawFigure(scenario, groupNames);
        target.appendChild(built.figure);
        target.appendChild(drawLegend(scenario, built.ranges));
    }

    function initStatic(container) {
        var scenarioName = container.getAttribute("data-scenario");
        var groupNames = (container.getAttribute("data-results") || "")
            .split(",")
            .map(function (s) {
                return s.trim();
            })
            .filter(Boolean);
        var target = el("div", "asw-render-target");
        container.appendChild(target);
        render(container, scenarioName, groupNames);
    }

    function init() {
        var widgets = document.querySelectorAll(".aligned-spans-widget");
        widgets.forEach(initStatic);
    }

    if (document.readyState === "loading") {
        document.addEventListener("DOMContentLoaded", init);
    } else {
        init();
    }
})();

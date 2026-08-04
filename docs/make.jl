using AlignedSpans
using Documenter

# We pregenerate some JSON containing time-index conversions
# to use in our little js widget to display in the docs.
include("widget_data.jl")

makedocs(; modules=[AlignedSpans],
         sitename="AlignedSpans",
         authors="Beacon Biosignals, Inc.",
         format=Documenter.HTML(; assets=["assets/aligned-spans-widget.css",
                                           "assets/generated/aligned-spans-widget-data.js",
                                           "assets/aligned-spans-widget.js"]),
         pages=["Introduction" => "index.md",
                "Examples" => "examples.md",
                "API Documentation" => "API.md",
                "Design Decisions" => "decisions.md"])

deploydocs(; repo="github.com/beacon-biosignals/AlignedSpans.jl.git",
           devbranch="main",
           push_preview=true)

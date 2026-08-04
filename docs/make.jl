using AlignedSpans
using Documenter

makedocs(; modules=[AlignedSpans],
         sitename="AlignedSpans",
         authors="Beacon Biosignals, Inc.",
         pages=["Introduction" => "index.md",
                "Examples" => "examples.md",
                "API Documentation" => "API.md",
                "Design Decisions" => "decisions.md"])

deploydocs(; repo="github.com/beacon-biosignals/AlignedSpans.jl.git",
           devbranch="main",
           push_preview=true)

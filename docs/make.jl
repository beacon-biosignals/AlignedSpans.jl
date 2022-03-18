using AlignedSpans
using Documenter

makedocs(; modules=[AlignedSpans],
         sitename="AlignedSpans",
         authors="Beacon Biosignals, Inc.",
         pages=["Introduction" => "index.md",
                "API Documentation" => "API.md"])

deploydocs(; repo="github.com/beacon-biosignals/AlignedSpans.jl.git",
           devbranch="main",
           push_preview=true)

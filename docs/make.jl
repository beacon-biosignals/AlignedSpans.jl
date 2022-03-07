using AlignedSpans
using Documenter

makedocs(modules=[AlignedSpans],
         sitename="AlignedSpans",
         authors="Beacon Biosignals, Inc.",
         pages=["API Documentation" => "index.md"])

deploydocs(repo="github.com/beacon-biosignals/AlignedSpans.jl.git",
           devbranch="main",
           push_preview=true)

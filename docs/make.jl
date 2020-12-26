using InformationDistances
using Documenter

makedocs(;
    modules=[InformationDistances],
    authors="Simon Schoelly <sischoel@gmail.com> and contributors",
    repo="https://github.com/simonschoelly/InformationDistances.jl/blob/{commit}{path}#L{line}",
    sitename="InformationDistances.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://simonschoelly.github.io/InformationDistances.jl",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/simonschoelly/InformationDistances.jl",
)

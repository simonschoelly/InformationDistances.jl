# InformationDistances

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://simonschoelly.github.io/InformationDistances.jl/stable)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://simonschoelly.github.io/InformationDistances.jl/dev)
[![Build Status](https://github.com/simonschoelly/InformationDistances.jl/workflows/CI/badge.svg)](https://github.com/simonschoelly/InformationDistances.jl/actions)
[![Coverage](https://codecov.io/gh/simonschoelly/InformationDistances.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/simonschoelly/InformationDistances.jl)

This package contains methods to calculate the [Normalized Compression Distance (NCD)](https://en.wikipedia.org/wiki/Normalized_compression_distance) - a metric for measuring how similar two strings are using a real life compression algorithm such as [bzip2](https://en.wikipedia.org/wiki/Bzip2).

## Installation

InformationDistances.jl is registered in the [general registry](https://github.com/JuliaRegistries/General) and can therefore be simply installed from the REPL with
```julia
] add InformationDistances
```

## Quick example

```julia
julia> using InformationDistances

# Create three strings that we want to compare - we expect s1 and s2 to be more similar than any of them to s3
julia> s1 = repeat("ab", 100)
"abababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababab"

julia> s2 = repeat("ba", 100)
"babababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababababa"

julia> s3 = String(rand(('a', 'b'), 200))
"aabaaabaaababaabababbaaaaabaaaaaabbabbaaabbbabbbbaaaaababaabbbbaababbbbaaaaaaaaabababaaabbbbbbbabbbaabbabababbaababbbbabbbababaaaababaaababbababaaaaababbabbbbaabbaabbbaabaababbbaaaaaababbbabbbabbabbaa"

# Create a normalized compression distance with the default parameters
julia> d = NormalizedCompressionDistance();

julia> d(s1, s2)
0.125

julia> d(s1, s3)
0.4482758620689655

julia> d(s2, s3)
0.4482758620689655

# Create annother distance that uses Bzip2 for compression
julia> using CodecBzip2: Bzip2Compressor

julia> d_bzip2 = NormalizedCompressionDistance(CodecCompressor{Bzip2Compressor}(workfactor=250));

julia> d_bzip2(s1, s2)
0.1

julia> d_bzip2(s1, s3)
0.5903614457831325

julia> d_bzip2(s2, s3)
0.5783132530120482
```

## References
[Li, Ming, Xin Chen, Xin Li, Bin Ma, and Paul MB Vitányi. "The similarity metric." IEEE transactions on Information Theory 50, no. 12 (2004): 3250-3264.](https://homepages.cwi.nl/~paulv/papers/similarity.pdf)

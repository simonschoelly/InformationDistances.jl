module InformationDistances

using Distances: PreMetric
import CodecXz
import TranscodingStreams


using LibDeflate

export NormalizedCompressionDistance, LibDeflateCompressor, CodecCompressor,
        compressed_length, compressed_lengths

include("compressors.jl")


"""
    NormalizedCompressionDistance{<: AbstractCompressor} <: Distances.PreMetric

A `normalized compression distance` metric between two strings.

The metric is defined by ``d(x, y) := \\frac{Z(xy) - \\min(Z(x), Z(y))} {\\max(Z(x), Z(y))}``

where `Z(x)` is the length when compressing the string `x` with a certain compression codec.

----

    NormalizedCompressionDistance(, [compressor::AbstractCompressor])

Create a `NormalizedCompressionDistance`.

# Arguments
- `compressor` The compressor to use. If not specified,
    `CodecCompressor{CodecXz.XzCompressor}(;level=9; check=CodecXz.LZMA_CHECK_NONE)` is used.

# Examples
```jldoctest
julia> d1 = NormalizedCompressionDistance()
NormalizedCompressionDistance{CodecCompressor{CodecXz.XzCompressor}}(CodecCompressor{CodecXz.XzCompressor}(Base.Iterators.Pairs{Symbol,Signed,Tuple{Symbol,Symbol},NamedTuple{(:level, :check),Tuple{Int64,Int32}}}(:level => 9,:check => 0)))

julia> d1("hello", "world")
0.07142857142857142

julia> d2 = NormalizedCompressionDistance(LibDeflateCompressor())
NormalizedCompressionDistance{LibDeflateCompressor}(LibDeflateCompressor(12))

julia> d2("hello", "world")
0.5
```
"""
struct NormalizedCompressionDistance{C <: AbstractCompressor} <: PreMetric

    compressor::C

    function NormalizedCompressionDistance(compressor=
            CodecCompressor{CodecXz.XzCompressor}(;level=9, check=CodecXz.LZMA_CHECK_NONE))

        return new{typeof(compressor)}(compressor)
    end
end

function (dist::NormalizedCompressionDistance)(x::AbstractString, y::AbstractString)

    x == y && return 0.0

    compressor = dist.compressor

    len_xy, len_x, len_y = compressed_lengths(compressor, (x * y, x, y))

    return clamp(Float64((len_xy - min(len_x, len_y)) / max(len_x, len_y)), 0.0, 1.0)
end

end # module

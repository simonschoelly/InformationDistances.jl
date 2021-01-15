
"""
    const ByteData = Union{Vector{UInt8}, Base.CodeUnits{UInt8, <: AbstractString}}

Either a Vector of `UInt8` or a `Base.CodeUnit{UInt8}` object. Compressors
should be able to compress both of these types.
"""
const ByteData = Union{Vector{UInt8}, Base.CodeUnits{UInt8, <: AbstractString}}


# ---------------------------
#    AbstractCompressor
# ---------------------------

"""
    AbstractCompressor

A compressor interface type that represent string compressors.

# Mandatory methods
- compressed_length( <: AbstractCompressor, ::InformationDistances.ByteData)

# Optional methods
- compressed_lengths( <: AbstractCompressor, iter)
"""
abstract type AbstractCompressor end


"""
    compressed_length(compressor, s)

The number of resulting bytes when `s` is compressed with `compressor`.

When implementing a subtype `Compressor <: AbstractCompressor` one should implement
`compressed_length(compressor::Compressor, s::InformationDistances.ByteData)

# Examples
```jldoctest
julia> compressed_length(LibDeflateCompressor(), "hello")
10
```
"""
function compressed_length(compressor::AbstractCompressor, s::AbstractString)

    return compressed_length(compressor, collect(codeunits(s)))
end


"""
    compressed_lengths(compressor, iter)

Calculate for each `s` in `iter` the number of resulting bytes when `s` is compressed with `compressor`.

Implementing this method for a specific subtype of `AbstractCompressor` might lead
to some performance improvements as some compressors need to allocate some resources before
compressing, therefore batch processing might lead to performance improvements as
the resources have to be allocated only once.

It is recommended but not necessary to implement this method for a custom subtype
`Compressor <: AbstractCompressor`. The method signature in that case should be
`compressed_lengths(compressor::Compressor, iter)`.

As Julia does not allow one to specify the eltype of an iterator, one should make at least
sure, that the elements of `iter` can be of type `InformationDistances.ByteData` and optionally
could also be of type `AbstractString`.

# Examples
```jldoctest
julia> compressed_lengths(LibDeflateCompressor(), ["hello", "world", "!"])
3-element Array{Int64,1}:
 10
 10
  6
```
"""
function compressed_lengths(compressor, iter)

    return map(s -> compressed_length(compressor, s), iter)
end


# ---------------------------
#    LibDeflateCompressor
# ---------------------------

"""
    LibDeflateCompressor <: AbstractCompressor

A compressor that uses a `LibDeflate.jl` for compressing.

-----

    LibDeflateCompressor(;compresslevel=12)

Create a `LibDeflateCompressor` with compression level `compresslevel`.

# Examples
```jldoctest
julia> LibDeflateCompressor()
LibDeflateCompressor(12)

julia> LibDeflateCompressor(;compresslevel=8)
LibDeflateCompressor(8)
```
"""
struct LibDeflateCompressor <: AbstractCompressor

    compresslevel::Int

    function LibDeflateCompressor(;compresslevel=12)

        return new(compresslevel)
    end
end


function compressed_length(compressor::LibDeflateCompressor, s::ByteData)

    compressor = LibDeflate.Compressor(compressor.compresslevel)

    outvector = Vector{UInt8}(undef, _deflate_maxoutlen(length(s)))

    @GC.preserve outvector s return unsafe_compress!(
        compressor, pointer(outvector), length(outvector), pointer(s), length(s))
end

function compressed_lengths(compressor::LibDeflateCompressor, iter)

    compressor = LibDeflate.Compressor(compressor.compresslevel)

    outvector = UInt8[]

    return map(iter) do s
        if !(s isa ByteData)
            s = codeunits(s)
        end
        resize!(outvector, max(length(outvector), _deflate_maxoutlen(length(s))))

        @GC.preserve outvector s return unsafe_compress!(
            compressor, pointer(outvector), length(outvector), pointer(s), length(s))
    end
end

function _deflate_maxoutlen(inlen)

    # TODO this calculation is taken from libdeflate, it would maybe be better to call the
    # libdeflate_deflate_compress_bound function directly
    max_num_blocks = max(div(inlen, 10000, RoundUp), 1)
    return (5 * max_num_blocks) + inlen + 9
end


# ---------------------------
#   CodecCompressor
# ---------------------------

"""
    CodecCompressor{ <: TranscodingStreams.Codec} <: AbstractCompressor

A compressor that uses a `TranscodingStreams.Codec` for compressing.

-----

    CodecCompressor{C <: TranscodingStreams.Codec}(;kwargs...)

Create a `CodecCompressor` for the codec `C` with a additional keyword arguments passed
to the constructor of that codec.

# Examples
```jldoctest
julia> using CodecXz: XzCompressor

julia> CodecCompressor{XzCompressor}(; level=6)
CodecCompressor{XzCompressor}(Base.Iterators.Pairs(:level => 6))
```
"""
struct CodecCompressor{C <: TranscodingStreams.Codec} <: AbstractCompressor

    kwargs::Base.Iterators.Pairs

    function CodecCompressor{C}(;kwargs...) where {C}

        return new{C}(kwargs)
    end
end

function compressed_lengths(compressor::CodecCompressor{C}, iter) where {C}

    codec = C(;compressor.kwargs...)
    TranscodingStreams.initialize(codec)

    try
        return map(iter) do s
            if !(s isa ByteData)
                s = codeunits(s)
            end
            length(transcode(codec, s))
        end
    catch
        rethrow()
    finally
        TranscodingStreams.finalize(codec)
    end
end

function compressed_length(compressor::CodecCompressor{C}, s::ByteData) where {C}

    codec = C(;compressor.kwargs...)
    TranscodingStreams.initialize(codec)
    try
        return length(transcode(codec, s))
    catch
        rethrow()
    finally
        TranscodingStreams.finalize(codec)
    end
end



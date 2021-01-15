using InformationDistances
using CodecXz: XzCompressor
using TranscodingStreams: Noop

using Test

struct MockCompressor <: InformationDistances.AbstractCompressor end

function InformationDistances.compressed_length(::MockCompressor, data::InformationDistances.ByteData)

    return length(data)
end

s0 = ""
s1 = "x"
s2 = "xy"

@testset "InformationDistances.jl" begin

    @testset "AbstractCompressor interface" begin
        @test compressed_lengths(MockCompressor(), [s0, s1, s2]) ==
            map(s -> compressed_length(MockCompressor(), s), [s0, s1, s2])

        @test compressed_length(MockCompressor(), s2) ==
            compressed_length(MockCompressor(), codeunits(s2))
    end

    @testset "NormalizedCompressionDistance" begin

        @test NormalizedCompressionDistance() isa NormalizedCompressionDistance{CodecCompressor{XzCompressor}}

        @test NormalizedCompressionDistance(MockCompressor()) isa
                NormalizedCompressionDistance{MockCompressor}


        len_s1 = compressed_length(MockCompressor(), s1)
        len_s2 = compressed_length(MockCompressor(), s2)
        len_s1s2 = compressed_length(MockCompressor(), s1 * s2)

        @test NormalizedCompressionDistance(MockCompressor())(s1, s2) ==
            (len_s1s2 - min(len_s1, len_s2)) / max(len_s1, len_s2)

        @test NormalizedCompressionDistance()("", "") == 0.0
        @test NormalizedCompressionDistance()(s2, s2) == 0.0
        # NCD is not symmetric in general, but it should be for the empty string
        @test NormalizedCompressionDistance()("", s2) ==
            NormalizedCompressionDistance()(s2, "")
        @test 0.0 <= NormalizedCompressionDistance()(s1, s2) <= 1.0
    end

    @testset "LibDeflateCompressor" begin

        @test LibDeflateCompressor().compresslevel == 12
        @test LibDeflateCompressor(;compresslevel=5).compresslevel == 5

        compressor = LibDeflateCompressor()

        data_CodeUnits = codeunits.([s0, s1, s2])
        data_Vector = Vector(data_CodeUnits)

        @test compressed_lengths(compressor, data_CodeUnits) ==
              compressed_lengths(compressor, data_Vector) ==
              map(s -> compressed_length(compressor, s), data_CodeUnits) ==
              map(s -> compressed_length(compressor, s), data_Vector)

    end

    @testset "CodecCompressor" begin

        @test CodecCompressor{Noop}() isa CodecCompressor{Noop}
        @test collect(CodecCompressor{Noop}(arg1="1", arg2=2).kwargs) ==
            [:arg1 => "1", :arg2 => 2]

        compressor = CodecCompressor{Noop}()

        data_CodeUnits = codeunits.([s0, s1, s2])
        data_Vector = Vector(data_CodeUnits)

        @test compressed_lengths(compressor, data_CodeUnits) ==
              compressed_lengths(compressor, data_Vector) ==
              map(s -> compressed_length(compressor, s), data_CodeUnits) ==
              map(s -> compressed_length(compressor, s), data_Vector)

    end

end

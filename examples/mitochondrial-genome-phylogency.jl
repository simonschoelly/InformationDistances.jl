### A Pluto.jl notebook ###
# v0.12.20

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : missing
        el
    end
end

# ╔═╡ ae20362a-4c60-11eb-2e5a-5b3904d7ef11
begin
	using Pkg
	Pkg.activate(mktempdir())
	Pkg.add("InformationDistances")
	Pkg.add("CodecXz")
	Pkg.add("CodecBzip2")
	Pkg.add("StringDistances")
	Pkg.add("BioServices")
	Pkg.add("EzXML")
	Pkg.add("DataFrames")
	Pkg.add("PlutoUI")
	Pkg.add("Plots")
	Pkg.add("PyPlot")
	Pkg.add(name="PhyloPlots", rev="master")
	Pkg.add(name="PhyloNetworks", version="0.12.0")
end

# ╔═╡ 38a62858-4c67-11eb-312a-cb83457c1b8a
begin
	using InformationDistances
	using CodecXz: XzCompressor
	using CodecBzip2: Bzip2Compressor
	
	# Additional string distances for reference
	import StringDistances
	
	# Loading Mitochondrial DNA
	import BioServices
	import EzXML
	import DataFrames
	
	# Pluto UI elements
	import PlutoUI
	
	# Plotting heatmaps and phylogentic trees
	import Plots
	import PhyloNetworks
	import PhyloPlots
end

# ╔═╡ 8fb6f778-63d3-11eb-37bd-81c244553b6c
md"""
# Mitochondrial Genome Phylogency

This notebook tries to replicate a result from [1] where the autors used the [Normalized Compression Distance](https://en.wikipedia.org/wiki/Normalized_compression_distance) to calculate pairwaise distaces between the mitochondrial DNA of various animals and then uses these distances to create a [phylogenetic tree](https://en.wikipedia.org/wiki/Phylogenetic_tree).

Note that the results here might be slightly different from the paper as we do not use the exact same string compressors, and the algorithm used to reconstruct the phylogenetic tree might also be slightly different.
"""

# ╔═╡ a08db6ca-63dc-11eb-2d6f-99961e06ef3c
md"""
## Setup
We load a bunch of packages, this might take a while...
"""

# ╔═╡ dca8b740-63dc-11eb-2bd6-2753b38c90f8
md"""
We start by loading the mitochondiral DNA of 20 different animals from [nuccore](https://www.ncbi.nlm.nih.gov/nucleotide/). Using the `efetch` function from [BioServices.jl](https://github.com/BioJulia/BioServices.jl) this is a very easy thing to do, one has just to know the correct sequence id for each animal.
"""

# ╔═╡ 2b43945a-53f6-11eb-3555-7509d07e5fe4
mitochondrial_dna_sources = DataFrames.DataFrame([
	(name = "rat", sequence_id = "NC_001665.2"),
	(name = "house mouse", sequence_id = "NC_005089.1"),
	(name = "gray seal", sequence_id = "NC_001602.1"),
	(name = "harbor seal", sequence_id = "NC_001325.1"),
	(name = "cat", sequence_id = "NC_001700.1"),
	(name = "white rhino", sequence_id = "NC_001808.1"),
	(name = "horse", sequence_id = "NC_001640.1"),
	(name = "finback whale", sequence_id = "NC_001321.1"),
	(name = "blue whale", sequence_id = "NC_001601.1"),
	(name = "cow", sequence_id = "NC_006853.1"),
	(name = "gibbon", sequence_id = "NC_002082.1"),
	(name = "gorilla", sequence_id = "NC_001645.1"),
	(name = "human", sequence_id = "NC_012920.1"),
	(name = "chimpanzee", sequence_id = "NC_001643.1"),
	(name = "pigmy chimpanzee", sequence_id = "NC_001644.1"),
	(name = "orangutan", sequence_id = "NC_001646.1"),
	(name = "Sumatran orangutan", sequence_id = "NC_002083.1"),
	(name = "opossum", sequence_id = "NC_001610.1"),
	(name = "wallaroo", sequence_id = "NC_001794.1"),
	(name = "platypus", sequence_id = "NC_000891.1"),
])

# ╔═╡ 188e2e0e-5404-11eb-04b8-936f9971bd95
animals = map(eachrow(mitochondrial_dna_sources)) do row
	res = EzXML.parsexml(BioServices.EUtils.efetch(
			db = "nuccore", id=row.sequence_id, retmode="xml").body)
	latin_name = EzXML.nodecontent(findfirst("//GBSeq_organism", res))
	dna = EzXML.nodecontent(findfirst("//GBSeq_sequence", res))
	return (name=row.name, latin_name=latin_name, DNA=dna)
end |> DataFrames.DataFrame

# ╔═╡ 3d59590e-63de-11eb-1275-d3545baf1a6f
md"""
## Calculating pairwise distances

The Normalized Compressor Distance uses a loseless string compressor - changing the compressor should have an influence on the quality of the result. 

For comparison we also use the [Levenshtein Distance](https://en.wikipedia.org/wiki/Levenshtein_distance) which is provided by [StringDistances.jl](https://github.com/matthieugomez/StringDistances.jl). Note that the calculations with the Levenshtein Distance might need a few minutes.
"""

# ╔═╡ 564ac642-4c95-11eb-1329-a15bb5b6bef0
@bind distance_key PlutoUI.Radio([
		"default" => "XzCompressor(level = 9) (default)",
		"XzCompressor_level1" => "XzCompressor(level = 1)",
		"Bzip2Compressor" => "Bzip2Compressor",
		"LibDeflateCompressor" => "LibDeflateCompressor",
		"LevenshteinDistance" => "Levenshtein Distance"
], default="default")

# ╔═╡ 5f9ccc3a-4c96-11eb-3857-65954810d179
distance = Dict(
	"default" =>
		NormalizedCompressionDistance(),
	"XzCompressor_level1" =>
		NormalizedCompressionDistance(CodecCompressor{XzCompressor}(; level=1)),
	"Bzip2Compressor" =>
		NormalizedCompressionDistance(CodecCompressor{Bzip2Compressor}(;workfactor=250)),
	"LibDeflateCompressor" =>
		NormalizedCompressionDistance(LibDeflateCompressor()),
	"LevenshteinDistance" => StringDistances.Levenshtein()
)[distance_key]

# ╔═╡ f4c5057a-63de-11eb-0745-293580109763
md"""
We can now compare the distance between some animals. One would expect that rats and mice are much closer than either of them to seals.
"""

# ╔═╡ 9e85ae72-4c97-11eb-2aa4-dfed6f457274
(rat, mouse, seal) = (animals[1, :], animals[2, :], animals[3, :])

# ╔═╡ 49d74218-5416-11eb-0c31-9f1f42fe0498
distance(rat.DNA, mouse.DNA)

# ╔═╡ cbb4f58c-4c6e-11eb-3a82-a38fdbeb1836
distance(rat.DNA, seal.DNA)

# ╔═╡ 26226824-63df-11eb-3650-bdf6ab44a134
md"""
We can now calulate all pairwise distances and visualize the matrix. As close animal groups are already next to each other in the input list, we can immediately spot some clusters.
"""

# ╔═╡ 5894c63e-4c70-11eb-0978-71432cc5cda1
distance_matrix = Float64[distance(x, y) for x in animals[!, :DNA], y in animals[!, :DNA]]

# ╔═╡ 41a44156-4c76-11eb-3675-11ca0568656b
begin
	Plots.pyplot()
	animal_names = replace.(animals[!, :name], ' ' => "\\ ")
	Plots.heatmap(
		animal_names,
		animal_names,
		distance_matrix;
		xtickfontrotation=90,
		yflip=true,
		yticks=:all,
		xticks=:all,
		right_margin=2.5(Plots.mm),
	)
end

# ╔═╡ 51fd3fea-63d6-11eb-2263-196018bcbff6
md"""
## Creating a phylogenetic tree

Finally, we can pass the distance matrix to the `nj!` function from [PhyloNetworks.jl](https://github.com/crsl4/PhyloNetworks.jl) to create a phylogenetic tree and then plot this tree using [PhyloPlots.jl](https://github.com/cecileane/PhyloPlots.jl).
"""

# ╔═╡ 8b6e1a10-4c70-11eb-07d9-113e4f2866a0
begin
	tree = PhyloNetworks.nj!(copy(distance_matrix), collect(animals[!, :name]))
	PhyloPlots.plot(tree)
end

# ╔═╡ ae2812f8-63d2-11eb-2e31-a7e555cb1e24
md"""
## References
[1]: [Li, Ming, Xin Chen, Xin Li, Bin Ma, and Paul MB Vitányi. "The similarity metric." IEEE transactions on Information Theory 50, no. 12 (2004): 3250-3264.](www.google.ch)
"""

# ╔═╡ Cell order:
# ╟─8fb6f778-63d3-11eb-37bd-81c244553b6c
# ╟─a08db6ca-63dc-11eb-2d6f-99961e06ef3c
# ╠═ae20362a-4c60-11eb-2e5a-5b3904d7ef11
# ╠═38a62858-4c67-11eb-312a-cb83457c1b8a
# ╟─dca8b740-63dc-11eb-2bd6-2753b38c90f8
# ╠═2b43945a-53f6-11eb-3555-7509d07e5fe4
# ╠═188e2e0e-5404-11eb-04b8-936f9971bd95
# ╟─3d59590e-63de-11eb-1275-d3545baf1a6f
# ╠═564ac642-4c95-11eb-1329-a15bb5b6bef0
# ╠═5f9ccc3a-4c96-11eb-3857-65954810d179
# ╟─f4c5057a-63de-11eb-0745-293580109763
# ╠═9e85ae72-4c97-11eb-2aa4-dfed6f457274
# ╠═49d74218-5416-11eb-0c31-9f1f42fe0498
# ╠═cbb4f58c-4c6e-11eb-3a82-a38fdbeb1836
# ╟─26226824-63df-11eb-3650-bdf6ab44a134
# ╠═5894c63e-4c70-11eb-0978-71432cc5cda1
# ╠═41a44156-4c76-11eb-3675-11ca0568656b
# ╟─51fd3fea-63d6-11eb-2263-196018bcbff6
# ╠═8b6e1a10-4c70-11eb-07d9-113e4f2866a0
# ╟─ae2812f8-63d2-11eb-2e31-a7e555cb1e24

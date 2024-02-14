### A Pluto.jl notebook ###
# v0.19.28

using Markdown
using InteractiveUtils

# This Pluto notebook uses @bind for interactivity. When running this notebook outside of Pluto, the following 'mock version' of @bind gives bound variables a default value (instead of an error).
macro bind(def, element)
    quote
        local iv = try Base.loaded_modules[Base.PkgId(Base.UUID("6e696c72-6542-2067-7265-42206c756150"), "AbstractPlutoDingetjes")].Bonds.initial_value catch; b -> missing; end
        local el = $(esc(element))
        global $(esc(def)) = Core.applicable(Base.get, el) ? Base.get(el) : iv(el)
        el
    end
end

# ╔═╡ a4aa940e-84c8-483e-a1d5-6fa235ed39b6
begin
	import Pkg; Pkg.activate()
	Pkg.add(["JuMP", "PlutoUI", "Graphs", "GraphMakie", "CairoMakie", "MetaGraphsNext", "HiGHS"])
	using JuMP, PlutoUI, Graphs, GraphMakie, CairoMakie, MetaGraphsNext, HiGHS
end

# ╔═╡ 299ada83-58d2-4bb3-ac21-dd7ce9e3b462
TableOfContents()

# ╔═╡ f60668bc-85c5-4812-bcbb-573adb218956
md"## Optimizing Flow in a Network

The directed graph below represents an oil transportation network. the edges are labeled with capacities for flows. Find the maximum flow from node S to node T.

This type of problem exists in many systems and would fall under the subject known as graph theory. 

This problem represents flowrate values, but these values could represent anything you want to optimize.
"

# ╔═╡ 55d53dc9-e6d0-4d2e-b22f-2604675be3bb
begin
	g = MetaGraph(
		DiGraph(),              # directed graph
		label_type=String,      # node labels are String's
	    edge_data_type=Float64, # edge labels are Float64's
		graph_data="oil pipeline network"
	)
	
	# add vertices
	for v in ["S", "T", "A", "B", "C", "D", "E", "F", "G"]
		add_vertex!(g, v)
	end

	# add edges
	add_edge!(g, "S", "A", 6.0)
	add_edge!(g, "S", "B", 6.0)
	add_edge!(g, "S", "C", 6.0)
	
	add_edge!(g, "A", "D", 4.0)
	add_edge!(g, "A", "E", 1.0)
	add_edge!(g, "A", "B", 2.0)
	
	add_edge!(g, "B", "E", 20.0)

	add_edge!(g, "C", "B", 2.0)
	add_edge!(g, "C", "F", 5.0)

	add_edge!(g, "D", "G", 5.0)
	add_edge!(g, "D", "E", 2.0)

	add_edge!(g, "E", "F", 10.0)
	add_edge!(g, "E", "G", 6.0)

	add_edge!(g, "F", "T", 4.0)

	add_edge!(g, "G", "T", 12.0)

	print("")
end

# ╔═╡ e629e32a-c69d-4e50-a8e4-27c134af82c2
begin
	nodes = collect(labels(g)) # list of nodes
	print("")
end

# ╔═╡ 6272ba29-f291-44b0-9eaa-c9e1c333672c
begin
	edges = collect(edge_labels(g)) # list of edges
	print("")
end

# ╔═╡ 746d8964-1576-4dce-a018-5ab582bb69dd
md"# Pipeline network with example flowrates and solution"

# ╔═╡ 78a36975-51f2-4a74-8905-516ae23b65ac
begin
	fig = Figure()
	ax = Axis(fig[1, 1], title="oil pipeline network")
	hidedecorations!(ax)
	hidespines!(ax)
	graphplot!(
		g.graph, 
		edge_width=3, 
		arrow_size=20,
		node_color="green",
		node_size=30,
		edge_color="gray",
		nlabels=collect(labels(g)),
		nlabels_distance=5.0,
		nlabels_fontsize=25,
		elabels=["$(g[e...])" for e in edge_labels(g)],
		arrow_shift=:end,
	)
	ylims!(nothing, 3.4)
	fig
end

# ╔═╡ 739e9c89-d127-49cb-81d6-a678e0485b62
md"""
#### The following solution was calculated by an optimization algorithm called HiGHS. 
"""

# ╔═╡ df4c7d65-1198-4961-a216-0d8a6b5a8c24
md"""
#### The raw code for the optimizer had been left shown for those interested
"""

# ╔═╡ d24be387-73dc-435d-9e4e-0605b1985b51
flow = Model(HiGHS.Optimizer)

# ╔═╡ d68e247f-8d4f-4f96-82c7-c789a14c288c
#Creates and array that represents all possible connections of nodes
G = zeros(size(nodes,1),size(nodes,1))

# ╔═╡ 3158611c-712a-4fce-ad5c-1356a9a346a1
#Creates a dictionary of the nodes to an integer representation for use in the array
m = Dict("S"=>1, "A"=>2, "B"=>3, "C"=>4, "D"=>5, "E"=>6, "F"=>7, "G"=>8, "T"=>9 )

# ╔═╡ 4b743760-aa6d-4aa9-95d7-7fa921d78bc1
n = size(G,1)

# ╔═╡ 3bf65d86-8f87-495c-98e8-937911fe4e9b
begin
	#assignes the max flow for each actual connection
	for i in edges #i is each 2 element vector of strings in edges
		 #uses the dict m to assign the flow value to its respective element of the array
		G[m[i[1]],m[i[2]]] = g[i[1],i[2]]
	end
	G
end

# ╔═╡ bf7bb1ae-bc99-48c2-81cc-b7dac5901b95
@variable(flow, f[1:n, 1:n] >= 0) #initializes all the flow variables

# ╔═╡ c2360213-12a7-4640-9b4b-5f0b19d43bff
#assignes the max flows from G to the variables
@constraint(flow, [i = 1:n, j = 1:n], f[i, j] <= G[i, j]) 

# ╔═╡ 65700e50-4610-477d-a528-844c1ddb71a4
#makes the constraint that the sum going into a node must equal the sum going out
@constraint(flow, [i = 1:n; i != 1 && i != n], sum(f[i, :]) == sum(f[:, i]))

# ╔═╡ 5e030137-7862-4e67-b2e4-ff9c724cfd90
@objective(flow, Max, sum(f[1, :]))

# ╔═╡ 92d4043a-1514-413a-b3d8-0f77c7d402da
optimize!(flow)

# ╔═╡ cb95e1c3-9309-4727-985d-9adf8f77ca75
md"## Max Flow from S to T"

# ╔═╡ 0afc45e1-edd9-49c2-915d-f0aad0de8829
begin
	
	optimum_ex = objective_value(flow)
	md"""
	 The maximum flow from S to T is $optimum_ex
	"""
end

# ╔═╡ d94b8f55-9316-4b88-a8ee-d859818e7021
optimum_flows = value.(f)

# ╔═╡ 5163c4d4-2922-448e-8824-eafc28ba05ae
md"""
# Problem with random flowrates
"""

# ╔═╡ f4663196-4c6f-495b-87ac-a82036975edb
md"""
Random flows
"""

# ╔═╡ b036c967-66a0-4743-890a-aafb0ccd2e11
begin
	r_flows = rand((1:20),(1,15))
end

# ╔═╡ fc84d0d9-e5f1-4ff6-9468-198c0b98b3f5
begin
	rand_flows = zeros(size(nodes,1),size(nodes,1))
	print("")
end

# ╔═╡ 25c9e64f-f6fb-40a1-8841-98f36e4114bd
begin
	rand_flows[1,2]=r_flows[1]
	rand_flows[1,3]=r_flows[2]
	rand_flows[1,4]=r_flows[3]
	rand_flows[2,5]=r_flows[4]
	rand_flows[2,6]=r_flows[5]
	rand_flows[2,3]=r_flows[6]
	rand_flows[3,6]=r_flows[7]
	rand_flows[4,3]=r_flows[8]
	rand_flows[4,7]=r_flows[9]
	rand_flows[5,8]=r_flows[10]
	rand_flows[5,6]=r_flows[11]
	rand_flows[6,7]=r_flows[12]
	rand_flows[6,8]=r_flows[13]
	rand_flows[7,9]=r_flows[14]
	rand_flows[8,9]=r_flows[15]
	rand_flows
	print("")
end

# ╔═╡ 00bcbe83-1dc1-4d1e-a219-336ba24554a3
begin
	g_rand = MetaGraph(
		DiGraph(),              # directed graph
		label_type=String,      # node labels are String's
	    edge_data_type=Float64, # edge labels are Float64's
		graph_data="oil pipeline network"
	)
	
	# add vertices
	for v in ["S", "T", "A", "B", "C", "D", "E", "F", "G"]
		add_vertex!(g_rand, v)
	end

	# add edges
	add_edge!(g_rand, "S", "A", rand_flows[1,2])
	add_edge!(g_rand, "S", "B", rand_flows[1,3])
	add_edge!(g_rand, "S", "C", rand_flows[1,4])
	
	add_edge!(g_rand, "A", "D", rand_flows[2,5])
	add_edge!(g_rand, "A", "E", rand_flows[2,6])
	add_edge!(g_rand, "A", "B", rand_flows[2,3])
	
	add_edge!(g_rand, "B", "E", rand_flows[3,6])

	add_edge!(g_rand, "C", "B", rand_flows[4,3])
	add_edge!(g_rand, "C", "F", rand_flows[4,7])

	add_edge!(g_rand, "D", "G", rand_flows[5,8])
	add_edge!(g_rand, "D", "E", rand_flows[5,6])

	add_edge!(g_rand, "E", "F", rand_flows[6,7])
	add_edge!(g_rand, "E", "G", rand_flows[6,8])

	add_edge!(g_rand, "F", "T", rand_flows[7,9])

	add_edge!(g_rand, "G", "T", rand_flows[8,9])
	print("")
end

# ╔═╡ 7472e750-b4d6-43c1-8e65-24364757ce2c
md"""
## Solve for max flow from S to T:
"""

# ╔═╡ b38593ba-8c15-4230-a6e9-e8f6c73b7f0d
begin
	fig_rand = Figure()
	ax_rand = Axis(fig_rand[1, 1], title="oil pipeline network")
	hidedecorations!(ax_rand)
	hidespines!(ax_rand)
	graphplot!(
		g_rand.graph, 
		edge_width=3, 
		arrow_size=20,
		node_color="green",
		node_size=30,
		edge_color="gray",
		nlabels=collect(labels(g_rand)),
		nlabels_distance=5.0,
		nlabels_fontsize=25,
		elabels=["$(g_rand[e...])" for e in edge_labels(g_rand)],
		arrow_shift=:end,
	)
	ylims!(nothing, 3.4)
	fig_rand
end

# ╔═╡ 198c8032-082d-4284-b936-4b499de63f84
# ╠═╡ show_logs = false
begin
	rand_flow = Model(HiGHS.Optimizer)
	@variable(rand_flow, rand_f[1:n, 1:n] >= 0) 
	@constraint(rand_flow, [i = 1:n, j = 1:n], rand_f[i, j] <= rand_flows[i, j]) 
	@constraint(rand_flow, [i = 1:n; i != 1 && i != n], sum(rand_f[i, :]) == sum(rand_f[:, i]))
	@objective(rand_flow, Max, sum(rand_f[1, :]))
	optimize!(rand_flow)
end

# ╔═╡ 3aaf6244-41f8-433f-9e23-988677ca5625
begin
optimum_rand_flows = value.(rand_f)
	print("")
end

# ╔═╡ c2318a04-ed89-4c7c-902d-f758e7e1c3aa
begin
	optimal_g_rand = MetaGraph(
		DiGraph(),              # directed graph
		label_type=String,      # node labels are String's
	    edge_data_type=Float64, # edge labels are Float64's
		graph_data="oil pipeline network"
	)
	
	# add vertices
	for v in ["S", "T", "A", "B", "C", "D", "E", "F", "G"]
		add_vertex!(optimal_g_rand, v)
	end

	# add edges
	add_edge!(optimal_g_rand, "S", "A", optimum_rand_flows[1,2])
	add_edge!(optimal_g_rand, "S", "B", optimum_rand_flows[1,3])
	add_edge!(optimal_g_rand, "S", "C", optimum_rand_flows[1,4])
	
	add_edge!(optimal_g_rand, "A", "D", optimum_rand_flows[2,5])
	add_edge!(optimal_g_rand, "A", "E", optimum_rand_flows[2,6])
	add_edge!(optimal_g_rand, "A", "B", optimum_rand_flows[2,3])
	
	add_edge!(optimal_g_rand, "B", "E", optimum_rand_flows[3,6])

	add_edge!(optimal_g_rand, "C", "B", optimum_rand_flows[4,3])
	add_edge!(optimal_g_rand, "C", "F", optimum_rand_flows[4,7])

	add_edge!(optimal_g_rand, "D", "G", optimum_rand_flows[5,8])
	add_edge!(optimal_g_rand, "D", "E", optimum_rand_flows[5,6])

	add_edge!(optimal_g_rand, "E", "F", optimum_rand_flows[6,7])
	add_edge!(optimal_g_rand, "E", "G", optimum_rand_flows[6,8])

	add_edge!(optimal_g_rand, "F", "T", optimum_rand_flows[7,9])

	add_edge!(optimal_g_rand, "G", "T", optimum_rand_flows[8,9])
	print("")
end

# ╔═╡ 36e975b3-bc99-4046-bd28-bb6bf9d1d432
md"""

Enter your solution

S -> A
$@bind s1 NumberField(0:r_flows[1], default=0)

S -> B
$@bind s2 NumberField(0:r_flows[2], default=0)

S -> C 
$@bind s3 NumberField(0:r_flows[3], default=0)

A -> D
$@bind s4 NumberField(0:r_flows[4], default=0)

A -> E
$@bind s5 NumberField(0:r_flows[5], default=0)

A -> B
$@bind s6 NumberField(0:r_flows[6], default=0)

B -> E 
$@bind s7 NumberField(0:r_flows[7], default=0)

C -> B 
$@bind s8 NumberField(0:r_flows[8], default=0)

C -> F 
$@bind s9 NumberField(0:r_flows[9], default=0)

D -> G 
$@bind s10 NumberField(0:r_flows[10], default=0)

D -> E 
$@bind s11 NumberField(0:r_flows[11], default=0)


E -> F
$@bind s12 NumberField(0:r_flows[12], default=0)

E -> G 
$@bind s13 NumberField(0:r_flows[13], default=0)

F -> T
$@bind s14 NumberField(0:r_flows[14], default=0)

G -> T 
$@bind s15 NumberField(0:r_flows[15], default=0)
	
"""

# ╔═╡ 96ec8b61-2a85-40c8-beca-7daadb2da141
begin
	solution = [s1,s2,s3,s4,s5,s6,s7,s8,s9,s10,s11,s12,s13,s14,s15]
	solution_matrix = zeros(size(nodes,1),size(nodes,1))
	solution_matrix[1,2]=solution[1]
	solution_matrix[1,3]=solution[2]
	solution_matrix[1,4]=solution[3]
	solution_matrix[2,5]=solution[4]
	solution_matrix[2,6]=solution[5]
	solution_matrix[2,3]=solution[6]
	solution_matrix[3,6]=solution[7]
	solution_matrix[4,3]=solution[8]
	solution_matrix[4,7]=solution[9]
	solution_matrix[5,8]=solution[10]
	solution_matrix[5,6]=solution[11]
	solution_matrix[6,7]=solution[12]
	solution_matrix[6,8]=solution[13]
	solution_matrix[7,9]=solution[14]
	solution_matrix[8,9]=solution[15]
	
	if optimum_rand_flows[7,9] + optimum_rand_flows[8,9] == solution_matrix[8,9]+solution_matrix[7,9] && solution_matrix[5,8] + solution_matrix[6,8] == solution_matrix[8,9] && solution_matrix[6,7] + solution_matrix[4,7] == solution_matrix[7,9]
		md"#### Correct Solution"
	else
		md"#### Incorrect Solution" 
	end
end

# ╔═╡ d4d1710f-0cb4-46a6-9d7b-f5f2981c4479
begin
	user_solution = MetaGraph(
		DiGraph(),              # directed graph
		label_type=String,      # node labels are String's
	    edge_data_type=Float64, # edge labels are Float64's
		graph_data="oil pipeline network"
	)
	
	# add vertices
	for v in ["S", "T", "A", "B", "C", "D", "E", "F", "G"]
		add_vertex!(user_solution, v)
	end

	# add edges
	add_edge!(user_solution, "S", "A", solution_matrix[1,2])
	add_edge!(user_solution, "S", "B", solution_matrix[1,3])
	add_edge!(user_solution, "S", "C", solution_matrix[1,4])
	
	add_edge!(user_solution, "A", "D", solution_matrix[2,5])
	add_edge!(user_solution, "A", "E", solution_matrix[2,6])
	add_edge!(user_solution, "A", "B", solution_matrix[2,3])
	
	add_edge!(user_solution, "B", "E", solution_matrix[3,6])

	add_edge!(user_solution, "C", "B", solution_matrix[4,3])
	add_edge!(user_solution, "C", "F", solution_matrix[4,7])

	add_edge!(user_solution, "D", "G", solution_matrix[5,8])
	add_edge!(user_solution, "D", "E", solution_matrix[5,6])

	add_edge!(user_solution, "E", "F", solution_matrix[6,7])
	add_edge!(user_solution, "E", "G", solution_matrix[6,8])

	add_edge!(user_solution, "F", "T", solution_matrix[7,9])

	add_edge!(user_solution, "G", "T", solution_matrix[8,9])
	print("")
end

# ╔═╡ a7dc04ac-6d97-4108-be5e-b768c7b93b83
md"""
#### Your current flow map
"""

# ╔═╡ db583aa3-5206-4129-8a7a-3f52ac6d041d
begin
	fig_user = Figure()
	ax_user = Axis(fig_user[1, 1], title="oil pipeline network")
	hidedecorations!(ax_user)
	hidespines!(ax_user)
	graphplot!(
		user_solution.graph, 
		edge_width=3, 
		arrow_size=20,
		node_color="green",
		node_size=30,
		edge_color="gray",
		nlabels=collect(labels(user_solution)),
		nlabels_distance=5.0,
		nlabels_fontsize=25,
		elabels=["$(user_solution[e...])" for e in edge_labels(user_solution)],
		arrow_shift=:end,
	)
	ylims!(nothing, 3.4)
	fig_user
end

# ╔═╡ cb2b89f4-6c23-4635-af54-a1624fb48a00
md"""
# Answer
"""

# ╔═╡ c7984b86-bd93-4d25-b0c1-8d916498f7b7
md"""
Show Answer
$@bind z CheckBox()
"""

# ╔═╡ bd4d8e7f-080e-4c35-b657-7799551d9c98
begin

if z == true
	fig_rand_o = Figure()
	ax_rand_o = Axis(fig_rand_o[1, 1], title="oil pipeline network")
	hidedecorations!(ax_rand_o)
	hidespines!(ax_rand_o)
	graphplot!(
		optimal_g_rand.graph, 
		edge_width=3, 
		arrow_size=20,
		node_color="green",
		node_size=30,
		edge_color="gray",
		nlabels=collect(labels(optimal_g_rand)),
		nlabels_distance=5.0,
		nlabels_fontsize=25,
		elabels=["$(optimal_g_rand[e...])" for e in edge_labels(optimal_g_rand)],
		arrow_shift=:end,
	)
	ylims!(nothing, 3.4)
	fig_rand_o
end
end


# ╔═╡ Cell order:
# ╠═a4aa940e-84c8-483e-a1d5-6fa235ed39b6
# ╠═299ada83-58d2-4bb3-ac21-dd7ce9e3b462
# ╟─f60668bc-85c5-4812-bcbb-573adb218956
# ╟─55d53dc9-e6d0-4d2e-b22f-2604675be3bb
# ╟─e629e32a-c69d-4e50-a8e4-27c134af82c2
# ╟─6272ba29-f291-44b0-9eaa-c9e1c333672c
# ╟─746d8964-1576-4dce-a018-5ab582bb69dd
# ╟─78a36975-51f2-4a74-8905-516ae23b65ac
# ╟─739e9c89-d127-49cb-81d6-a678e0485b62
# ╟─df4c7d65-1198-4961-a216-0d8a6b5a8c24
# ╠═d24be387-73dc-435d-9e4e-0605b1985b51
# ╠═d68e247f-8d4f-4f96-82c7-c789a14c288c
# ╠═3158611c-712a-4fce-ad5c-1356a9a346a1
# ╠═4b743760-aa6d-4aa9-95d7-7fa921d78bc1
# ╠═3bf65d86-8f87-495c-98e8-937911fe4e9b
# ╠═bf7bb1ae-bc99-48c2-81cc-b7dac5901b95
# ╠═c2360213-12a7-4640-9b4b-5f0b19d43bff
# ╠═65700e50-4610-477d-a528-844c1ddb71a4
# ╟─5e030137-7862-4e67-b2e4-ff9c724cfd90
# ╟─92d4043a-1514-413a-b3d8-0f77c7d402da
# ╟─cb95e1c3-9309-4727-985d-9adf8f77ca75
# ╟─0afc45e1-edd9-49c2-915d-f0aad0de8829
# ╟─d94b8f55-9316-4b88-a8ee-d859818e7021
# ╟─5163c4d4-2922-448e-8824-eafc28ba05ae
# ╟─f4663196-4c6f-495b-87ac-a82036975edb
# ╟─b036c967-66a0-4743-890a-aafb0ccd2e11
# ╟─fc84d0d9-e5f1-4ff6-9468-198c0b98b3f5
# ╟─25c9e64f-f6fb-40a1-8841-98f36e4114bd
# ╟─00bcbe83-1dc1-4d1e-a219-336ba24554a3
# ╟─7472e750-b4d6-43c1-8e65-24364757ce2c
# ╟─b38593ba-8c15-4230-a6e9-e8f6c73b7f0d
# ╟─198c8032-082d-4284-b936-4b499de63f84
# ╟─3aaf6244-41f8-433f-9e23-988677ca5625
# ╟─c2318a04-ed89-4c7c-902d-f758e7e1c3aa
# ╟─36e975b3-bc99-4046-bd28-bb6bf9d1d432
# ╟─96ec8b61-2a85-40c8-beca-7daadb2da141
# ╟─d4d1710f-0cb4-46a6-9d7b-f5f2981c4479
# ╟─a7dc04ac-6d97-4108-be5e-b768c7b93b83
# ╟─db583aa3-5206-4129-8a7a-3f52ac6d041d
# ╟─cb2b89f4-6c23-4635-af54-a1624fb48a00
# ╟─c7984b86-bd93-4d25-b0c1-8d916498f7b7
# ╟─bd4d8e7f-080e-4c35-b657-7799551d9c98

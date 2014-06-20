


module TestAlgoBGP

using FactCheck, MOpt

p    = ["a" => 3.1 , "b" => 4.9]
pb   = [ "a" => [-1,1] , "b" => [0,1] ]
moms = [
	"alpha" => [ 0.8 , 0.02 ],
	"beta"  => [ 0.8 , 0.02 ],
	"gamma" => [ 0.8 , 0.02 ]
]

mprob = MProb(p,pb,MOpt.Testobj,moms)

facts("testing MAlgoBGP Constructor") do

	context("checking members") do

		opts =["N"=>5,"shock_var"=>1.0,"mode"=>"serial","maxiter"=>100,"path"=>".","maxtemp"=>100,"min_shock_sd"=>0.1,"max_shock_sd"=>1.0,"past_iterations"=>30,"min_disttol"=>0.1,"max_disttol"=>1.0,"min_jump_prob"=>0.05,"max_jump_prob"=>0.1,"min_accept_tol"=>0.05,"max_accept_tol"=>0.1] 

		MA = MAlgoBGP(mprob,opts)

		@fact isa(MA,MAlgo) => true
		@fact isa(MA,MAlgoBGP) => true
		@fact isa(MA.m,MProb) => true

		@fact MA.i => 0
		@fact length(MA.MChains) => opts["N"]

		for ix = 1:opts["N"]
			@fact MA.current_param[ix] => p 
		end

	end

	context("checking getters/setters on MAlgo") do

		opts =["N"=>5,"shock_var"=>1.0,"mode"=>"serial","maxiter"=>100,"path"=>".","maxtemp"=>100,"min_shock_sd"=>0.1,"max_shock_sd"=>1.0,"past_iterations"=>30,"min_disttol"=>0.1,"max_disttol"=>1.0,"min_jump_prob"=>0.05,"max_jump_prob"=>0.1,"min_accept_tol"=>0.05,"max_accept_tol"=>0.1] 
		MA = MAlgoBGP(mprob,opts)

		# getters
		@fact MA["N"] => opts["N"]
		@fact MA["mode"] => opts["mode"]

		# setter
		MA["newOption"] = "hi"
		@fact MA["newOption"] => "hi"

	end

end



facts("testing getNewCandidates(MAlgoBGP)") do

	context("test fitMirror(x,ub,lb)") do

		x = 12.1
		ub = 12.0
		lb = -1.1
		z = MOpt.fitMirror(x,lb,ub)
		@fact (z < ub) & (z>lb) => true

		x = rand()
		z = MOpt.fitMirror(x,lb,ub)
		@fact z-x<eps() => true

		x = -1.11
		z = MOpt.fitMirror(x,lb,ub)
		@fact (z < ub) & (z>lb) => true

	end

	context("test fitMirror!(df,dict)") do

		df = DataFrame(a=1.2,b=-1.5)
		MOpt.fitMirror!(df,mprob.params_to_sample_df)
		@fact df[1][1] > pb["a"][1] => true
		@fact df[1][1] < pb["a"][2] => true
		@fact df[2][1] > pb["b"][1] => true
		@fact df[2][1] < pb["b"][2] => true

	end

	context("test getParamCovariance") do

		opts =["N"=>5,"shock_var"=>1.0,"mode"=>"serial","maxiter"=>100,"path"=>".","maxtemp"=>100,"min_shock_sd"=>0.1,"max_shock_sd"=>1.0,"past_iterations"=>30,"min_disttol"=>0.1,"max_disttol"=>1.0,"min_jump_prob"=>0.05,"max_jump_prob"=>0.1,"min_accept_tol"=>0.05,"max_accept_tol"=>0.1] 
		MA = MAlgoBGP(mprob,opts)

		# fill chains with random values
		for iter =1:(MA["maxiter"]-1)
			# update all chains to index 1
			MOpt.updateIterChain!(MA.MChains)

			# set a parameter vector on all chains using appendEval!
			myp = ["a" => rand() , "b" => rand()]
			mym = ["alpha" => rand(),"beta"  => rand(),"gamma" =>  rand()]
			ret = ["value" => 1.1, "params" => myp, "time" => 0, "status" => 1, "moments" => mym]
			for ich in 1:MA["N"]
				MOpt.appendEval!(MA.MChains[ich],ret,true,1,rand())
			end
		end

		# get all parameters
		lower_bound_index = maximum([1,MA.MChains[1].i-MA["past_iterations"]])
		pars = parameters(MA.MChains,lower_bound_index:MA.MChains[1].i)

		# get the last MA["past_iterations"] iterations from each chain
		# get parameter_to_sample names as symbols 
		

		# get covariance matrix of those
		VV = cov(array(pars[:,MA.m.p2sample_sym])) + 0.0001 * Diagonal([1 for i=1:length(p)])

		# get kernel and check VV
		myVV = MOpt.getParamCovariance(MA)

		@fact myVV[:] == VV[:] => true

	end


	context("test updateCandidateParam!") do

		# taking a specific MvNormal instance, 
		# I can know exactly how parameters should change when shocked

		# I'm interested in how algo.candidate_param changes on chain ch

		# setup an Algo
		opts =["N"=>5,"shock_var"=>1.0,"mode"=>"serial","maxiter"=>100,"path"=>".","maxtemp"=>100,"min_shock_sd"=>0.1,"max_shock_sd"=>1.0,"past_iterations"=>30,"min_disttol"=>0.1,"max_disttol"=>1.0,"min_jump_prob"=>0.05,"max_jump_prob"=>0.1,"min_accept_tol"=>0.05,"max_accept_tol"=>0.1] 
		MA = MAlgoBGP(mprob,opts)

		# fill chains with random values up to iteration ix
		ix = 5
		for iter =1:ix
			# update all chains to index 1
			MOpt.updateIterChain!(MA.MChains)

			# set a parameter vector on all chains using appendEval!
			for ich in 1:MA["N"]
				myp = ["a" => rand() , "b" => rand()]
				mym = ["alpha" => rand(),"beta"  => rand(),"gamma" =>  rand()]
				ret = ["value" => 1.1, "params" => myp, "time" => 0, "status" => 1, "moments" => mym]
				MOpt.appendEval!(MA.MChains[ich],ret,true,1,rand())
			end
		end

		# get a "kernel"/Covariance matrix
		# pos def matrix:
		myVV = rand(length(MA.m.params_to_sample_df),length(MA.m.params_to_sample_df))
		myVV = myVV * myVV'

		# manually create next parameter guess on
		# each chain
		newp = Array(DataFrame,MA["N"])
		shock = {i=>Array{Float64,1} for i=1:MA["N"]}

		# on all chains, the parameter entry number ix+1 
		# must correspond to entry number ix plus a shock from the kernel
		for ich in 1:MA["N"]

			MVN = MOpt.MvNormal( myVV.*MA.MChains[ich].tempering )
			shock[ich] = rand(MVN)

			oldp = parameters(MA.MChains[ich],ix-1)	# get a dataframe of row ix-1
			newp[ich] = copy(oldp[MA.m.p2sample_sym])	# get just those you wish to sample

			# add shock
			for i in 1:length(newp[ich])
				newp[ich][i] = newp[ich][i] .+ shock[ich][i]
			end			

			# adjust for bounds
			MOpt.fitMirror!(newp[ich],MA.m.params_to_sample_df)
		end


		# check on algo.candidate_param
		for ich in 1:MA["N"]
			# call library funciton
			MOpt.updateCandidateParam!(MA,ich,shock[ich])

			@fact collect(values(MA.candidate_param[ich])) == map(x->x[1],collect(values(MOpt.df2dict(newp[ich])))) => true

		end


	end

end

facts("testing swaprows") do

	context("testing swapRows!") do

		opts =["N"=>5,"shock_var"=>1.0,"mode"=>"serial","maxiter"=>100,"path"=>".","maxtemp"=>100,"min_shock_sd"=>0.1,"max_shock_sd"=>1.0,"past_iterations"=>30,"min_disttol"=>0.1,"max_disttol"=>1.0,"min_jump_prob"=>0.05,"max_jump_prob"=>0.1,"min_accept_tol"=>0.05,"max_accept_tol"=>0.1] 
		MA = MAlgoBGP(mprob,opts)

		# fill chains with random values up to iteration ix
		ix = 5
		for iter =1:ix
			# update all chains to index 1
			MOpt.updateIterChain!(MA.MChains)

			# set a parameter vector on all chains using appendEval!
			for ich in 1:MA["N"]
				myp = ["a" => rand() , "b" => rand()]
				mym = ["alpha" => rand(),"beta"  => rand(),"gamma" =>  rand()]
				ret = ["value" => 1.1, "params" => myp, "time" => 0, "status" => 1, "moments" => mym]
				MOpt.appendEval!(MA.MChains[ich],ret,true,1,rand())
			end
		end

		# get a pair (i,j) of chains
		pair = (1,3)

		# get params and moms
		p1 = parameters(MA.MChains[pair[1]],ix)
		p2 = parameters(MA.MChains[pair[2]],ix)
		m1 = moments(MA.MChains[pair[1]],ix)
		m2 = moments(MA.MChains[pair[2]],ix)
		v1 = evals(MA.MChains[pair[1]],ix)
		v2 = evals(MA.MChains[pair[2]],ix)


		# exchange
		MOpt.swapRows!(MA,pair,ix)

		# check parameters
		@fact parameters(MA.MChains[pair[1]],ix) == p2 => true
		@fact parameters(MA.MChains[pair[2]],ix) == p1 => true
		@fact moments(MA.MChains[pair[1]],ix) == m2 => true
		@fact moments(MA.MChains[pair[2]],ix) == m1 => true
		@fact evals(MA.MChains[pair[1]],ix) == v2 => true
		@fact evals(MA.MChains[pair[2]],ix) == v1 => true

	end

	
end

facts("testing localMovesMCMC") do

	context("testing initila period") do

		opts =["N"        => 20,		# number of chains
		"mode"            => "serial",	# mode: serial or mpi
		"maxiter"         => 100,		# number of iterations
		"path"            => ".",		# path where to save
		"maxtemp"         => 100,		# chain tempering is linspace(1,maxtemp,N)
		"min_shock_sd"    => 0.1,		# initial sd of shock to coolest chain
		"max_shock_sd"    => 1.0, 		# initial sd of shock to hottest chain. linspace()
		"past_iterations" => 30,		# max number of periods used to compute Cov of parameters
		"min_disttol"     => 0.1,		# minimum tol criterion to assess "similar" chains for jumps
		"max_disttol"     => 1.0,		# maximum tol criterion to assess "similar" chains for jumps
		"min_jump_prob"   => 0.00,		# minimum probability with which a given chain jumps, if similar chains found
		"max_jump_prob"   => 0.0,		# maximum probability with which a given chain jumps, if similar chains found
		"min_accept_tol"  => 1000.05,		# minimum acceptance level for local moves. Set for ABC-like estimation. For chain_i, accept param_x with probability rho iff value(param_x) < accept_tol_i. In practice, moves with only minor improvement are rejected.
		"max_accept_tol"  => 1000.1]

		MA = MAlgoBGP(mprob,opts)

		# get a return value
		v = map( x -> MOpt.evaluateObjective(MA,x), 1:MA["N"])

		# set iteration on chains and algo = 1
		MA.i = 1
		MOpt.updateIterChain!(MA.MChains)
		MOpt.localMovesMCMC!(MA,v)

		# all accepted: 
		@fact all(infos(MA.MChains,1)[:accept]) => true
		@fact all(infos(MA.MChains,1)[:status] .== 1) => true
		# all params equal to initial value
		for nm in 1:length(MA.MChains[1].params_nms)
			@fact parameters(MA.MChains[1],1)[MA.MChains[1].params_nms[nm]][1] == p[string(MA.MChains[1].params_nms[nm])] => true
		end

		# next iteration
		# set options
		MA.i = 2
		MOpt.updateIterChain!(MA.MChains)
		MOpt.localMovesMCMC!(MA,v)

		# param equal to previous param is accepted with prob = 1
		@fact all(infos(MA.MChains,MA.i)[:prob] .== 1) => true
		@fact all(infos(MA.MChains,MA.i)[:status] .== 1) => true
	end

	context("testing whether params get accept/rejected") do

		# impose zero exchange by setting jump_prob to 0.0
		opts =["N"        => 20,		# number of chains
		"mode"            => "serial",	# mode: serial or mpi
		"maxiter"         => 100,		# number of iterations
		"path"            => ".",		# path where to save
		"maxtemp"         => 100,		# chain tempering is linspace(1,maxtemp,N)
		"min_shock_sd"    => 0.1,		# initial sd of shock to coolest chain
		"max_shock_sd"    => 1.0, 		# initial sd of shock to hottest chain. linspace()
		"past_iterations" => 30,		# max number of periods used to compute Cov of parameters
		"min_disttol"     => 0.1,		# minimum tol criterion to assess "similar" chains for jumps
		"max_disttol"     => 1.0,		# maximum tol criterion to assess "similar" chains for jumps
		"min_jump_prob"   => 0.00,		# minimum probability with which a given chain jumps, if similar chains found
		"max_jump_prob"   => 0.0,		# maximum probability with which a given chain jumps, if similar chains found
		"min_accept_tol"  => 1000.05,		# minimum acceptance level for local moves. Set for ABC-like estimation. For chain_i, accept param_x with probability rho iff value(param_x) < accept_tol_i. In practice, moves with only minor improvement are rejected.
		"max_accept_tol"  => 1000.1]
		
		MA = MAlgoBGP(mprob,opts)
		v=0

		# get a return value
		v = map( x -> MOpt.evaluateObjective(MA,x), 1:MA["N"])

		# first iteration
		MA.i = 1
		MOpt.updateIterChain!(MA.MChains)
		MOpt.localMovesMCMC!(MA,v)

		# second iteration
		MA.i = 2
		MOpt.updateIterChain!(MA.MChains)
		# set values close to initial
		temps = linspace(1.0,MA["maxtemp"],MA["N"])
		v0 = deepcopy(v)
		for i in 1:length(v) 
			v[i]["value"] = v[i]["value"] - log(0.5)
			for (k,va) in MA.candidate_param[i]
				MA.candidate_param[i][k] = va + rand()
			end
		end
		MOpt.localMovesMCMC!(MA,v)

		# acceptance prob is exactly 0.5
		@fact all(abs(infos(MA.MChains,MA.i)[:prob] .- exp(temps.*log(0.5))) .< 0.000000001) => true
		vv = infos(MA.MChains,MA.i)
		@fact all(abs(vv[vv[:accept] .== true,:evals]  .- v0[1]["value"] .+ log(0.5)) .<0.000001) => true
		@fact all(abs(vv[vv[:accept] .== false,:evals]  .- v0[1]["value"]) .< 0.000000001 ) => true

		# check that where not accepted, params and moments are previous ones
		for ch in 1:MA["N"]
			if infos(MA.MChains[ch],MA.i)[:accept][1]

				# println("chain number = $ch")
				# println("accept = $(MOpt.infos(MA.MChains[ch],MA.i)[:accept][1])")
				# println("stored parameters = $(array(MOpt.parameters(MA.MChains[ch],MA.i)[:,MA.MChains[ch].params_nms])[:])")
				# println("candidate parameters = $(collect(values(MA.candidate_param[ch])))")
				# println("current parameters = $(collect(values(MA.current_param[ch])))")
				
				# if accepted, parameters == current_param
				for nm in 1:length(MA.MChains[1].params_nms)
					@fact parameters(MA.MChains[ch],MA.i)[MA.MChains[ch].params_nms[nm]][1] == MA.current_param[ch][string(MA.MChains[ch].params_nms[nm])] => true
				end
				for nm in 1:length(MA.MChains[1].params_nms)
					@fact parameters(MA.MChains[ch],MA.i)[MA.MChains[ch].params_nms[nm]][1] == MA.candidate_param[ch][string(MA.MChains[ch].params_nms[nm])] => true
				end
			else
				# if not, parameters == current println("chain number = $ch")
				# println("chain number = $ch")
				# println("accept = $(MOpt.infos(MA.MChains[ch],MA.i)[:accept][1])")
				# println("stored parameters = $(array(MOpt.parameters(MA.MChains[ch],MA.i)[:,MA.MChains[ch].params_nms])[:])")
				# println("candidate parameters = $(collect(values(MA.candidate_param[ch])))")
				# println("current parameters = $(collect(values(MA.current_param[ch])))")

				for nm in 1:length(MA.MChains[1].params_nms)
					@fact parameters(MA.MChains[ch],MA.i)[MA.MChains[ch].params_nms[nm]][1] == MA.current_param[ch][string(MA.MChains[ch].params_nms[nm])] => true
				end
				for nm in 1:length(MA.MChains[1].params_nms)
					@fact parameters(MA.MChains[ch],MA.i)[MA.MChains[ch].params_nms[nm]][1] != MA.candidate_param[ch][string(MA.MChains[ch].params_nms[nm])] => true
				end

			end
		end

	end
end

facts("testing exchangeMoves") do


	context("testing exchangeMoves: some chains exchange") do

		opts =["N"=>20,"shock_var"=>1.0,"mode"=>"serial","maxiter"=>100,"path"=>".","maxtemp"=>100,"min_shock_sd"=>0.1,"max_shock_sd"=>1.0,"past_iterations"=>30,"min_disttol"=>0.01,"max_disttol"=>0.01,"min_jump_prob"=>1.0,"max_jump_prob"=>1.0,"min_accept_tol"=>0.05,"max_accept_tol"=>0.1] 

		MA = MAlgoBGP(mprob,opts)
		MA.i = 1
		MOpt.updateIterChain!(MA.MChains)
		v = map( x -> MOpt.evaluateObjective(MA,x), 1:MA["N"])
		for ch in 1:MA["N"] MOpt.appendEval!(MA.MChains[ch],v[ch],false,1,1.0) end

		MA.i = 2
		MOpt.updateIterChain!(MA.MChains)

		# index we want to fix: ch
		ch = 1
		ch2 = 2
		v[ch2]["value"] = v[ch2]["value"] + randn()*0.01
		MOpt.appendEval!(MA.MChains[ch],v[ch],false,1,1.0) 
		MOpt.appendEval!(MA.MChains[ch2],v[ch2],false,1,1.0) 
		for i in 1:length(v) 
			if ((i != ch) & (i != ch2))
				v[i]["value"] = v[i]["value"]+100
				MOpt.appendEval!(MA.MChains[i],v[i],false,1,1.0) 
			end
		end

		MOpt.exchangeMoves!(MA,ch,v[1]["value"])

		# expect we exchanged ch with ch2 and nothing else
		@fact infos(MA.MChains[ch],MA.i)[:exchanged_with][1] .== ch2 =>true
		@fact infos(MA.MChains[ch2],MA.i)[:exchanged_with][1] .== ch =>true
		for i in 1:length(v) 
			if ((i != ch) & (i != ch2))
				@fact infos(MA.MChains[i],MA.i)[:exchanged_with][1] .== 0 =>true
			end
		end

	end


	context("testing exchangeMoves: 0 chains exchange") do
	
		opts =["N"=>20,"shock_var"=>1.0,"mode"=>"serial","maxiter"=>100,"path"=>".","maxtemp"=>100,"min_shock_sd"=>0.1,"max_shock_sd"=>1.0,"past_iterations"=>30,"min_disttol"=>0.01,"max_disttol"=>0.01,"min_jump_prob"=>0.0,"max_jump_prob"=>0.0,"min_accept_tol"=>0.05,"max_accept_tol"=>0.1] 

		MA = MAlgoBGP(mprob,opts)
		MA.i = 1
		MOpt.updateIterChain!(MA.MChains)
		v = map( x -> MOpt.evaluateObjective(MA,x), 1:MA["N"])
		for ch in 1:MA["N"] MOpt.appendEval!(MA.MChains[ch],v[ch],false,1,1.0) end

		MA.i = 2
		MOpt.updateIterChain!(MA.MChains)

		# index we want to fix: ch
		ch = 1
		ch2 = 2
		v[ch2]["value"] = v[ch2]["value"] + randn()*0.01
		MOpt.appendEval!(MA.MChains[ch],v[ch],false,1,1.0) 
		MOpt.appendEval!(MA.MChains[ch2],v[ch2],false,1,1.0) 
		for i in 1:length(v) 
			if ((i != ch) & (i != ch2))
				v[i]["value"] = v[i]["value"]+100
				MOpt.appendEval!(MA.MChains[i],v[i],false,1,1.0) 
			end
		end

		MOpt.exchangeMoves!(MA,ch,v[1]["value"])

		for i in 1:length(v) 
			@fact infos(MA.MChains[i],MA.i)[:exchanged_with][1] .== 0 =>true
		end
	end

	

end


facts("testing MAlgo methods") do
	
	context("testing evaluateObjective(algo)") do

		opts =["N"=>5,"shock_var"=>1.0,"mode"=>"serial","maxiter"=>100,"path"=>".","maxtemp"=>100,"min_shock_sd"=>0.1,"max_shock_sd"=>1.0,"past_iterations"=>30,"min_disttol"=>0.1,"max_disttol"=>1.0,"min_jump_prob"=>0.05,"max_jump_prob"=>0.1,"min_accept_tol"=>0.05,"max_accept_tol"=>0.1] 
		MA = MAlgoBGP(mprob,opts)

		which_chain = 1
		x = MOpt.evaluateObjective(MA,which_chain)

		@fact haskey(x,"value") => true
		@fact x["params"] => p
		@fact haskey(x,"moments") => true

		# change p on MA:
		newp = ["a" => 103.1 , "b" => -2.2]
		MA.candidate_param[which_chain] = newp
		x = MOpt.evaluateObjective(MA,1)
		@fact x["params"] => newp
	end


	
end





end # module

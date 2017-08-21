
# imports
push!(LOAD_PATH, normpath(joinpath(pwd(),".."))) #adds the location of ClustForOpt to the LOAD_PATH
push!(LOAD_PATH, "/data/cees/hteich/clustering/src")
using ClustForOpt
using JLD

 # read parameters
param=DataFrame()
try
  param = readtable(joinpath("outfiles","parameters.txt"))
catch
  error("No input file parameters.txt exists in folder outfiles.")
end

n_clust_min=param[:n_clust_min][1]
n_clust_max=param[:n_clust_max][1]
n_init=param[:n_init][1]
n_dbaclust=param[:n_dbaclust][1]
rad_sc_min=param[:rad_sc_min][1]
rad_sc_max=param[:rad_sc_max][1]
iterations=param[:iterations][1]
inner_iterations=param[:inner_iterations][1]
region=param[:region][1]

n_clust_ar = collect(n_clust_min:n_clust_max)
rad_sc_ar = collect(rad_sc_min:rad_sc_max)
 
# read in original data
data_orig_daily = load_pricedata(region)
seq = data_orig_daily[:,1:365]  # do not load as sequence

problem_type_ar = ["battery", "gas_turbine"]

 # initialize dictionaries of the loaded data (key: number of clusters)
centers = Dict{Tuple{Int,Int,Int},Array}()
clustids = Dict{Tuple{Int,Int,Int},Array}()
cost = zeros(length(n_clust_ar),length(rad_sc_ar),n_dbaclust)
iter =  zeros(length(n_clust_ar),length(rad_sc_ar),n_dbaclust)
inner_iter =  zeros(length(n_clust_ar),length(rad_sc_ar),n_dbaclust)
weights = Dict{Tuple{Int,Int,Int},Array}()
revenue = Dict{String,Array}() 
for i=1:length(problem_type_ar)
  revenue[problem_type_ar[i]] = zeros(length(n_clust_ar),length(rad_sc_ar),n_dbaclust)
end
 # iterate through settings 
  

for n_clust_it=1:length(n_clust_ar)
  n_clust = n_clust_ar[n_clust_it] # use for indexing Dicts
  for rad_sc_it=1:length(rad_sc_ar)
    rad_sc = rad_sc_ar[rad_sc_it] # use for indexing Dicts
    for i = 1:n_dbaclust
      
      # readdata
      centers[n_clust,rad_sc,i] = Array(readtable(joinpath("outfiles",string("dbaclust_k_",n_clust,"_scband_",rad_sc,"_ninit_",n_init,"_it_",iterations,"_innerit_",inner_iterations,"_",i,"_cluster.txt")),separator='\t',header=false))
      clustids[n_clust,rad_sc,i] = Array(readtable(joinpath("outfiles",string("dbaclust_k_",n_clust,"_scband_",rad_sc,"_ninit_",n_init,"_it_",iterations,"_innerit_",inner_iterations,"_",i,"_clustids.txt")),separator='\t',header=false))
      cost[n_clust_it,rad_sc_it,i] = Array(readtable(joinpath("outfiles",string("dbaclust_k_",n_clust,"_scband_",rad_sc,"_ninit_",n_init,"_it_",iterations,"_innerit_",inner_iterations,"_",i,"_cost.txt")),separator='\t',header=false))[1]

     iter[n_clust_it,rad_sc_it,i] = Array(readtable(joinpath("outfiles",string("dbaclust_k_",n_clust,"_scband_",rad_sc,"_ninit_",n_init,"_it_",iterations,"_innerit_",inner_iterations,"_",i,"_it.txt")),separator='\t',header=false))[1]
      inner_iter[n_clust_it,rad_sc_it,i] = Array(readtable(joinpath("outfiles",string("dbaclust_k_",n_clust,"_scband_",rad_sc,"_ninit_",n_init,"_it_",iterations,"_innerit_",inner_iterations,"_",i,"_innerit.txt")),separator='\t',header=false))[1]
      
      # calculate weights
      weights[n_clust,rad_sc,i] = zeros(n_clust) 
      for j=1:length(clustids[n_clust,rad_sc,i])
          weights[n_clust,rad_sc,i][clustids[n_clust,rad_sc,i][j]] +=1
      end
      weights[n_clust,rad_sc,i] =  weights[n_clust,rad_sc,i] /length(clustids[n_clust,rad_sc,i])

      
      # run opt
      for ii=1:length(problem_type_ar)
        revenue[problem_type_ar[ii]][n_clust_it,rad_sc_it,i]=sum(run_opt(problem_type_ar[ii],(centers[n_clust,rad_sc,i])',weights[n_clust,rad_sc,i],region,false))
      end 

    end
      println("rev bat ","k=",n_clust," SC rad: ",rad_sc," " , revenue["battery"][n_clust_it,rad_sc_it,1])
  end
end


 # save as JLD file

save_dict = Dict("centers"=>centers,
                 "clustids"=>clustids,
                 "cost"=>cost,
                 "iter"=>iter,
                 "inner_iter"=>inner_iter,
                 "weights"=>weights,
                 "revenue"=>revenue )
                  
save("outfiles/aggregated_results.jld",save_dict)
println("Dbaclust data revenue calculated + saved.")




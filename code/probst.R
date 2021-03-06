library(mlr)
library(batchtools)
library(plyr)

dir = "/home/probst/Random_Forest/RFParset"
setwd(paste0(dir,"/results"))
source(paste0(dir,"/code/probst_defs.R"))

unlink("probs-muell", recursive = TRUE)
regis = makeExperimentRegistry("probs-muell", 
                             packages = c("mlr", "OpenML", "randomForest", "methods"),
                             source = "/nfsmb/koll/probst/Random_Forest/RFParset/code/probst_defs.R",
                             work.dir = "/nfsmb/koll/probst/Random_Forest/RFParset/results",
                             conf.file = "/nfsmb/koll/probst/Random_Forest/RFParset/code/.batchtools.conf.R"
)

regis$cluster.functions = makeClusterFunctionsMulticore() 

# add our selected OML dsets as problems
for (did in OMLDATASETS) {
  data = list(did = did)
  addProblem(name = as.character(did), data = data)
}

# add one generic 'algo' that evals the RF in hyperpar space
addAlgorithm("eval", fun = function(job, data, instance, lrn.id, ...) {
  par.vals = list(...)
  oml.dset = getOMLDataSet(data$did)             
  task = convertOMLDataSetToMlr(oml.dset)
  type = getTaskType(task)
  par.vals = par.vals[!(is.na(par.vals))]
  par.vals = CONVERTPARVAL(par.vals, task, lrn.id)
  lrn.id = paste0(type, ".", lrn.id)
  lrn = switch(type, "classif" = makeLearner(lrn.id, predict.type = "prob"), "regr" = makeLearner(lrn.id))
  lrn = setHyperPars(lrn, par.vals = par.vals)
  measures = MEASURES(type)
  mod = train(lrn, task)
  oob = getOutOfBag(mod, task)
  performance(oob, measures = measures, model = mod)
})

# Random maximin design
set.seed(124)
ades = data.frame()
for (lid in LEARNERIDS) {
  ps = makeMyParamSet(lid, task = NULL)
  des.size = DESSIZE(ps)
  d = generateDesign(des.size, ps)
  d = cbind(lrn.id = lid, d, stringsAsFactors = FALSE)
  ades = rbind.fill(ades, d)
}
addExperiments(algo.designs = list(eval = ades))

# FIXME: we need to add the defaults of each learner and defaults that we could invent.
# defaults
ades_def = data.frame()
for (lid in "ranger") {
  ps = makeMyDefaultParamSet(lid)
  d = generateGridDesign(ps, resolution = 1)
  d = cbind(lrn.id = lid, d, stringsAsFactors = FALSE)
  ades_def = rbind.fill(ades_def, d)
}

summarizeExperiments()
ids = getJobTable()$job.id
ids = chunkIds(findNotDone(), chunk.size = 1000)

submitJobs(ids)
submitJobs(ids, resources = list(chunk.ncpus = 9))
getStatus()
getErrorMessages()
res = reduceResultsDataTable(ids = 1:10, fun = function(r) as.data.frame(as.list(r)), reg = regis)
res
res = reduceResultsDataTable(ids = 1141:1806, fun = function(r) as.data.frame(as.list(r)), reg = regis)
res

# zu Debugzwecken
#lrn.id = "ranger"
#par.vals = as.list(ades[1,-1])
#data$did = 457

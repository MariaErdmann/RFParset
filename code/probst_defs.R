load("/home/probst/Random_Forest/RFParset/results/clas.RData")
load("/home/probst/Random_Forest/RFParset/results/reg.RData")
tasks = rbind(clas_small, reg_small)

OMLDATASETS = tasks$did[!(tasks$did %in% c(1054, 1071, 1065))] # Cannot guess task.type from data! for these 3
#OMLDATASETS = OMLDATASETS[1:50]

MEASURES = function(x) switch(x, "classif" = list(acc, ber, mmce, multiclass.au1u, multiclass.brier, logloss, timetrain), "regr" = list(mse, mae, medae, medse, timetrain))

LEARNERIDS = c("randomForest", "ranger", "randomForestSRC")

DESSIZE = function(ps) {
   20 * 24 * 4 # sum(getParamLengths(ps)) # approx. 2 days
  # 20 * 10 * 1
  # 2 minutes per sample approximately
}

makeMyParamSet = function(lrn.id, task = NULL) {
  switch(lrn.id,
         randomForest = makeParamSet(
           makeIntegerParam("ntree", lower = 50, upper = 10000),
           makeLogicalParam("replace"),
           makeNumericParam("sampsize", lower = 0, upper = 1),
           makeNumericParam("mtry", lower = 0, upper = 1),
           makeNumericParam("nodesize", lower = 0, upper = 0.5),
           makeNumericParam("maxnodes", lower = 0, upper = 1)
         ),
         ranger = makeParamSet(
           makeIntegerParam("num.trees", lower = 50, upper = 10000),
           makeLogicalParam("replace"),
           makeNumericParam("sample.fraction", lower = 0, upper = 1),
           makeNumericParam("mtry", lower = 0, upper = 1),
           makeNumericParam("min.node.size", lower = 0, upper = 0.5)
         ),
         randomForestSRC = makeParamSet(
           makeIntegerParam("ntree", lower = 50, upper = 10000),
           makeDiscreteParam("samptype", values = c("swr", "swor")), # entspricht replace
           makeNumericParam("sampsize", lower = 0, upper = 1),
           makeNumericParam("mtry", lower = 0, upper = 1),
           makeNumericParam("nodesize", lower = 0, upper = 0.5),
           makeNumericParam("nodedepth", lower = 0, upper = 1),
           makeDiscreteParam("splitrule", values = c("normal", "unwt", "hvwt", "random"))
           #makeDiscreteParam("bootstrap", values = c("by.root", "by.node", "none")),
           # not possible, as oob are not available; resample alternatively
         )
  )
}

makeMyDefaultParamSet = function (lrn.id, task = NULL) {
  switch(lrn.id,
         ranger = makeParamSet(
           makeIntegerParam("num.trees", lower = 10000, upper = 10000),
           makeLogicalParam("replace"),
           makeDiscreteParam("sample.fraction", values = c("1", "0.632")),
           makeDiscreteParam("mtry", values = c("log", "sqrt", "1", "2")),
           makeDiscreteParam("min.node.size", values = c("log", "sqrt", "5", "1"))
         )
  ) 
}

# FIXME: this is maybe not so good?
# mabe we would like to do this instead:
# makeNumericParam("mtry", lower = 0, upper = 1, trafo = function(mtry) mtry * p)
# ???
CONVERTPARVAL = function(par.vals, task, lrn.id) {
  typ = getTaskType(task)
  n = getTaskSize(task)
  p = getTaskNFeats(task)
  if (is.null(par.vals$default)) {
  if (lrn.id == "ranger") {
    par.vals$sample.fraction = max(par.vals$sample.fraction, 1/n) # sollte nicht kleiner als "1" Beobachtung sein
    par.vals$mtry = ceiling(par.vals$mtry * p)
    par.vals$min.node.size =  ceiling(par.vals$min.node.size * ceiling(par.vals$sample.fraction * n)) # nodesize darf nicht größer sein als sampsize!
  }
  if (lrn.id == "randomForest") {
    par.vals$sampsize = max(ceiling(par.vals$sampsize * n), 1)
    par.vals$mtry = ceiling(par.vals$mtry * p)
    par.vals$nodesize = ceiling(par.vals$nodesize * par.vals$sampsize) # nodesize darf nicht größer sein als sampsize!
    par.vals$maxnodes = max(2, floor(par.vals$maxnodes * (par.vals$sampsize/par.vals$nodesize)))
  }
  if (lrn.id == "randomForestSRC") {
    par.vals$sampsize = ceiling(par.vals$sampsize * n)
    par.vals$samptype = as.character(par.vals$samptype)
    par.vals$mtry = ceiling(par.vals$mtry * p)
    par.vals$nodesize = ceiling(par.vals$nodesize * par.vals$sampsize) # nodesize darf nicht größer sein als sampsize!
    par.vals$nodedepth = ceiling(par.vals$nodedepth * floor(log(n, 2))) # nodedepth kann zwischen 1 und floor(log(n, 2)) liegen

    # par.vals$bootstrap = as.character(par.vals$bootstrap)
    if (typ == "classif") par.vals$splitrule = switch(as.character(par.vals$splitrule), normal = "gini", unwt = "gini.unwt", hvwt = "gini.hvwt", random = "random")
    if (typ == "regr") par.vals$splitrule = switch(as.character(par.vals$splitrule), normal = "mse", unwt = "mse.unwt", hvwt = "mse.hvwt", random = "random")
  }
  } else {
    
  }
  
  return(par.vals)
}



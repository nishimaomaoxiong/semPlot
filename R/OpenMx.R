### Path diagrams ###
# 
# semPaths_MxRAMModel <- function(object,...){
#   invisible(semPaths(semPlotModel(object),...))
# }
#           
# semPaths_MxModel <- function(object,...){
#   invisible(semPaths(semPlotModel(object),...))
# }
#  
### EXTRACT MODEL ###
          
### SINGLE GROUP ###
semPlotModel_MxRAMModel <- function(object){
  
  # Extract names:
  varNames <- object@manifestVars
  factNames <- object@latentVars
  
  # Extract directed paths:
  Dirpaths <- which(t(object@matrices$A@free | object@matrices$A@values!=0),arr.ind=TRUE)
  DirpathsFixed <- !t(object@matrices$A@free)[Dirpaths]
  DirpathsValues <- t(object@matrices$A@values)[Dirpaths]
  DirpathsLabels <- t(object@matrices$A@labels)[Dirpaths]
  
  # Extract symmetric paths:
  Sympaths <- which(t(object@matrices$S@free | object@matrices$S@values!=0) & upper.tri(object@matrices$S@values,diag=TRUE),arr.ind=TRUE)
  SympathsFixed <- !t(object@matrices$S@free)[Sympaths]
  SympathsValues <- t(object@matrices$S@values)[Sympaths]
  SympathsLabels <- t(object@matrices$A@labels)[Sympaths]
  
  if (!is.null(object@matrices$M))
  {
    # Extract intercepts:
    Means <- which(object@matrices$M@free | object@matrices$M@values!=0)
    MeansFixed <- !object@matrices$M@free[Means]
    MeansValues <- object@matrices$M@values[Means]
    MeansLabels <- object@matrices$M@labels[Means]
  } else
  {
    Means <- numeric(0)
    MeansFixed <- logical(0)
    MeansValues <- numeric(0)
    MeansLabels <- character(0)
  }
  
  ## Standardized
  if (!length(object@output)==0)
  {
    # Function by Ryne Estabrook (http://openmx.psyc.virginia.edu/thread/718)
    standObj <- standardizeRAM(object,"model")
    
    # Extract directed paths:
    DirpathsValuesStd <- t(standObj@matrices$A@values)[Dirpaths]
    
      # Extract symmetric paths:
    SympathsValuesStd <- t(standObj@matrices$S@values)[Sympaths]
      
      # Extract means:
    
    if (!is.null(standObj@matrices$M))
    {
      MeansValuesStd <- standObj@matrices$S@values[Means]
    } else
    {
      MeansValuesStd <- numeric(0)
    }
  } else 
  {
    DirpathsValuesStd <- rep(NA,nrow(Dirpaths)) 
    SympathsValuesStd <- rep(NA,nrow(Sympaths))
    MeansValuesStd <- rep(NA,length(Means))
  }
  
  # Vars dataframe:
  Vars <- data.frame(
    name = c(varNames,factNames),
    manifest = c(varNames,factNames)%in%varNames,
    exogenous = NA,
    stringsAsFactors=FALSE)
  
  # Define RAM:
  RAM <- data.frame(
    label = c(DirpathsLabels,SympathsLabels,MeansLabels), 
    lhs = c(Vars$name[c(Dirpaths[,1],Sympaths[,1])],rep("",length(Means))),
    edge = c(rep("->",nrow(Dirpaths)),rep("<->",nrow(Sympaths)),rep("int",length(Means))),
    rhs = Vars$name[c(Dirpaths[,2],Sympaths[,2],Means)],
    est = c(DirpathsValues,SympathsValues,MeansValues),
    std = c(DirpathsValuesStd,SympathsValuesStd,MeansValuesStd),
    group = object@name,
    fixed = c(DirpathsFixed,SympathsFixed,MeansFixed),
    par = 0,
    stringsAsFactors=FALSE)
  
  RAM$par[is.na(RAM$label)] <- seq_len(sum(is.na(RAM$label)))
  for (lbl in unique(RAM$label[!is.na(RAM$label)]))
  {
    RAM$par[RAM$label==lbl] <- max(RAM$par)+1
  }
#   
#   # Add standardized:
#   for (i in 1:nrow(standRAM))
#   {
#     if (standRAM$matrix[i] == "A")
#     {
#       RAM$std[RAM$lhs == standRAM$col[i] & RAM$rhs == standRAM$row[i] & RAM$edge == "->"] <- standRAM[["Std. Estimate"]][i]
#     }
#     if (standRAM$matrix[i] == "S")
#     {
#       RAM$std[RAM$lhs == standRAM$col[i] & RAM$rhs == standRAM$row[i] & RAM$edge == "<->"] <- standRAM[["Std. Estimate"]][i]
#     }
#   }
  
  RAM$label[is.na(RAM$label)] <- ""
  
  semModel <- new("semPlotModel")
  semModel@RAM <- RAM
  semModel@Vars <- Vars
  semModel@Computed <- !length(object@output)==0
  semModel@Original <- list(object)
  
  if (!is.null(object@data))
  {
    if (object@data@type=="cov")
    {
      semModel@ObsCovs <- list(object@data@observed)
    } else if (object@data@type=="raw")
    {
      semModel@ObsCovs <- list(cov(object@data@observed))
    } else
    {
      semModel@ObsCovs <- list(NULL)
    }
  } else
  {
    semModel@ObsCovs <- list(NULL)
  }
  semModel@ImpCovs <- list(object@objective@info$expCov)
  
  return(semModel)
}


semPlotModel_MxModel <- function(object){

  if (any(!"MxRAMModel"%in%sapply(object@submodels,class))) stop("Model or all submodels must be of class 'MxRAMModel'")
  for (i in 1:length(object@submodels)) object@submodels[[i]]@output <- list(TRUE)
  S4objects <- lapply(object@submodels,semPlotModel)
  
  semModel <- new("semPlotModel")
  semModel@RAM <- do.call("rbind",lapply(S4objects,slot,"RAM"))
  
  semModel@RAM$par <- 0
  semModel@RAM$par[semModel@RAM$label==""] <- seq_len(sum(semModel@RAM$label==""))
  for (lbl in unique(semModel@RAM$label[semModel@RAM$label!=""]))
  {
    semModel@RAM$par[semModel@RAM$label==lbl] <- max(semModel@RAM$par)+1
  }
  
  semModel@Vars <- S4objects[[1]]@Vars
  semModel@Computed <- !length(object@output)==0
  semModel@Original <- list(object)
  
  semModel@ObsCovs <- lapply(S4objects,function(x)x@ObsCovs[[1]])
  names(semModel@ObsCovs) <- sapply(object@submodels,slot,"name")
  
  
  semModel@ImpCovs <- lapply(S4objects,function(x)x@ImpCovs[[1]])
  names(semModel@ImpCovs) <- sapply(object@submodels,slot,"name")
  
  
  return(semModel)
}
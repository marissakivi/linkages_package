##' @title LINKAGES growth function
##' @author Ann Raiho
##'
##' @param max.ind maximum number of individuals
##' @param nspec number of species
##' @param ntrees number of trees of each species
##' @param frt foliage retention time
##' @param slta parameter to calculate crown area from diameter
##' @param sltb parameter to calculate crown area from diameter
##' @param dbh diameter of each tree
##' @param fwt leaf weight per unit crown area
##' @param b2 growth scaling parameter
##' @param b3 growth scaling parameter
##' @param itol shade tolerance code for each species
##' @param g scalar for species maximum diameter increment
##' @param frost minimum January temperature tolerated
##' @param rt current monthly temperature
##' @param degdgf growing degree day growth factor from gmult.R
##' @param smgf soil moisture growth factor from gmult.R
##' @param sngf soil nitrogen growth factor from gmult.R
##' @param iage age of each individual
##' @param nogro flags slow growing individuals
##'
##' @description    GROW CALCULATES DIAMETER GROWTH FOR EACH TREE
##'   BY DECREASING MAXIMAL GROWTH TO THE EXTENT THAT THE MOST
##'   LIMITING RESOURCE IS LESS THAN OPTIMAL.
##'
##' @return dbh diameter of each individual
##' @return ntrees number of trees of each species
##' @return awp aboveground woody production
##' @export
##'
grow <- function(max.ind,nspec,ntrees,frt,slta,sltb,dbh,fwt, b2,b3, itol,g,
                 degdgf,smgf,sngf,frost,rt,iage,nogro){
  #initialize wood production
  awp = matrix(0,1,max.ind)

  #calculate total number of trees
  ntot = 0
  ntot = sum(ntrees[1:nspec])
  gf.vec <- array(NA,dim=c(ntot,nspec,4))
  gf.vec.means <- matrix(NA, nrow=nspec, ncol = 4)
  algf.save <- matrix(NA,max.ind,nspec)
  if(ntot != 0){
  if(ntot > max.ind) print("too many trees -- grow")

  #initialize canopy leaf biomass profile
  sumla = matrix(0,1,max.ind)


  #loop for calculating canopy profile
  nl = 1
  for(j in 1:nspec){
    if(ntrees[j]==0) next
    nu = nl + ntrees[j] - 1
    ret = frt[j]
    for(k in nl:nu){
      age = iage[k]
      if(age < ret) ret = age

      #calculate height profile
      iht = ((b2[j]*dbh[k]-b3[j]*dbh[k]^2)/10)+1
      if(iht>700) print("trees too tall")

      #calculate and sum leaf biomass for trees of approx. the same height
      sumla[iht] = sumla[iht] + ((((slta[j] + sltb[j] * dbh[k]) / 2) ^ 2) * 3.14 * fwt[j] * ret)
    }
    nl = nl + ntrees[j]
  }

  #calculate cumulative leaf biomass down through the canopy
  #for(j in 1:699){
    j1 = 700-1:699
    sumla[j1] = sumla[j1] + sumla[j1 + 1]
  #}

  #main loop for calculating diameter increment
  nl = 1
  for(i in 1:nspec){
    if(ntrees[i] == 0) next
    nu = nl + ntrees[i] - 1
    for(j in nl:nu){
      #calulate leaf biomass of all taller trees (slar)
      ht = b2[i]*dbh[j] - b3[i]*dbh[j]^2
      iht = ht/10 + 2
      if(iht < 1) iht = 1 #added to avoid error with sumla
      slar = sumla[iht]
      if(is.na(slar)) slar <- sumla[which.max(!is.na(sumla))]

      #calculate available light to this tree (% full sunlight)
      al = 1 * exp(-slar/93750)

      #calculate available light multiplier if tree is shade intolerant
      if(itol[i] >= 2) {
        algf = 2.24 * (1 - exp(-1.136 * (al - .08)))
      } else {
        algf = 1 - exp(-4.64 * (al - .05))
      }

      if(length(algf)>1){
        #print(algf)
        algf = algf[1]
      }

      if(is.na(algf)){
        browser()
        algf <- 1
      }

      if(algf < 0) algf = 0
      algf.save[j,i] <- algf

      #calculate maximum tree volume
      gr = (137 + .25 *(( b2[i]^2 )/ b3[i])) * (.5 * b2[i] / b3[i])

      #calculate diameter increment under optimal conditions
      dncmax = g[i] * dbh[j] * (1 - (137 * dbh[j] + b2[i] * dbh[j]^2 - b3[i] * (dbh[j]^3)) / gr) / (274 + 3 * b2[i] * dbh[j] - 4 * b3[i] * dbh[j]^2)

      #choose smallest growth multiplier for this tree
      gf = min(algf, smgf[i], sngf[i], degdgf[i])
      if(is.na(gf)) gf = 0

      gf.vec[j,i,1:4] = c(algf, smgf[i], sngf[i], degdgf[i])
      #print(gf==gf.vec)
      #print(gf.vec)

      #reduce diameter increment to the extent that conditions are less than optimum for growth
      dinc = dncmax*gf
      #if(dinc < .1) dinc = .1

      #check if increment is less than minimum required for growth. if dinc less than 1 mm or 10% of ndcmax or if january temp is less than frost tolerance, flag tree in nogro
      #if(dinc < .1*dncmax | frost[i] > rt[1]) dinc = 0
      if(dinc >= .25*dncmax) nogro[j] = 0
      if(dinc < .25*dncmax) nogro[j] = nogro[j] - 1

      #calculate woody biomass (kg) before incrementing diameter
      ab1 = .1193 * dbh[j] ^ 2.393

      #increment diameter
      dbh[j] = dbh[j] + dinc

      #if(dbh[j]>10) print(i)
      #calculate woody biomass after incrementing diameter
      ab2 = .1193 * dbh[j] ^ 2.393

      #calculate net increase in woody biomass (aboveground woody production in kg)
      awp[j] = ab2 - ab1
    }
    gf.vec.means[i,1:4] = colMeans(gf.vec[,i,1:4]) #matrix(NA, nrow=nspec, ncol = 4)
    nl = nl + ntrees[i]
  }
  }
  return(list(ntrees = ntrees, dbh = dbh, awp = awp, nogro = nogro, gf.vec = gf.vec.means, algf.save = algf.save))
}

#
#
#
#
#
#

grow.opt <- function(max.ind,nspec,ntrees,frt,slta,sltb,dbh,fwt, b2,b3, itol,g,
                 degdgf,smgf,sngf,frost,rt,iage,nogro){
  #initialize wood production
  awp = matrix(0,1,max.ind)
  algf.save <- matrix(NA,max.ind,nspec)
  npp.spp <- numeric(nspec)

  #calculate total number of trees
  ntot = 0
  ntot = sum(ntrees[1:nspec])
  gf.vec <- matrix(NA, nrow=nspec, ncol = 4)
  if(ntot != 0){
    if(ntot > max.ind) print("too many trees -- grow")

    #initialize canopy leaf biomass profile
    sumla = matrix(0,1,700)
    
    #get species list 
    spp.ind = c()
    for (k in 1:nspec){
      spp.ind = c(spp.ind, rep(k, ntrees[k]))
    }

    #loop for calculating canopy profile tree-by-tree
    for (j in 1:ntot){
      
      # gather information about this tree
      sp = spp.ind[j]
      ret = frt[sp]
      age = iage[j]
      if (age < ret) ret = age 
      
      # calculate height profile
      iht = ((b2[sp]*dbh[j]-b3[sp]*dbh[j]^2)/10)+1
      if (iht < 1) iht = 1
      if (iht > 700) print("trees too tall")
      
      #calculate leaf biomass for tree and add it to the appropriate canopy level 
      sumla[iht] = sumla[iht] + ((((slta[sp] + sltb[sp] * dbh[j]) / 2) ^ 2) * 3.14 * fwt[sp] * ret)
    }
    
    # MK: removed this because it does not correctly increment foliage weight when there is more than one tree of 
    # the same height and species (July 2020)
    #nl = 1
    #for(j in 1:nspec){
    #  if(ntrees[j]==0) next
    #  nu = nl + ntrees[j] - 1
    #  ret = frt[j]
    #    age = iage[nl:nu]
    #    ret <- matrix(frt[j],length(age))
    #    ret[age < ret] = age[age < ret]

    #    #calculate height profile
    #    iht = ((b2[j]*dbh[nl:nu]-b3[j]*dbh[nl:nu]^2)/10)+1
    #    iht[iht<1] <- 1
    #    if(any(which(iht>700))) print("trees too tall")

    #    #calculate and sum leaf biomass for trees of approx. the same height
    #    sumla[iht] = sumla[iht] + ((((slta[j] + sltb[j] * dbh[nl:nu]) / 2) ^ 2) * 3.14 * fwt[j] * ret)
    #  nl = nl + ntrees[j]
    #}

    #calculate cumulative leaf biomass down through the canopy
    # MK: the following recursive method does not correctly calcuulate cumulative foliage weight (July 2020)
    #j1 = 700-1:699
    #sumla[j1] = sumla[j1] + sumla[j1 + 1]
    sumla <- rev(cumsum(rev(sumla)))

    #main loop for calculating diameter increment
    nl = 1
    npp.spp <- numeric(nspec)
    for(i in 1:nspec){
      if(ntrees[i] == 0) next
      nu = nl + ntrees[i] - 1
        #calulate leaf biomass of all taller trees (slar)
        ht = b2[i]*dbh[nl:nu] - b3[i]*dbh[nl:nu]^2
        iht = ht/10 + 2
        iht[iht < 1] = 1 #added to avoid error with sumla
        slar = sumla[iht]


        #calculate available light to this tree (% full sunlight)
        al = 1 * exp(-slar/93750)

        #calculate available light multiplier if tree is shade intolerant
        if(itol[i] >= 2) {
          algf = 2.24 * (1 - exp(-1.136 * (al - .08)))
        } else {
          algf = 1 - exp(-4.64 * (al - .05))
        }

        algf[algf < 0] = 0

        #calculate maximum tree volume
        gr = (137 + .25 *(( b2[i]^2 )/ b3[i])) * (.5 * b2[i] / b3[i])

        #calculate diameter increment under optimal conditions
        dncmax = g[i] * dbh[nl:nu] * (1 - (137 * dbh[nl:nu] + b2[i] * dbh[nl:nu]^2 - b3[i] * (dbh[nl:nu]^3)) / gr) / (274 + 3 * b2[i] * dbh[nl:nu] - 4 * b3[i] * dbh[nl:nu]^2)

        #choose smallest growth multiplier for this tree
        #browser()
        gf = apply(rbind(algf, smgf[i], sngf[i], degdgf[i]),2,min)
        gf[is.na(gf)] <- 0

        algf.save[nl:nu,i] <- algf

        gf.vec[i,1:4] <- c(mean(algf), smgf[i], sngf[i], degdgf[i])

          #c(algf, rep(smgf[i],length(nl:nu)),
                        #        rep(sngf[i],length(nl:nu)),
                        #        rep(degdgf[i],length(nl:nu)))
        #print(gf==gf.vec)
        #print(gf.vec)

        #reduce diameter increment to the extent that conditions are less than optimum for growth
        dinc = dncmax*gf
        #if(dinc < .1) dinc = .1

        #check if increment is less than minimum required for growth. if dinc less than 1 mm or 10% of ndcmax or if january temp is less than frost tolerance, flag tree in nogro
        #if(dinc < .1*dncmax | frost[i] > rt[1]) dinc = 0
        
        # If the trees are too chilly, make them not grow
        if(frost[i] > rt[1]) dinc = 0
        # Flag as NOGRO only because of slow growth
        # MK: changed the minimum value considered for NOGRO from 0.15 to 0.1, which was the original model value
        nogro[nl:nu] = ifelse(dinc >= .1*dncmax, 0, nogro[nl:nu] - 1)

        #nogro[nl:nu] = ifelse(frost[i] > rt[1], 0, nogro[nl:nu] - 1)
        #nogro[nl:nu] = ifelse(dinc >= .15*dncmax, 0, nogro[nl:nu] - 1)

        #calculate woody biomass (kg) before incrementing diameter
        ab1 = .1193 * dbh[nl:nu] ^ 2.393

        #increment diameter
        dbh[nl:nu] = dbh[nl:nu] + dinc

        #if(dbh[j]>10) print(i)
        #calculate woody biomass after incrementing diameter
        ab2 = .1193 * dbh[nl:nu] ^ 2.393

        #calculate net increase in woody biomass (aboveground woody production in kg)
        awp[nl:nu] = ab2 - ab1
        npp.spp[i] <- sum(awp[nl:nu])

      nl = nl + ntrees[i]

    }

  }
  #browser()
  return(list(ntrees = ntrees,npp.spp=npp.spp, dbh = dbh,
              awp = awp, nogro = nogro, gf.vec = gf.vec, algf.save = algf.save))
}


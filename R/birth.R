
##' @title LINKAGES birth function
##' @author Ann Raiho
##'
##' @param nspec number of species
##' @param ntrees number of trees of each species
##' @param iage age of each individual
##' @param dbh diameter of each individual
##' @param mplant maximum seeding in rate per plot
##' @param sprtnd number of sprouts per stump
##' @param frt foliage retention time
##' @param slta parameter to calculate crown area from diameter
##' @param sltb parameter to calculate crown area from diameter
##' @param fwt leaf weight per unit crown area
##' @param dmin degree day minimum for each species
##' @param dmax degree day maximum for each species
##' @param spp.num species code for each species
##' @param frost minimum January temperature tolerated
##' @param rt current monthly temperatures
##' @param itol shade tolerance code for each species
##' @param degd growing degree days from tempe.R
##' @param nogro flags individuals that aren't growing well
##' @param ksprt flags individuals that could sprout
##' @param max.ind maximum number of individuals in a plot
##' @param smgf soil moisture growing factor from gmult.R
##' @param degdgf growing degree day growing factor from gmult.R
##'
##' @description    BIRTH CALCULATES SEEDLING AND SPROUT BIRTH BASED ON
##'    SPECIES FECUNDITY, SEEDBED CONDITIONS, SUSCEPTIBILITY TO BROWSING,
##'    AND THE DEGREE TO WHICH LIGHT, SOIL MOISTURE, AND DEGREE DAYS ARE
##'    LESS THAN OPTIMUM FOR GROWTH. SOIL MOISTURE AND DEGREE DAY
##'    MULTIPLIERS ARE SUPPLIED BY SUBROUTINE GMULT.
##'    A SPECIES CAN HAVE SPROUTS IF AT LEAST ONE
##'    TREE WITH DIAMETER BETWEEN SPRTMN AND SPRTMX DIED LAST
##'    YEAR (KSPRT INCREMENTED BY 1 IN KILL).
##'    RANDOM NUMBERS USED TO DETERMINE OCCURENCE OF BROWSING, NUMBERS
##'    OF SEEDLINGS AND SPROUTS, AND DBH SUPPLIED BY rand.
##'
##' @return iage age of each individual
##' @return dbh diameter of each individual
##' @return nogro flags individuals growing slowly
##' @return ntrees number of trees of each species
##' @return newtr records species considered 'eligible'
##' @return ksprt flags individuals that could sprout
##' @export
##'
birth <- function(nspec,ntrees,frt,iage,slta,sltb,spp.num,dbh,fwt,
                  degd,dmin,dmax,frost,rt,itol,mplant,nogro,ksprt,sprtnd,
                  max.ind,smgf,degdgf){

  max.seeds <- round(max.ind/nspec)-1 #needs to be less than max.ind
  if((max.ind - (max.seeds*nspec)) < 0) {
   print('Imbalance between max.ind and max.seeds and nspec. See birth subroutine.')
   stop()
  }

if(sum(ntrees) < max.ind){
  
  #switch.mat1 = matrix(as.logical(switch.mat),nspec,5)

  #initialize foliage biomass (folw) and foliage area (fola)
  folw = 0
  fola = 0
  nl = 1

  #calculate leaf weight in G/plot and leaf area index
  for(i in 1:nspec){
    if(ntrees[i] == 0) next
      nu = nl + ntrees[i] - 1
      ret = frt[i]
      for(k in nl:nu){
        age = iage[k]
        if(age<ret){
          ret = age
          folw = folw + ((slta[i]+sltb[i]*dbh[k])/2)^2*(3.14*fwt[i]*ret)
          fola = fola + ((1.9283295) * 10^-4)*((dbh[k])^2.129)
        }
      }
      nl = nl + ntrees[i]
  }

  fola[is.na(fola)] <- 0
  #calculate amount of light at forest floor
  al = 1 * exp(-folw/93750)
  #calculate number of trees in stand
  ntot = nl - 1
  
  #determine which species are eligible for planting this year
  #swtch = rep(NA,5) #added this AMR
  #switch 1 is true if the spp requires leaf litter for successful recruitment
  #switch 2 is true if the spp requires minerl soil
  #switch 3 is true if the spp recruitment is reduced by hot year
  #switch 4 is true if the species is a preferred food of deer or small mammals
  #switch 5 reduces seedling rate of desirable mast
  #swtch[1:5] = TRUE
  #swtch[3] = FALSE

  #set switches based on value of leaf area, degree day, and random number
  #if(fola>=1) swtch[1] = FALSE
  #if(fola<=2) swtch[2] = FALSE

  #browse - a random number simulating the occurence of browsing
  #yfl = runif(1,0,1)
  #browse = yfl
  #if(browse > .5) swtch[4] = FALSE
  #if(fola <= .05) swtch[5] = FALSE
  nw = 0

  newtr = matrix(0,1,100) #added this AMR

  # end recruitment of aspen, pin cherry, and most pine if available light is < 60% of full sunlight and 
  # recruitment of paper birch and white pine if available light is <30% of full sunlight
  for(i in 1:nspec){
    
     code = spp.num[i]
     
     if(al<.60 & code == 'PRPE2') next # pin cherry, 
     if(al<.30 & code == 'LITU') next # yellow poplar
    
     if(al<.60 & code == 'POBA2') next # balsam poplar
     if(al<.60 & code == 'POGR4') next # bigtooth aspen
     if(al<.60 & code == 'POTR5') next # quaking aspen

     if(al<.60 & code == 'PIBA2') next # jack pine
     if(al<.60 & code == 'PIEC2') next # shortleaf pine
     if(al<.60 & code == 'PIRE') next # red pine
     if(al<.30 & code == 'PIST') next # white pine
     if(al<.60 & code == 'PITA') next # loblolly pine
     if(al<.60 & code == 'PIVI2') next # virginia pine
     if(al<.30 & code == 'BEPA') next # paper birch

    #if(switch.mat1[i,3] & swtch[3]) next
    #if(switch.mat1[i,4] & swtch[4]) next #the deer are eating too much. Who decided this should always be true??
    #if(switch.mat1[i,5] & swtch[5]) next

    #allow only those spp whose degree day tolerances span the simulated degree days this year to be eligible for seeding
    if(degd <= dmin[i] | degd >= dmax[i]) {
       print(paste('spp',i,'did not make it past degd dmin dmax step in birth.R'))
       next
    }
    #allow only those species whose frost tolerance is less than the January mean temperature to be eligible for seeding
    if(frost[i] > rt[1]) {
      print(paste('skipping',i,'in birth.R because of frost param'))
        next
    }
    #place eligible species numbers in array newtr
    nw = nw + 1
    newtr[nw] = i
  }

  #check to see if there are any new trees
  if(nw != 0){
    #place iage, dbh, and nogro into temporary arrays
    itemp = iage; dtemp = dbh; ntemp = nogro
    
    #create vector to store possible seed bank for this year  
    seed.ind = c()
    
    #begin loop to determine nplant for each species
    for(k in 1:nw){
      nsp = newtr[k]
      
      #calculate seedling light multipliers
      slite = 1.5 * (1 - exp(-1.136*(al-.08)))
      if(itol[nsp] < 2) slite = 1 - exp(-4.64*(al-.05))
      if(slite <= 0) slite = 0
      
      #reduce max number of seedlings to the extent that light, soil moisture, and degree days are less than optimum for growth of each species
      
      yfl = runif(1,0,1)
      nplant = mplant[nsp] * slite * smgf[nsp] * degdgf[nsp] * yfl
      
      #see if any stumps of this spp are available for sprouting
      if(ksprt[nsp] > 0 & sprtnd[nsp] > 0){
        yfl = .5 #runif(1,0,1)
        #if available light is greater than 50% of full sunlight determine number of stump sprouts and add to nplant
        if(al >= .5) nplant = nplant + (sprtnd[nsp]*slite*smgf[nsp]*degdgf[nsp]*ksprt[nsp]) #*yfl
        #if(nplant > max.seeds) nplant = max.seeds #HACK
      }
      
      #add the seeds for this species to the seed bank 
      #this rounds nplant down to the first whole integer
      seed.ind = c(seed.ind, rep(nsp, nplant))
    }
    
    #now that we have the total possible seed bank for the year, we need to determine how many seeds we can plant
    nseed = length(seed.ind)
    
    #if planting all of the seeds would cause the model to exceed max.ind, 
    #we need to randomly choose which seeds in bank will get planted
    if (sum(ntrees)+nseed > max.ind){
      
      #how many total seedlings can we plant this year?
      nposs = max.ind - sum(ntrees)
      
      #randomly draw that many seeds from seedbank without replacement
      seed.sample = sample(seed.ind, nposs, replace=FALSE)
      
    }else{
      seed.sample = seed.ind
    }
    
    
    #now we complete another loop to plant the seeds for each species 
    for(nsp in 1:nspec){

      #determine number of seeds for this species
      nplant = length(which(seed.sample == nsp))
      
      #check if there are seeds of this species to plant
      if (nplant < 1) next
      
      #plant!!
      nsum = sum(ntrees[1:nsp])
      nl = nsum + 1
      nup = ntot
      
      #loop through seeds
      for (j in 1:nplant){
        
        # increment 
        ntot = ntot + 1
        if (ntot > max.ind) print('max.ind has been exceeded')
        nsum = nsum + 1 
        ntrees[nsp] = ntrees[nsp] + 1
        itemp[nsum] = 0
        
        #calculate dbh for new trees
        size = 1.27
        yfl = .5#runif(1,0,1)
        dtemp[nsum] = size + .3 * (1 - yfl)^3
        ntemp[nsum] = 0
      }
      if (nl <= nup){
        n1 = nsum + 1
        for(l in nl:nup){
          dtemp[n1] = dbh[l]
          itemp[n1] = iage[l]
          ntemp[n1] = nogro[l]
          n1 = n1 + 1
        }
      }
      
      #reinitialize original dbh and age arrays - including new trees
      iage[1:ntot] = itemp[1:ntot]
      dbh[1:ntot] = dtemp[1:ntot]
      nogro[1:ntot] = ntemp[1:ntot]
    }
  }
  
  #reinitialize array ksprt
  ksprt[1:nspec] = 0
}else{
  print('No births this year. There are enough trees in the stand. See birth.R')
}
  #increment ages by one year
  ntot <- sum(ntrees)
  iage[1:ntot] = iage[1:ntot] + 1
  return(list(iage=iage, dbh=dbh, nogro=nogro, ntrees=ntrees, ksprt=ksprt))
}

# birth.opt <- function(nspec,ntrees,frt,iage,slta,sltb,dbh,fwt,switch.mat,
#                   degd,dmin,dmax,frost,rt,itol,mplant,nogro,ksprt,sprtnd,
#                   max.ind,smgf,degdgf){
#
#   switch.mat1 = matrix(as.logical(switch.mat),nspec,5)
#
#   #initialize foliage biomass (folw) and foliage area (fola)
#   folw = 0
#   fola = 0
#   nl = 1
#
#   #calculate leaf weight in G/plot and leaf area index
#   for(i in 1:nspec){
#     if(ntrees[i] == 0) next
#     nu = nl + ntrees[i] - 1
#     ret = frt[i]
#     for(k in nl:nu){
#       age = iage[k]
#       dbh.vec <- dbh[nl:nu]
#       age.vec <- iage[nl:nu]
#
#       folw = sum((slta[i]+sltb[i]*dbh.vec[age<ret])/2)^2*(3.14*fwt[i]*age.vec[age<ret])
#       fola = sum((1.9283295) * 10^-4)*((dbh.vec[age<ret])^2.129)
#
#     }
#     nl = nl + ntrees[i]
#   }
#
#   fola[is.na(fola)] <- 0
#   #calculate amount of light at forest floor
#   al = 1 * exp(-folw/93750)
#   #calculate number of trees in stand
#   ntot = nl - 1
#   #determine which species are eligible for planting this year
#   swtch = rep(NA,5) #added this AMR
#   #switch 1 is true if the spp requires leaf litter for successful recruitment
#   #switch 2 is true if the spp requires minerl soil
#   #switch 3 is true if the spp recruitment is reduced by hot year
#   #switch 4 is true if the species is a preferred food of deer or small mammals
#   #switch 5 reduces seedling rate of desirable mast
#   swtch[1:5] = TRUE
#   swtch[3] = FALSE
#
#   #set switches based on value of leaf area, degree day, and random number
#   if(fola>=1) swtch[1] = FALSE
#   if(fola<=2) swtch[2] = FALSE
#
#   #browse - a random number simulating the occurence of browsing
#   yfl = runif(1,0,1)
#   browse = yfl
#   if(browse > .5) swtch[4] = FALSE
#   if(fola <= .05) swtch[5] = FALSE
#   nw = 0
#
#   newtr = matrix(0,1,100) #added this AMR
#
#   # end recruitment of aspen, pin cherry, and most pine if available light is < 60% of full sunlight and recruitment of paper birch and white pine if available light is <30% of full sunlight
#   for(i in 1:nspec){
#     if(al<.60 & i == 29) next
#
#     if(al<.30 & i == 34) next
#
#     if(al<.60 & i == 60) next
#     if(al<.60 & i == 61) next
#     if(al<.60 & i == 13) next
#
#     if(al<.60 & i == 38) next
#     if(al<.60 & i == 39) next
#     if(al<.60 & i == 40) next
#     if(al<.30 & i == 41) next
#     if(al<.60 & i == 7) next
#     if(al<.60 & i == 42) next
#     if(al<.30 & i == 42) next
#
#     if(switch.mat1[i,3] & swtch[3]) next
#     if(switch.mat1[i,4] & swtch[4]) next
#     if(switch.mat1[i,5] & swtch[5]) next
#
#     #allow only those spp whose degree day tolerances span the simulated degree days this year to be eligible for seeding
#     if(degd <= dmin[i] | degd >= dmax[i]) next
#     #allow only those species whose frost tolerance is less than the January mean temperature to be eligible for seeding
#     if(frost[i] > rt[1]) next
#     #place eligible species numbers in array newtr
#     nw = nw + 1
#     newtr[nw] = i
#   }
#
#   #check to see if there are any new trees
#   if(nw != 0){
#     #place iage, dbh, and nogro into temporary arrays
#     itemp = iage; dtemp = dbh; ntemp = nogro
#     #begin main loop for planting
#     for(k in 1:nw){
#       nsp = newtr[k]
#       #calculate seedling light multipliers
#       slite = 1.5 * (1 - exp(-1.136*(al-.08)))
#       if(itol[nsp] < 2) slite = 1 - exp(-4.64*(al-.05))
#       if(slite <= 0) slite = 0
#       #reduce max number of seedlings to the extent that light, soil moisture, and degree days are less than optimum for growth of each species
#       yfl = runif(1,0,1)
#       nplant = mplant[nsp] * slite * smgf[nsp] * degdgf[nsp] * yfl
#       if(nplant>100) nplant=100 #HACK
#       #see if any stumps of this spp are available for sprouting
#       if(ksprt[nsp] > 0 & sprtnd[nsp] > 0){
#         yfl = runif(1,0,1)
#         #if available light is greater than 50% of full sunlight determine number of stump sprouts and add to nplant
#         if(al >= .5) nplant = nplant + (sprtnd[nsp]*slite*smgf[nsp]*degdgf[nsp]*ksprt[nsp]*yfl)
#         if(nplant>100) nplant=100 #HACK
#       }
#
#       nsum = sum(ntrees[1:nsp])
#
#       #print(paste(nplant,nsp))
#       #plant seedlings and sprouts
#       nl = nsum + 1
#       nup = ntot
#       if(nplant == 0) next
#       for(j in 1:nplant){
#         ntot = ntot + 1
#         if(ntot > max.ind) print(paste("too many trees -- birth -- species", i))
#         nsum = nsum + 1
#         ntrees[nsp] = ntrees[nsp] + 1
#         itemp[nsum] = 0
#         #calculate dbh for new trees
#         size = 1.27
#         yfl = runif(1,0,1)
#         dtemp[nsum] = size + .3 * (1 - yfl)^3
#         ntemp[nsum] = 0
#       }
#
#       if(nl <= nup){
#         n1 = nsum + 1
#         for(l in nl:nup){
#           dtemp[n1] = dbh[l]
#           itemp[n1] = iage[l]
#           ntemp[n1] = nogro[l]
#           n1 = n1 + 1
#         }
#       }
#
#       #reinitialize original dbh and age arrays - including new trees
#       iage = itemp
#       dbh = dtemp
#       nogro = ntemp
#
#     }
#   }
#   #increment ages by one year
#   iage[1:ntot] = iage[1:ntot] + 1
#
#   #reinitialize array ksprt
#   ksprt[1:nspec] = 0
#
#   return(list(iage=iage, dbh=dbh, nogro=nogro, ntrees=ntrees, newtr = newtr,ksprt=ksprt))
# }

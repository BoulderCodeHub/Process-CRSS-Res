##############################################################################
#This script creates annual boxplots of all traces and exceedances for 
#Powell Inflow and Outflow to compare two CRSS runs
#It is intended as an example of how Generic_annual_plot.R can be ADAPTED to 
#create a custom set of outputs

#Contents 
## 1. Set Up ##
## 2. User Input ##
## 3. Process Results ## 
## 4. Plot ## 

#   Created by C. Felletter on 10/2018 
##############################################################################

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## 1. Set Up ##
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
rm(list=ls()) #clear the enviornment 
library(RWDataPlyr)

## Directory Set Up
#Set folder where studies are kept as sub folders. 
CRSSDIR <- Sys.getenv("CRSS_DIR")

# where scenarios are folder are kept
scen_dir = file.path(CRSSDIR,"Scenario") 
#containing the sub folders for each ensemble

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## 2. User Input ##
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

list.dirs(scen_dir) #list dirs in set folder folder for us in next input

#### Normally You'll Only Change The Below ####
#scens you want to compare 
scens <- list(
  "Aug 2018" = "Aug2018_2019,DNF,2007Dems,IG,Most",
  "Aug 2018 + Fix" = "Aug2018_2019_9000,DNF,2007Dems,IG_9000,Most_BM_FGltsp"
)

list.files(file.path(scen_dir,scens[1])) #list files in scen folder for next input

#files, variables, floworpes, cyorwys, figuretypes, exc_months (if using exceed
# on PE), & customcaptions should be set to a single value
#but could be used to loop through multiple plots if additional loops were added

#rdf file with slot you want 
files <- "Res.rdf" 

#### ADAPTATION ####
#easiest if just index all plots by one loop i
variables <- c("Powell.Inflow","Powell.Pool Elevation","Powell.Outflow",
               "Powell.Inflow","Powell.Pool Elevation","Powell.Outflow")

floworpes <- c("flow","pe","flow","flow","pe","flow") #"flow" or "pe" 
cyorwys <- "cy" #"cy" or "wy". WY not tested for all plot configurations  
#could be used to loop through multiple plots with additional loops added

#### ADAPTATION ####
figuretypes <- c(2,2,2,3,3,3) #1 is Trace Mean, 2 is Bxplt of Traces, 3 is Exceedance 
# IF PICKING 3 you must specify a month
exc_months <- 12 #1 - Jan, 12 - Dec

customcaptions <- NA #NA or this will over write the default caption on boxplots 

#plot inputs 
startyr <- 2019 #filter out all years > this year
endyr <- 2026 #filter out all years > this year

#file names 
figs <- 'Powell_Annual_InOutPE' #objectslot + .pdf will be added when creating plots


#output image parameters 
width=9 #inches
height=6
imgtype = "pdf" #supports pdf, png, jpeg. pdf looks the best 

# the mainScenGroup is the name of the subfolder this analysis will be stored
#under in the results folder 
mainScenGroup <- names(scens)[1]

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#                               END USER INPUT
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#Additional plotting functions and libraries 
library('tidyverse') #ggplot2,dplyr,tidyr
library('devtools')
library(RWDataPlyr)
library(CRSSIO)
#see RWDATPlyr Workflow for more information 
# library(CRSSIO)
# plotEOCYElev() and csVarNames()
source('code/Stat_emp_ExcCrv.r')

# some sanity checks that UI is correct:
if(!(mainScenGroup %in% names(scens))) 
  stop(mainScenGroup, ' is not found in scens.')

# check folders
if(!file.exists(file.path(scen_dir, scens[1])) 
   | !file.exists(file.path(scen_dir, scens[2])))
  stop('scens folder(s) do not exist or scen_dir is set up incorrectly. 
       Please ensure scens is set correctly.')

ofigs <- file.path(CRSSDIR,'results',mainScenGroup) 
if (!file.exists(ofigs)) {
  message(paste('Creating folder:', ofigs))
  dir.create(ofigs)
}

message('Figures will be saved to: ', ofigs)

figurenames <- c("Mean","Bxplt","Exceedance")

## create a pdf  
#### ADAPTATION ####
pdf(paste0(file.path(ofigs,figs),".pdf"), width=9, height=6)

#easiest if just index all plots by one loop i
for(i in 1:length(variables)){ #loop through variables and also possibly floworpe
  #cyorwy 

   #used to loop through multiple plots 
	floworpe <- floworpes[i]
	cyorwy <- cyorwys

#y axis titles 
if (floworpe == "flow"){
  if (cyorwy == "cy"){
    y_lab = "Annual CY Flow (ac-ft/mo)"
  } else {
    y_lab = "Annual WY Flow (ac-ft/mo)"
  }
} else {
  if (cyorwy == "cy"){
    y_lab = "EOCY PE (ft)"
    peperiod = "eocy"
  } else {
    y_lab = "EOWY PE (ft)"
    peperiod = "eowy"
  }
}

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## 3. Process Results 
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#this could be used to loop through multiple plots 
file <- files 

#### ADAPTATION ####
variable = variables[i] #loop through multiple

#check slots in rdf
if(!any(rdf_slot_names(read_rdf(iFile = file.path(scen_dir,scens[1],file))) 
       # !any() checks if none in the vector are true 
        %in% variable)){ # %in% checks if variable is in the character vector
  stop(paste('Slot ',variable,' does not exist in given rdf'))
} 

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## 3. Process Results 
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
#generic agg file 
rwa1 <- rwd_agg(data.frame(
  file = file,
  slot = variable, 
  period = if (floworpe == "flow"){
    cyorwy
  } else{
    peperiod
  },
  summary = if (floworpe == "flow"){
    "sum"
  } else{
    NA
  },
  eval = NA,
  t_s = NA,
  variable = variable,
  stringsAsFactors = FALSE
))

#rw_scen_aggregate() will aggregate and summarize multiple scenarios, essentially calling rdf_aggregate() for each scenario. Similar to rdf_aggregate() it relies on a user specified rwd_agg object to know how to summarize and process the scenarios.
scen_res <- rw_scen_aggregate(
  scens,
  agg = rwa1,
  scen_dir = scen_dir
) 

unique(scen_res$Variable) #check variable names
unique(scen_res$TraceNumber) #check trace numbers 

# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
## 4. Plot Choosen Figure Type 
# +++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#this could be used to loop through multiple plots 
figuretype <- figuretypes[i]   
exc_month <- exc_months
customcaption <- customcaptions


#figure captions
if (is.na(customcaption) &  figuretype == 2){
  caption <- "Note: The boxplots show the distribution of traces, one for each year. The boxplot boxes correspond to the 25th and 75th quantiles,\nthe whiskers enclose the 10th to 90th quantiles,with points representing data that falls outside this range."
} else if (is.na(customcaption)){
  caption <- "" #no caption 
} else {
  caption <- customcaption #user supplied 
}


#    -------------------        All Trace Mean        ----------------------

print(paste("Creating ",variable," ",cyorwy," ",figurenames[figuretype]))

if (figuretype == 1){
  p <- scen_res %>%
    # dplyr::filter(Variable == variable) %>%
    dplyr::filter(startyr <= Year && Year <= endyr) %>% #filter year
    dplyr::group_by(Scenario, Year) %>%
    dplyr::summarise(Value = mean(Value)) %>%
    ggplot(aes(x = factor(Year), y = Value, color = Scenario, group = Scenario)) + 
    geom_line() +
    geom_point() +
    labs(title = paste("Mean",variable,startyr,"-",endyr), 
         y = y_lab, x = "Year", caption = caption) +
    theme(plot.caption = element_text(hjust = 0)) #left justify 
  print(p)
}

#    -------------------        All Trace Boxplot        ----------------------

if (figuretype == 2){
  p <- scen_res %>%
    # dplyr::filter(Variable == variable) %>%
    dplyr::filter(startyr <= Year && Year <= endyr) %>% #filter year
    dplyr::group_by(Scenario, Year) %>%
    ggplot(aes(x = factor(Year), y = Value, color = Scenario)) + 
    # geom_boxplot() + #generic geom uses 1.5 * IQR for the whiskers
    # custom has whiskers go to the 10th/90th
    stat_boxplot_custom(qs = c(0.1, 0.25, 0.5, 0.75, 0.9)) + 
    labs(title = paste(variable,startyr,"-",endyr), 
         y = y_lab, x = "Year", caption = caption) +  
    theme(plot.caption = element_text(hjust = 0)) #left justify 
    print(p)
}

#    -------------------        Percent Exceedance of Traces       ----------------------

if (figuretype == 3){
  p <- scen_res %>%
    # dplyr::filter(Variable == variable) %>%
    dplyr::filter(startyr <= Year && Year <= endyr) %>% #filter year
    dplyr::group_by(Scenario, Year) %>%
    ggplot(aes(Value, color = Scenario)) + 
    stat_eexccrv() + 
    labs(title = paste(variable,"Trace Exceedance",startyr,"-",endyr), 
         y = y_lab, caption = caption) +
    scale_x_continuous("Year",labels = scales::percent) + 
    theme(plot.caption = element_text(hjust = 0)) #left justify 
  print(p)
}

## save off image, disabled for multiple plots 
#ggsave(filename = paste0(file.path(ofigs,figs),"_",variable,"_",cyorwy,"_",figurenames[figuretype],".",imgtype), width = width, height = height, units ="in")

#### ADAPTATION ####
} #close i loop

dev.off()

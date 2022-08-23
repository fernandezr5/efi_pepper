#' ---
#' title: "Differential Effect of Glucose Regulating Drugs on the Onset and Progression of Frailty"
#' subtitle: "Clustering longitudinal trajectories"
#' author:
#'  - Roman Fernandez, M.S.
#'  - Alex Bokov, Ph.D.
#'  - Sara Espinoza, M.D.
#'  - Tiffany Cortez, M.D.
#' css: "production.css"
#' output:
#'   html_document:
#'     keep_md: true
#'     toc: true
#'     toc_float: true
#' ---
#'
#+ init, echo=FALSE, message=FALSE, warning=FALSE,results='hide'
# Init ----
#
.debug <- 0;
.seed <- 123412345;

library(dplyr);
library(rio);     # format-agnostic convenient file import
library(pander);  # auto-formatting for HTML/Word/LaTeX
library(printr);  # auto-formatting of tables for HTML/Word/LaTeX?
library(table1);
library(forcats);
library(dint);    # date-conversion
library(ggplot2); # visualization
library(kmlShape);
#library(latrend); # clustering time series
options(max.print=42);
options(latrend.id='patient_num',latrend.time='age_at_visit_days');
pander::panderOptions('table.alignment.default','right');
pander::panderOptions('table.alignment.rownames','right');
pander::panderOptions('table.split.table',Inf);
pander::panderOptions('table.split.cells',Inf);
pander::panderOptions('p.wrap','');
pander::panderOptions('p.copula',', and ');
pander::panderOptions('missing','-');
# theme_set(theme_bw(base_family = 'serif',base_size=14) +
#             theme(strip.background = element_rect(fill=NA,color=NA)
#                   ,strip.text = element_text(size=15)));
knitr::opts_chunk$set(echo=.debug>0, warning=.debug>0, message=.debug>0);


source('default_config.R');
# The local path names for the data files should be stored in a vector
# named `inputdata` that get set in a script named `local_config.R`
if(file.exists('local_config.R')) source('local_config.R');

dat0 <- import(inputdata['analyzeme'],colClasses=cClasses);
efi0 <- import(inputdata['efixwalk'],colClasses=cClasses);
efi1 <- dat0[,c('patient_num','start_date','age_at_visit_days')] %>% inner_join(efi0[,c('patient_num','start_date','FRAIL6MO')]);

.patkeep <- table(efi1$patient_num) %>% {names((.)[.>50])};
efi2 <- subset(efi1[,c('patient_num','age_at_visit_days','FRAIL6MO')],patient_num %in% .patkeep)
efi2clds <- cldsLong(efi2);
efi2clds2 <- cldsLong(mutate(efi2,age_at_visit_days=age_at_visit_days-min(age_at_visit_days)) %>% #select(-delta) %>%
                        data.frame());

set.seed(.seed);
reduceTraj(efi2clds,nbSenators=200,nbTimes=50);
reduceTraj(efi2clds2,nbSenators=200,nbTimes=50);

cldsefi1cshapeC5T10 <- kmlShape(efi2clds,5,timeScale = 10,toPlot = F);
cldsefi1cshapeC5T1 <- kmlShape(efi2clds,5,timeScale = 1,toPlot = F);
cldsefi1cshapeC5T01 <- kmlShape(efi2clds,5,timeScale = 0.01,toPlot = F);
cldsefi1cshapeC5T001 <- kmlShape(efi2clds,5,timeScale = 0.001,toPlot = F,parAlgo = parKmlShape(maxIter = 300));

cldsefiNclust <- list();
for(ii in 1:10) cldsefiNclust[[ii]] <- kmlShape(efi2clds,ii,toPlot = F);

cldsefi1cshapeC5T10_2 <- kmlShape(efi2clds2,5,timeScale = 10,toPlot = F);
cldsefi1cshapeC5T1_2 <- kmlShape(efi2clds2,5,timeScale = 1,toPlot = F);
cldsefi1cshapeC5T01_2 <- kmlShape(efi2clds2,5,timeScale = 0.01,toPlot = F);
cldsefi1cshapeC5T001_2 <- kmlShape(efi2clds2,5,timeScale = 0.001,toPlot = F,parAlgo = parKmlShape(maxIter = 300));

cldsefiNclust_2 <- list();
for(ii in 1:10) cldsefiNclust_2[[ii]] <- kmlShape(efi2clds2,ii,toPlot = F);

# cldsefi1cshapeC1 <- kmlShape(efi2clds,1,toPlot = F);
# cldsefi1cshapeC1 <- kmlShape(efi2clds,2,toPlot = F);
# cldsefi1cshapeC1 <- kmlShape(efi2clds,3,toPlot = F);
# cldsefi1cshapeC1 <- kmlShape(efi2clds,4,toPlot = F);
# cldsefi1cshapeC1 <- kmlShape(efi2clds,5,toPlot = F);


# plotMeans(cldsefi1cshapeC5T10);
# plotMeans(cldsefi1cshapeC5T1);
# plotMeans(cldsefi1cshapeC5T01);
# plotMeans(cldsefi1cshapeC5T001);


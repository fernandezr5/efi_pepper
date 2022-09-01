#' ---
#' title: "Differential Effect of Glucose Regulating Drugs on the Onset and Progression of Frailty"
#' subtitle: "Healthcare Analytics Meets Aging Research"
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
library(lme4)
library(gtsummary)
library(purrr)
#library(latrend); # clustering time series
options(max.print=42);
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
dct0 <- import(inputdata['metadata']);

#' ## Sample
#'
#' Don't let the cryptic column names in the analysis ready data discourage you.
#' We have a data dictionary where we will add display-names so that the
#' variables will be auto-substituted in figures and tables. There is additional
#' data that we need to choose variables from including _all_ diagnoses,
#' medications, and labs. So the next step will be identifying relevant groups
#' of diagnoses and medications to turn into variables.
#'
#+ sample
# sample ----
head(dat0);

sample_ind = sample(1:nrow(dat0), size = 1000, replace = F)

dat = dat0 %>%
  rename(Language=language_cd,
         `HbA1c` = medhba1c,
         `BMI` = v002_Indx__ptnts_mn,
         `Diastolic Pressure` = v005_Prsr__ptnts_mn,
         `Systolic Pressure` = v019_Prsr__ptnts_mn,
         `Temperature` = v020_Tmprtr_ptnts_mn) %>%
  #Note: Take Random Sample for testing
  filter(1:nrow(.) %in% sample_ind) %>%
  rowwise %>%
  mutate(None_ME = if_any(c(Glinides:AnyOther), isTRUE),
         None_ME = ifelse(isTRUE(None)&isFALSE(None_ME), TRUE, FALSE),
         Metformin_ME = if_any(c(Glinides:TZD, Sulfonylureas:Nsone), isTRUE),
         Metformin_ME = ifelse(isTRUE(Metformin)&isFALSE(Metformin_ME), TRUE, FALSE),
         Secretagogues_ME = if_any(c(Glinides:Sulfonylureas, AnyOther:None), isTRUE),
         Secretagogues_ME = ifelse(isTRUE(Secretagogues)&isFALSE(Secretagogues_ME), TRUE, FALSE)) %>%
  ungroup

# Fit Linear Models

formulas = c('as.numeric(None_ME)~sex_cd+Language+race_cd+age_at_visit_days+(1|patient_num)',
             'as.numeric(Metformin_ME)~sex_cd+Language+race_cd+age_at_visit_days+(1|patient_num)')

data_hold %>%
  select(grep("ME", colnames(.)))

mods1 = formulas %>%
  map(function(form) dat %>%
        mutate_if(is.numeric, scale) %>%
        (function(data_hold) glmer(formula(form), data = data_hold, family = 'binomial'))) %>%
  set_names(c('None_ME', 'Metformin_ME'))

summaries1 = mods1 %>%
  map(function(mod) mod %>%
        tbl_regression(exponentiate = T))

#'  Recode variable in





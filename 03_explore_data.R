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

#' ## Cohort Demographics
#'
#' Each patient has a long series of observations for most variables. In order
#' to generate a demographic summary, these needed to be compressed into one
#' or a few discrete values. Here, wherever the value is preceded by Max or Min
#' we are summarizing the minimum and maximum values separately for all the
#' patients. For example, `Min FRAIL6MO` shows the mean, SD, median, and range
#' of the lowest 6-month frailty score each patient ever had (stratified by
#' whether or not they died during the observation period).
#'
#+ cohort_demog
# cohort_demog ----
demog0 <- group_by(dat0,patient_num,sex_cd,language_cd,race_cd) %>%
  subset(age_at_visit_days<=coalesce(dat0$age_at_death_days,Inf) &
           age_at_visit_days >= 0 &
           start_date > birth_date & start_date > '2006-01-01') %>%
  rename(Language=language_cd,
         `HbA1c` = medhba1c,
         `BMI` = v002_Indx__ptnts_mn,
         `Diastolic Pressure` = v005_Prsr__ptnts_mn,
         `Systolic Pressure` = v019_Prsr__ptnts_mn,
         `Temperature` = v020_Tmprtr_ptnts_mn) %>%
  summarise(AgeAtStart=min(age_at_visit_days)/365.25
            ,AgeAtDeath=max(age_at_death_days)/365.25
            ,EncounterDays=length(start_date)
            ,EncounterMonths=length(unique(as.character(dint::as_date_ym(start_date))))
            ,across(where(is.numeric) & !starts_with('age') & !starts_with('Encounter') & !starts_with('MONTH'),~na_if(min(.x,na.rm=T),Inf),.names='Min {.col}')
            ,across(where(is.numeric) & !starts_with('age') & !starts_with('Encounter') & !starts_with('MONTH') & !starts_with('Min'),~na_if(max(.x,na.rm=T),-Inf),.names='Max {.col}')
            ,across(where(is.logical) & !any_of('None') & !contains('_Dgns_'),any),None=all(None)
            ,Strata=interaction(ifelse(Metformin,'Metformin',''),ifelse(Secretagogues,'Secretagogues',''),ifelse(AnyOther,'Other',''),ifelse(None,'None',''),sep='+')
  ) %>% ungroup %>%
  mutate(Language=fct_lump_n(Language,2) #,vs=ifelse(is.na(AgeAtDeath),'Living','Deceased')
         ,Strata=as.character(Strata) %>% gsub('^[+]+|[+]+$','',.) %>% gsub('[+]{2}','+',.));
select(demog0,-1) %>% table1(~.|Strata,data=.);

#' ## Visualizations
#'
#' Warning: these are from a random cross-sectional sample of one encounter per
#' patient, and do not yet take into account individual patient trajectories.
#'
#' Change in EFI with age (purple=24-month window, green=12-month window,
#' blue=6-month window).
#+ efi_age_plot

# First, create a random cross-sectional sample from the longitudinal data
# (i.e. one randomly selected encounter per patient)
set.seed(.seed);
xsdat0 <- subset(dat0,age_at_visit_days>=365.25*50 &
                   age_at_visit_days <= coalesce(age_at_death_days,Inf) &
                   medhba1c < 17) %>% group_by(patient_num) %>%
  slice_sample(n=1) %>% mutate(Age=age_at_visit_days/365.25) %>%
  left_join(demog0[,c('patient_num','Strata')]);

# efi_age_plot ----
ggplot(xsdat0,aes(x=Age,y=FRAIL6MO)) + geom_smooth() +
  geom_smooth(aes(y=FRAIL12MO),col='green') +
  geom_smooth(aes(y=FRAIL24MO),col='purple') + ylab('EFI');

#' 6-Month EFI vs age, stratified by type of monotherapy.
#+ drug_efi_age_plot
subset(xsdat0,!grepl('[+]',Strata)) %>% ggplot(aes(x=Age,y=FRAIL6MO,col=Strata)) + geom_smooth(alpha=0.1) +
  ylab('EFI')


#' Change in HbA1c with age. Survivor effect?
#+ hba1c_age_plot
# hba1c_age_plot ----
ggplot(xsdat0,aes(x=Age,y=medhba1c)) + geom_smooth() + ylab('HbA1c')

#' Change in HbA1c with age stratified by monotherapy
#+ drug_hba1c_age_plot
# hba1c_age_plot ----
subset(xsdat0,!grepl('[+]',Strata)) %>% ggplot(aes(x=Age,y=medhba1c,col=Strata)) + geom_smooth(alpha=0.1) + ylab('HbA1c')


#' EFI vs HbA1c. Surprising that there is an inverse relationship, but again,
#' this is not longitudinal.
#+ efi_hba1c_plot
# efi_hba1c_plot ----
ggplot(xsdat0,aes(x=medhba1c,y=FRAIL6MO)) + geom_smooth() +
  geom_smooth(aes(y=FRAIL12MO),col='green') +
  geom_smooth(aes(y=FRAIL24MO),col='purple') + ylab('EFI') + xlab('HbA1c');


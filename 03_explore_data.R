library(dplyr);
library(rio);     # format-agnostic convenient file import
library(dint);    # date-conversion
library(latrend); # clustering time series
#' The local path names for the data files should be stored in a vector
#' named `inputdata` that get set in a script named `local_config.R`
if(file.exists('local_config.R')) source('local_config.R');

dat0 <- import(inputdata['analyzeme']) %>% mutate(start_date=as.Date(start_date),patient_num=as.character(patient_num));
dct0 <- import(inputdata['metadata']);

library(dplyr);
library(DBI);
library(rio);     # format-agnostic convenient file import
library(dint);    # date-conversion
#' The local path names for the data files should be stored in a vector
#' named `inputdata` that get set in a script named `local_config.R`
if(file.exists('local_config.R')) source('local_config.R');

#' Import the main data and the EFI mappings
dat0 <- import(inputdata['samplecsv']);
efi <- import(inputdata['efixwalk']) %>%
  mutate(patient_num = as.character(patient_num));
dat1 <- left_join(dat0,efi);
export(dat1,file='DEID_EFI_HSC20210681E_20220204_9aaf19f0.tsv');


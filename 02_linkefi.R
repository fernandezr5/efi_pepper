library(dplyr);
library(tidyr);
#library(DBI);
library(rio);     # format-agnostic convenient file import
library(dint);    # date-conversion
#' The local path names for the data files should be stored in a vector
#' named `inputdata` that get set in a script named `local_config.R`
if(file.exists('local_config.R')) source('local_config.R');
savename <- gsub('[A-Za-z]+_[A-Za-z]+','DEID_EFI',basename(inputdata['samplecsv'])) %>% gsub('.csv.zip','.tsv',.);

#' Import the main data and the EFI mappings
dat0 <- import(inputdata['samplecsv']);
efi <- import(inputdata['efixwalk']) %>%
  mutate(patient_num = as.character(patient_num));
hba1c <- import(inputdata['hba1c']) %>% mutate(patient_num=as.character(patient_num));
#' Filter out the patients who don't have valid EFIs within the range of the data
dat1 <- subset(dat0,patient_num %in% efi$patient_num);
#' But for the rest, keep all available dates because some of them contain special data elements
dat2 <- left_join(dat1,efi) %>%
  left_join(hba1c[,c('patient_num','start_date','medhba1c','vfhba1c')]) %>%
  fill(medhba1c,vfhba1c,FRAIL6MO,FRAIL12MO,FRAIL24MO) %>%
  select(!any_of(c('PATIENT_IDE','patient_ide','DATE_SHIFT','date_shift','monthkey')));
message('Saving data for analysis as ',savename);
export(dat2,file=savename);


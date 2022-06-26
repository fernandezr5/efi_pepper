library(dplyr);
library(tidyr);
#library(DBI);
library(rio);     # format-agnostic convenient file import
library(dint);    # date-conversion

source('default_config.R');
#' The local path names for the data files should be stored in a vector
#' named `inputdata` that get set in a script named `local_config.R`
if(file.exists('local_config.R')) source('local_config.R');
savename <- gsub('[A-Za-z]+_[A-Za-z]+','DEID_EFI',basename(inputdata['samplecsv'])) %>% gsub('.csv.zip','.tsv',.);

#' Import the main data and the EFI mappings
dat0 <- import(inputdata['samplecsv'],colClasses=cClasses);

#' Columns containing nested data that takes up a lot of memory and isn't really
#' analysis-ready
json_cols <- names(dat0) %>% grep('_cd$|_mn$|_tf$',.,inv=T,val=T) %>% grep('^v[0-9]',.,val=T);

efi <- import(inputdata['efixwalk'],colClasses=cClasses);
#' Import various de-identified data elements to link
hba1c <- import(inputdata['hba1c'],colClasses=cClasses);
gludrugs <- import(inputdata['gludrugs'],colClasses=cClasses);

#' Filter out the patients who don't have valid EFIs within the range of the data
dat1 <- subset(dat0,patient_num %in% efi$patient_num);
#' But for the rest, keep all available dates because some of them contain special data elements
dat2 <- left_join(dat1,efi) %>%
  left_join(gludrugs) %>%
  left_join(hba1c[,c('patient_num','start_date','medhba1c','vfhba1c')]) %>%
  fill(medhba1c,vfhba1c,FRAIL6MO,FRAIL12MO,FRAIL24MO) %>%
  select(!any_of(c('PATIENT_IDE','patient_ide','DATE_SHIFT','date_shift','monthkey')));
dat3 <- select(dat2,!any_of(json_cols));

message('Saving full data as ',savename);
export(dat2,file=savename);
message('Saving analytic-only data as ',nojsonsavename <- gsub('^DEID_EFI_','DEID_EFI_NOJSON_',savename));
export(dat3,file=nojsonsavename);


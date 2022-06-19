library(dplyr);
library(DBI);
library(rio);     # format-agnostic convenient file import
library(dint);    # date-conversion

#' The local path names for the data files should be stored in a vector
#' named `inputdata` that get set in a script named `local_config.R`
if(file.exists('local_config.R')) source('local_config.R');

#' ### Create the Patient-Date crosswalk.
file.copy(inputdata['fullsqlfile'],fullsql<-file.path(tempdir,'fullsql.db'));
fullsqlcon <- dbConnect(RSQLite::SQLite(), fullsql);
deid_patdate <- dbGetQuery(fullsqlcon
                           ,'SELECT DISTINCT patient_num,start_date FROM observation_fact') %>%
  mutate(patient_num=as.character(patient_num)
         ,start_date=as.Date(start_date)) %>% unique;
#' Import the patmap and EFI
id_efidate <- import(inputdata['efi']) %>% mutate(MON=as.Date(MON));
id_patmap <- import(inputdata['patmap']) %>%
  mutate(PATIENT_NUM=as.character(PATIENT_NUM));
#'
#' Either one of `id_xwalk_patdateefi` or `deid_xwalk_patdateefi` is
#' sufficient to attach an EFI to every patient-date combo for which one is
#' available. Recommend using the deidentified one, of course.
id_xwalk_patdateefi <- subset(id_patmap,grepl('^Z',PATIENT_IDE)) %>%
  inner_join(deid_patdate,.,by=c('patient_num'='PATIENT_NUM')) %>%
  mutate(monthkey = last_of_month(start_date - DATE_SHIFT)) %>%
  left_join(id_efidate,by=c('PATIENT_IDE'='PAT_ID','monthkey'='MON'));
deid_xwalk_patdateefi <- select(id_xwalk_patdateefi
                                ,-c('PATIENT_IDE','DATE_SHIFT','monthkey'));
#' ### Saving files out
#' The below is the item that is referenced in `inputdata['efixwalk']`
export(deid_xwalk_patdateefi,'DEID_Xwalk_PatDateEFI.tsv');
export(id_xwalk_patdateefi,'ID_Xwalk_PatDateEFI.tsv');

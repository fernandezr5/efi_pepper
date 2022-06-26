library(dplyr);
library(DBI);
library(rio);     # format-agnostic convenient file import
library(dint);    # date-conversion
library(digest);

source('default_config.R');
#' The local path names for the data files should be stored in a vector
#' named `inputdata` that gets set in a script named `local_config.R`
if(file.exists('local_config.R')) source('local_config.R');

# Verify that the three original raw files are still the same and try to exit
# if they are not.
.current_digests <- sapply(inputdata[1:3],digest::digest,file=T);

if(!identical(.current_digests
              ,c(fullsqlfile="6a16692a07c116e1559b09cbe0b92268"
                 ,patmap="96d0fa0e6c247eb6349ef83d28d84064"
                 ,efi="5d52569b3037d72c6e481038d931f7d9"))){

  rstudioapi::restartSession(command="warning('The original raw data files seem to be corrupted! You should not proceed further. Ask Alex to restore them from backup!')");
  stop('The original raw data files seem to be corrupted! You should not proceed further. Ask Alex to restore them from backup!');
  NOFUNCTION();
};

#' ## Create the Patient-Date crosswalk.
fullsql <- file.path(tempdir,'fullsql.db');
if(!file.exists(fullsql) || digest::digest(fullsql,file=T) != "6a16692a07c116e1559b09cbe0b92268"){
  file.copy(inputdata['fullsqlfile'],fullsql<-file.path(tempdir,'fullsql.db'))};
fullsqlcon <- dbConnect(RSQLite::SQLite(), fullsql);
deid_patdate <- dbGetQuery(fullsqlcon
                           ,'SELECT DISTINCT patient_num,start_date FROM observation_fact') %>%
  mutate(patient_num=as.character(patient_num)
         ,start_date=as.Date(start_date)) %>% unique;

deid_hba1c <- dbGetQuery(fullsqlcon
                         ,'SELECT encounter_num,patient_num,concept_cd,start_date,nval_num,valueflag_cd
                           FROM observation_fact
                           WHERE concept_cd IN ("LOINC:17856-6","LOINC:4548-4","LOINC:4549-2","LOINC:62388-4","LOINC:LG51070-7")'
                         ) %>%
  mutate(patient_num=as.character(patient_num)
         #,encounter_num=as.character(encounter_num)
         ,start_date=as.Date(start_date)) %>% group_by(patient_num,start_date) %>%
  summarise(concept_cd=paste0(unique(concept_cd),collapse=';')
            ,minhba1c=min(nval_num,na.rm=T)
            ,medhba1c=median(nval_num,na.rm=T)
            ,maxhba1c=max(nval_num,na.rm=T)
            ,vfhba1c=paste0(setdiff(valueflag_cd,'@'),collapse=';')) %>%
  arrange(patient_num,start_date);
#' Import the patmap and EFI
id_efidate <- import(inputdata['efi']) %>% mutate(MON=as.Date(MON));
id_patmap <- import(inputdata['patmap']) %>%
  mutate(PATIENT_NUM=as.character(PATIENT_NUM));

consort_counts <- list();
xwalk_patdateefi0 <- subset(id_patmap,grepl('^Z',PATIENT_IDE)) %>%
  inner_join(deid_patdate,.,by=c('patient_num'='PATIENT_NUM')) %>%
  mutate(monthkey = last_of_month(start_date - DATE_SHIFT)) ;
# patients that could not be mapped to an Epic ID
consort_counts$pat_no_patmapid <- list(deid=setdiff(deid_patdate$patient_num,xwalk_patdateefi0$patient_num));
consort_counts$pat_no_patmapid$days <- nrow(deid_patdate)-nrow(xwalk_patdateefi0);
# patients who were mapped to an Epic ID but for whom no EFI was found
consort_counts$pat_no_efiid <- list(id=setdiff(xwalk_patdateefi0$PATIENT_IDE,id_efidate$PAT_ID));
xwalk_patdateefi1 <- subset(xwalk_patdateefi0,!PATIENT_IDE %in% consort_counts$pat_no_efiid$id);
consort_counts$pat_no_efiid$deid <- setdiff(xwalk_patdateefi0$patient_num,xwalk_patdateefi1$patient_num);
consort_counts$pat_no_efiid$days <- nrow(xwalk_patdateefi0)-nrow(xwalk_patdateefi1);
# patients with an EFI but not during the periods in the scope of the data-pull
.patmonthinrange <- xwalk_patdateefi1[,c('PATIENT_IDE','monthkey')] %>% setNames(c('PAT_ID','MON')) %>% intersect(id_efidate[,1:2]);
xwalk_patdateefi2 <- subset(xwalk_patdateefi1,PATIENT_IDE %in% .patmonthinrange$PAT_ID);
consort_counts$pat_allefioor <- list(deid=setdiff(xwalk_patdateefi1$patient_num,xwalk_patdateefi2$patient_num));
consort_counts$pat_allefioor$days <- nrow(xwalk_patdateefi1)-nrow(xwalk_patdateefi2);
# only the visits where EFIs are available
xwalk_patdateefi3 <- inner_join(xwalk_patdateefi2,id_efidate,by=c('PATIENT_IDE'='PAT_ID','monthkey'='MON'));
consort_counts$pat_someefioor <- list(days=nrow(xwalk_patdateefi2)-nrow(xwalk_patdateefi3));

#'
#' Either one of `id_xwalk_patdateefi` or `deid_xwalk_patdateefi` is
#' sufficient to attach an EFI to every patient-date combo for which one is
#' available. Recommend using the deidentified one, of course.
id_xwalk_patdateefi <- xwalk_patdateefi3;
  # subset(id_patmap,grepl('^Z',PATIENT_IDE)) %>%
  # inner_join(deid_patdate,.,by=c('patient_num'='PATIENT_NUM')) %>%
  # mutate(monthkey = last_of_month(start_date - DATE_SHIFT)) %>%
  # left_join(id_efidate,by=c('PATIENT_IDE'='PAT_ID','monthkey'='MON'));
deid_xwalk_patdateefi <- select(id_xwalk_patdateefi
                                ,-c('PATIENT_IDE','DATE_SHIFT','monthkey'));
#' ### Saving files out
#' The below is the item that is referenced in `inputdata['efixwalk']`
export(deid_xwalk_patdateefi,'DEID_Xwalk_PatDateEFI.tsv');
export(id_xwalk_patdateefi,'ID_Xwalk_PatDateEFI.tsv');
export(deid_hba1c,'DEID_HBA1c.tsv');
save(consort_counts,file='consort_counts.rdata');

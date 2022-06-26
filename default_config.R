# Please copy this file to `local_config.R` and change the file paths as needed
# to reflect the configuration of your computer. I recommend copying the files
# specified by by `analyzeme` and `metadata` to your local computer and updating
# just those file paths, and leaving everything else as-is.
#
# The purpose of this file is to isolate all the things that change based on
# who is running the scripts and why, so that we don't have to keep making and
# unmaking configurational changes to the scripts themselves.
#
# This file is never read by the scripts-- it serves as a thoroughly documented
# example of what settings exist. However, the scripts will not run until you
# do create a copy named `local_config.R`

###################
# Global Settings #
###################

cClasses <- list(character='patient_num',Date='start_date');

##################
# Local Settings #
##################

# The below variable is so you can specify file names without having to type out
# a long folder path before each one. You don't have to use it, and you can
# specify additional folders in that path, not only file (see example below for)
# how this is done. The strange-looking "r{...}" syntax is NOT a typo: when
# using Windows network paths, it is needed to prevent R from interpreting
# backslashes as escape characters.
shared_filepath <- r"{\\ifs.win.uthscsa.edu\G2300-Barshop\Projects\Clinical Research\1. Pepper Center Regulatory Files\Cortes\21-20210681EX Regulatory Binder\Differential_effect\Data\}";

inputdata <- c(

  # STAGE 0
  # You don't actually need the following three files for ordinary activities.
  # We only use them to create de-identified crosswalks.

  # the i2b2 database extract that is currently used to create crosswalk files
  # in 01_makemappings.R
  fullsqlfile=paste0(shared_filepath,"LDS Raw Data (do not alter)\\2022-02-04T15%3A51%3A42.717847-bokov_Cortes_HSC20210681E_20220204.db"),

  # !!PHI!! Mapping file for re-identifying patients and un-shifting encounter
  # dates for each patient
  patmap=paste0(shared_filepath,"PHI Raw Data (do not alter)\\DATABUILDER_PAT_LIST_MAP.csv"),

  # !!PHI!! Actual frailty scores for each patient-month combo. The actual
  # EPIC IDs and real dates are used in this table.
  efi=paste0(shared_filepath,"PHI Raw Data (do not alter)\\EFI_FRAILTY_ALL.csv"),


  # STAGE 1
  # A random sample of patients (40%) from the i2b2 database extract (otherwise
  # identical to above) that is the basis for the `samplecsv` file below
  samplesqlfile=paste0(shared_filepath,"00 LDS DataFinisher Data\\sample30_HSC20210681E_20220204.db"),

  # The actual file (from above random 40% sample) that currently gets
  # crosswalked by 02_linkefi.R to create the analyzable data
  samplecsv=paste0(shared_filepath,"00 LDS DataFinisher Data\\DF_sample_HSC20210681E_20220204_9aaf19f0.csv.zip"),

  # This is a table based on EFI_FRAILTY_ALL.csv but thanks to 01_makemappings.R
  # is now indexed by the same non-identifying `patient_num` as used by i2b2 and
  # instead of months has specific `start_date` values shifted in exactly the
  # same way as i2b2 does. This makes it a standalone de-identified EFI dataset
  # we can link to the also de-identified i2b2 raw data without ever needing to
  # touch PHI.
  # Why even have it as a separate file? Instead of already linked to the i2b2
  # data? In fact, that's what we do in 02_linkefi.R. But we will go through
  # several iterations of the i2b2 extract (the file specified by the `samplecsv`
  # variable) as we think of more new items to include.
  # Each time we do, we won't have to go all the way back to the PHI in Stage 0
  # we can re-link it to EFI using only de-identified data and 02_linkefi.R
  efixwalk=paste0(shared_filepath,"01 LDS Derived Data 220624\\DEID_Xwalk_PatDateEFI.tsv"),

  # This is a de-identified table of all HbA1c values uniquely indexed by
  # patient_num and start_date. It is all patients, not just the 40% sample, so
  # in principle we might never need to rebuild it-- just keep re-linking it to
  # the latest version of `samplecsv`.
  hba1c=paste0(shared_filepath,"01 LDS Derived Data 220624\\DEID_HBA1c.tsv"),

  # This is a de-identified table of drug information uniquely indexed by
  # patient_num start_date. It is all patients, not just the 40% sample, so in
  # principle we might never need to rebuild it-- just keep re-linking it to the
  # latest version of `samplecsv`.
  gludrugs=paste0(shared_filepath,"01 LDS Derived Data 220624\\DEID_GLUDRUGS.tsv"),

  # ANALYSIS READY

  # The below are the files to analyze directly, the others are earlier steps
  # in the process of creating them
  analyzeme=paste0(shared_filepath,"01 LDS Derived Data 220624\\DEID_EFI_NOJSON_HSC20210681E_20220204_9aaf19f0.tsv.zip"),
  metadata=paste0(shared_filepath,"00 LDS DataFinisher Data\\DF_sample_HSC20210681E_20220204_9aaf19f0_dict.csv"),

  # The below is a full version of `analyzeme`. Keep it commented out unless
  # you have a computer that can accommodate in-memory objects of at least 3Gb
  # of data. The extra space is due to preserving all the non-tabular data from
  # i2b2 as JSON strings (i.e. not directly analyzable anyway).
  # analyzeme=paste0(shared_filepath,"01 LDS Derived Data 220624\\DEID_EFI_HSC20210681E_20220204_9aaf19f0.tsv.zip"),



  # files for future use
  consort=paste0(shared_filepath,"01 LDS Derived Data 220624\\consort_counts.rdata")
);

# A stable location for temporary files that persists between sessions.
# Feel free to hard-code whatever you want to use on your computer as the actual
# temp directory. Not used currently except by 01_makemappings.R
tempdir <- dirname(tempdir());


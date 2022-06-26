# How Raw Data Was Processed

Please note: the analysis scripts get distributed completely separate from the
data on which they are to be used. You can get these scripts from GitHub, but
the data will be provided privately to you within the University firewall. You
will probably receive it as a CSV file, but these instructions are here so I
don't forget, or if somebody else replicate this process for some reason.

YOU PROBABLY CAN JUST SKIP STRAIGHT DOWN TO STEP 10: ANALYSIS.

## 1. Extraction from i2b2

This is a one-time step. It only needs to be replicated for future projects that
follow a similar i2b2 data strategy.

Briefly, sftp of the db SQLite file created by KUMC's databuilder (todo: cite
build hash of databuilder, OS version, versions of python and all dependencies
used)

Download as a table the identified extract of study patients from
PATIENT_DIMENSION

Download as a table the EFI scores for patients

(todo: include exact SQL script used to create EFI scores)

## 2. Obtain DataFinisher WebApp and DataFinisher

```{bash}
git clone git@github.com:bokov/datafinisher_webapp;
cd datafinisher_webapp;
git checkout integration;
git submodule update --init --recursive;
cd dfshiny/datafinisher;
git checkout refactor_00_args_dtcp_tf;

```

If you received the data for this project in the form of a CSV file, skip the
next two steps and go to step 5, 9, or even 10.

## 3. Create a smaller sample of the data

The data is huge -- it includes almost every lab and diagnosis over a 5 year
period for almost 9000 patients. For development purposes we will need to work
with a sample of the data. Let's assume the i2b2 databuilder raw dump is named
YOURDATA.db and is copied or linked to the
`datafinisher_webapp/dfshiny/datafinisher` folder. In that folder, run the
following command:

```{bash}
python dfsamp.py -l -s " SUBSTR(patient_num,-1)+0 > 6 " YOURDATA.db
```

What this does is create a random but reproducible 30% sample of data only from
patients whose study id ends with 7, 8, or 9. Here is what normal output from
this command looks like. There shouldn't be any stack traces, at least not with
the default options.

    First run since cleanup, apparently
    modifier_dimension is empty, let's fill it
    initialized variables:                                          0.0283
    created df_joinme table and index:                             10.6304
    created df_codeid_tmp table:                                   10.4197
    mapped concept codes in df_codeid:                             10.9674
    created df_obsfact table and index:                            71.4887
    created rule definitions:                                       0.0077
    created df_dtdict:                                            275.6365
    added rules to df_dtdict:                                       0.0050
    created df_dynsql table:                                        0.0093
    assigned chunks to df_dynsql:                                   0.0050
    created all tables described by df_dynsql:                    227.5773
    created fulloutput2 table:                                     16.8610
    created fulloutput table:                                      17.3722
    created df_binoutput view:                                      0.0074
    wrote output table to file:                                    36.2948
    wrote metadata to file:                                         0.6796
    TOTAL RUNTIME:                                                677.9906
    processRows() is writing headers
    processRows() is writing data
    processRows() is cleaning up and returning results

After a maybe 30 minutes you will end up with `sample_YOURDATA.csv`.

Please make sure you have plenty of disk space to spare because for a while you
will be using more disk space than the final sizes of the original and output
files. Also, in subsequent steps you will need even more to create the csv file.
At least 3x the size of YOURDATA.db.

## 4. Turn your data into a spreadsheet with one row per patient-date

Now we get to the entire reason I wasted years of my life writing datafinisher:
converting relational database tables to a single, analysis-friendly
spreadsheet. Skipping over half a professional lifetime's worth of detail and
background, all you need to do is this (using `sample_YOURDATA.db` file from the
previous step):

`python2.7 df.py sample_YOURDATA.db`

After a few minutes, the following files will be created in the same folder:

-   [sample_YOURDATA.csv]{.underline}: a spreadsheet containing one column per
data-element as defined by the original i2b2 query and one row per unique
visit-date for each patient. The problem is that multiple completely different
variables can be in the same column--- for example, all the diagnoses are one
column, all the labs are another column, and so on. Furthermore, multiple
diagnoses and labs are usually associated with the same visit. For these
reasons, most cells in this spreadsheet don't contain normal numeric values.
They contain structured data in a format called
[JSON](https://en.wikipedia.org/wiki/JSON). But hey, at least we have them
sorted out into a unified rows and columns schema in a text format that can be
read with many different tools. Anyway, this isn't the yet file you will likely
be using-- the next one is.

-   [df_sample_YOURDATA.csv]{.underline}: After creating the above file,
datafinisher also does an automated post-processing step for you where it makes
its best guess on your behalf on how you want to aggregate each cell into a
single value. This is the result. Datafinisher probably didn't correctly
anticipate what you want to do with the data, but now this file can be fed into
the Datafinisher WebApp so you can interactively adjust what columns should be
created from the blobs of JSON.

-   [meta_sample_YOURDATA.csv]{.underline}: An automatically generated data
dictionary of your data.

If all goes well, you will receive this data already in CSV format and can jump
straight to step 5.

## 5. Install the R Dependencies

```{r}
install.packages(c('reticulate','readr','shiny','dplyr','devtools','shinyjs','shinyalert'));
devtools::install_github("harveyl888/queryBuilder");
```

For more info, see <https://github.com/bokov/datafinisher_webapp/tree/integration>

## 6. Make sure you have a working Python 2.7 environment

I use Python 2.7.18 (default, Mar 8 2021, 13:02:45) [GCC 9.3.0] on Ubuntu/PopOS
20.04 (Focal) but these scripts aren't terribly sensitive to exact versions.
They *do* however requiredPython 2.7-- I never succeeded in getting dedicated
funding for this project and as a result have not had the protected time to port
it to Python 3.X. Maybe someday.

Let's assume you already have the Reticulate package installed and you also got
Python 2.7 installed as `/usr/bin/python2.7`. If you do not have a compatible
PIP installed, here is how you fix that:

```{bash}
curl https://bootstrap.pypa.io/pip/2.7/get-pip.py -o get-pip.py
/usr/bin/python2.7 get-pip.py 
/usr/bin/python2.7 -m pip install --upgrade --user virtualenv
```

I was still having trouble getting Reticulate to work with Python 2.7, so I
downgraded Reticulate to 1.18.

In R, I used the following command to force the use of system default Python
2.7. This bypasses virtualenv and conda and all that junk that (for me at least)
creates more deployment problems than it solves.

```{r}
Sys.setenv(RETICULATE_PYTHON='/usr/bin/python2.7');
```

When invoking Python from Reticulate (but not when invoking it directly)
something about the default library paths was causing it to error trying to load
the sqlite3 module with `ImportError: No module named dbapi2`. The code below
executed (e.g. from `repl_python()`) will fix it for the duration of the
session.

```{python}
import sys,os
MyPriorityPaths = ['/usr/lib/python2.7/sqlite3']

sys.path = MyPriorityPaths + sys.path 
```

This was the last thing I tried before it started working, so maybe downgrading
Reticulate was not necessary. Please let me know if you are able to avoid
downgrading, or if you find other ways to get Python 2.7 to work with Reticulate
on your system.

## 7. Run Datafinisher WebApp

Now you can change the working directory of your R session to the root level of
the datafinisher_webapp repository you cloned and run
`shiny::runApp('dfshiny')`. The file (in the example it's `sample_YOURDATA.csv`,
the actual one will be whatever you name or rename it) will likely be too large
to upload via the browser. Instead, you should move it to
`datafinisher_webapp/dfshiny/trusted_files` . Now, in the local browser window
you can go to [http://127.0.0.1:3594/?dfile=sample_YOURDATA.csv]{.underline}
(change the URL to the actual port that got assigned to your Shiny instance and
the actual name of the file you copied to `trusted_files`. Now you can
interactively select what to extract into which analytic columns from the
"kitchen sink" version of the data. You will see more explanation and hints on
the splash page of the Datafinisher WebApp.

Briefly, DataFinisher allows you to interactively specify what column/s should
be created from each element in the i2b2 dataset and export that as a new .csv
file.

## 8. Collecting the Updated Results from DataFinisher WebApp

(TBD)
Briefly, you find the .csv file in a temp directory that DataFinisher made and
copy it somewhere safe. You could try downloading it via the web browser by
clicking the appropriate button on the dashboard, but I'm starting to realize
it's like trying to drink ice cream through a straw.

## 9. Post-Processing

The .csv file created by DataFinisher is a drop-in replacement for the 
`samplecsvfile` specified in `local_config.R` (see `default_config.R` for 
documentation). Make sure it has a name that's different from the current 
`samplecsvfile`, copy it to the same folder as that file, comment out the 
old path and add the new path in its place. Now run the script named 
`02_linkefi.R`. It will create two new .tsv files in the current folder. The 
smaller one is a drop-in replacement for `analyzeme`. Again, rename it to 
something different than the current file's name, optionally zip it, copy it
to the same folder where the current `analyzeme` lives, comment out the old 
path and add the new path in its place.

Note that `02_linkefi.R` _by design_ does not automatically replace the old
versions of your source data files. The manual steps of renaming, copying, and
updating `local_config.R` are intended to make sure you don't accidentally
overwrite needed data!

On that note-- **never modify the mappings for `fullsqlfile`, `patmap` or `efi`
nor the files to which those mappings refer!!!!**. The only exception is if you 
need to copy those three files **verbatim** from one location to another and
then change your mappings to point at those new locations.

## 10. Analysis

If all goes well, you won't need to run your data through DataFinisher and 
rebuild the analysis file. You can just start with the analysis file. In that 
case, the steps simplify to:

1. `git clone git@github.com:bokov/efi_pepper.git` (recommended you first make
   your own fork of this repository and clone that)
2. Open the resulting folder as a project in RStudio
3. Open `default_config.R` and save it under the name `local_config.R`
4. Follow the instructions in that file to edit it as necessary according to 
   where your copies of the data are located.
5. Open `03_explore_data.R`, run it as a script, and then build it as a report
   to make sure everything is working correctly.
6. Save `03_explore_data.R` under a new name, and start making changes as you
   see fit!

The 
script `03_explore_data.R` gives an example from which to begin. Please read 
the comments in that script for more information.

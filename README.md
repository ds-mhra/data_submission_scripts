# data_submission_scripts
Scripts to aid with completing metadata forms and uploading data to online repositories, namely NCBI's SRA.

Please see confluence page associated with the scripts for further detail: [Confluence page](https://mdop.atlassian.net/wiki/pages/resumedraft.action?draftId=1034649654&draftShareId=67e7285f-4634-4ef3-b660-b9e704580fd0&atlOrigin=eyJpIjoiODY4ZTdjNGExOWRjNDBmYThmMjc5OTBkN2Q2YjM2YjIiLCJwIjoiYyJ9).


### process_filenames.sh
This script:

✔ Identifies paired vs single-end reads

✔ Extracts sample names and creates library IDs from listed filenames and organism

✔ Logs unprocessed files
<br><br>

**Step 1: Process Filenames for the Metadata File**

The input file is a **completed BioSample packages CSV** file.

```
process_filenames.sh "input.csv" "processed_paired.csv"
```

Outputs include:
- "processed_paired.csv" - contains paired samples
- "unpaired.csv" - contains single or unpaired samples
- "unprocessed.csv" - contains samples that were classified as either, needs to be dealt with manually
- "temp_fastq_files.txt" - intermediate list of FASTQ file

*Note. the libraryID is created by default from organism + sample_name from the packages file.*
<br><br>

### copy_fastq_gcp.sh
This script:

✔ Extracts filenames from the input CSV

✔ Removes any empty lines

✔ Checks which files are already copied

✔ Transfers missing files in Google Storage

✔ Logs failures in uncopied.txt
<br><br>

**Step 1: Review or Prepare Metadata File for Input**

The metadata file must contain at least 1 column for FASTQ files but reads can be single-, paired- or triple-ended etc): filename, filename2, filename3 . The remaining fields must be completed as described.
<br><br>

**Step 2: Copy Only Required FASTQ Files**

Run the script `copy_fastq_gcp.sh` to copy only the files in the metadata to the destination bucket.

```
copy_fastq_gcp.sh \
  projectID/SRA_metadata.csv \
  "gs://source-bucket" "gs://destination-bucket/"
```
Ensure `source_bucket` does not end in `/` as this will mess with the reiterative search of FASTQ files

Outputs include:
- "uncopied.txt" - contains a list of files that were unsuccessfully not copied to the destination bucket and need to be reviewed
- "to_copy.txt" - intermediate file listing files that are not currently present in the destination bucket
- "file_list.txt" - intermediate file that contains the list of FASTQ files to be transferred
<br><br>

**Step 3: Upload data from the destination bucket to online repository.**


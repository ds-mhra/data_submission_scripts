#!/bin/bash
# Define source and destination buckets
# Ensure correct usage
if [[ $# -ne 3 ]]; then
    echo "Usage: $0 <FASTQ_LIST_CSV> <SOURCE_BUCKET> <DEST_BUCKET>"
    echo "input.csv should be a 3-column list of FASTQ filenames, paired or single-reads."
    exit 1
fi

FASTQ_LIST_CSV="$1"
SOURCE_BUCKET="$2"
DEST_BUCKET="$3"


# Get header line and determine column positions
HEADER_LINE=$(head -1 "$FASTQ_LIST_CSV")

COL_FILENAME=$(echo "$HEADER_LINE" | awk -F',' '{for(i=1;i<=NF;i++) if($i=="filename") print i}')
COL_FILENAME2=$(echo "$HEADER_LINE" | awk -F',' '{for(i=1;i<=NF;i++) if($i=="filename2") print i}')
COL_FILENAME3=$(echo "$HEADER_LINE" | awk -F',' '{for(i=1;i<=NF;i++) if($i=="filename3") print i}')

if [[ -z "$COL_FILENAME" ]]; then
    echo "Error: 'filename' column not found!"
    exit 1
fi

# Extract filenames from metadata and remove empty new lines
# cut -d ',' -f1-3 "$FASTQ_LIST_CSV" | tail -n +2 | tr ',' '\n' | grep -v '^$' > tmp_file_list.txt
awk -F',' -v f1="$COL_FILENAME" -v f2="$COL_FILENAME2" -v f3="$COL_FILENAME3" 'NR > 1 {
    if (f1) print $f1;
    if (f2 && $f2 != "") print $f2;
    if (f3 && $f3 != "") print $f3;
}' "$FASTQ_LIST_CSV" | grep -v '^$' > tmp_file_list.txt

sed '/^[[:space:]]*$/d' tmp_file_list.txt > file_list.txt
echo "File list extracted successfully."        

# List files in destination bucket to identify files that are still needed to be copied
gsutil ls "$DEST_BUCKET/**/*fastq*" | awk -F'/' '{print $NF}' | sort -u > copied_files.txt
comm -23 <(sort file_list.txt) <(sort copied_files.txt) > to_copy.txt
rm copied_files.txt tmp_file_list.txt

# Copy only the missing files
while read -r file; do
    if gsutil -q stat "$DEST_BUCKET/$file"; then
        echo "Skipping $file (already copied)"
    else
        if gsutil -m cp "$SOURCE_BUCKET/**/$file" "$DEST_BUCKET/"; then
            echo "$file copied successfully."
        else
            echo "$file" >> uncopied.txt
            echo "Failed to copy $file. Added to uncopied.txt."
        fi
    fi
done < to_copy.txt



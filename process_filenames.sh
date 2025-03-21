#!/bin/bash

# Ensure correct usage
if [[ $# -ne 2 ]]; then
    echo "Usage: $0 <input_file> <output_paired>"
    exit 1
fi

input_file="$1"
output_paired="$2"
touch "unpaired.csv"
touch "unprocessed.csv"

# Start fresh
rm -f "$output_paired" "unpaired.csv" "unprocessed.csv"
echo "sample_name,library_ID,filename,filename2" > "$output_paired"
echo "sample_name,library_ID,filename,filename2" > "unpaired.csv"
echo "filename" > "unprocessed.csv"

# Extract and process fastq filenames
awk -F',' '{print $1}' "$input_file" | grep -o '[^ ]*\.fastq[^,]*' | sort | uniq > temp_fastq_files.txt
# Remove trailing whitespaces
awk '{gsub(/^[ \t]+|[ \t]+$/, ""); print}' temp_fastq_files.txt > temp_fastq_files_trimmed.txt
mv temp_fastq_files_trimmed.txt temp_fastq_files.txt

# Function to extract lab number from filename
extract_lab_number() {
    local filename="$1"
    if [[ "$filename" =~ ^(Lab|LAB|lab)[0-9]+ ]]; then
        echo "$filename" | grep -oE '^(Lab|LAB|lab)[0-9]+' | tr '[:upper:]' '[:lower:]'
    # elif [[ "$filename" =~ ^(Lab|LAB|lab)0[0-9]+ ]]; then
    #     echo "$filename" | grep -oE '^(Lab|LAB|lab)0[0-9]+' | tr '[:upper:]' '[:lower:]'
    else
        echo "unknown"
    fi
}

while read -r file; do
    
    # Extract organism from input file
    organism=$(grep "$file" "$input_file" | awk -F',' '{print $4}')
    if [[ -z "$organism" ]]; then
        organism="unknown"
    fi

    # Extract sample name and library ID fro filenames
    if [[ "$file" =~ _L[0-9]+_R[12]_[0-9]+ ]]; then
        #  Handle files like: LAB3_M2H_B_9_S1_L001_R1_001.fastq.gz
        sample=$(echo "$file" | sed -E 's/(_L[0-9]+_R[12]_.*)//')
        lab_num=$(extract_lab_number "$file")
        sample_name="${organism}_${lab_num}"
        lib_id="${organism}_${sample}"  # _$(echo "$file" | grep -o '_S[0-9]*' | tr -d '_S')

    elif [[ "$file" =~ _L[0-9]+_R[12]\.fastq ]]; then
        #  Handle files like: Lab4_M2R_A1-001_CAAGCTCC-GGGGGGGG_L001_R1.fastq.gz
        sample=$(echo "$file" | sed -E 's/_L[0-9]+_R[12]\.fastq.gz//')    # (_L[0-9]+_R[12].*)
        lab_num=$(extract_lab_number "$file")
        sample_name="${organism}_${lab_num}"
        lib_id="${organism}_${sample}"

    elif [[ "$file" =~ _S[0-9]+_R[12] ]]; then
        #  Handle: LAB2_FFR_A2H_NegControl-1_S15_R1_001.fastq.gz 
        sample=$(echo "$file" | sed -E 's/_R[12]_.*//')
        lab_num=$(extract_lab_number "$file")
        sample_name="${organism}_${lab_num}"
        lib_id="${organism}_${sample}"  #_$(echo "$file" | grep -o 'S[0-9]*') | tr -d '_S'
        
    elif [[ "$file" =~ _R[12] ]]; then
        #  Handle: Lab11_M2H_B5_R1.fastq.gz
        sample=$(echo "$file" | sed -E 's/_R[12].*//')
        lab_num=$(extract_lab_number "$file")
        sample_name="${organism}_${lab_num}"
        lib_id="${organism}_${sample}"

    elif [[ "$file" =~ \.[RF]\.[12]\.fastq ]]; then
        #  Handle: Lab23_M2H_B4-0010A.R.1.fastq.gz + Lab23_M2H_B4-0010A.F.1.fastq.gz
        sample=$(echo "$file" | sed -E 's/.[RF].[12].*//')
        lab_num=$(extract_lab_number "$file")
        sample_name="${organism}_${lab_num}"
        lib_id="${organism}_${sample}"

    elif [[ "$file" =~ _runid_[^_]+_([0-9]+)\.fastq\.gz ]]; then       # _runid_[^_]+_([0-9]+)\.fastq\.gz OR     elif [[ "$file" =~ _runid_.*_[0-9]+\.fastq.gz ]]; then
        # Handle files like: _bcboth_fastq_runid_11a037f1cc9b9e98699bff7087e377a0af85c982_38.fastq.gz
        repeat_num="${BASH_REMATCH[1]}"
        # repeat_num=$(echo "$repeat_num" | sed -E 's/.*_runid_[^_]+_([0-9]+)\.fastq\.gz/\1/') 
        # echo "repeat.num0 ${repeat_num}"
        sub_sample=$(echo "$file" | sed -E 's/_fastq_runid_.*_[0-9]+\.fastq.gz//') 
        sample="${sub_sample}_${repeat_num}"
        # echo $file
        lab_num=$(extract_lab_number "$file")
        sample_name="${organism}_${lab_num}"
        lib_id="${organism}_${sample}"
        
    elif [[ "$file" =~ \(([0-9]+)\)\.gz$ ]]; then
        # Handle files like: _bcsingle_fastq_runid_9eec72fe_0.fastq (83).gz
        repeat_num="${BASH_REMATCH[0]}"
        repeat_num=$(echo "$repeat_num" | sed -E 's/.gz$//') 
        # echo "num2 ${repeat_num}"
        sub_sample=$(echo "$file" | sed -E 's/_fastq_runid_.*_[0-9]+.fastq \(([0-9]+)\)\.gz$//') 
        sample="${sub_sample}_${repeat_num}"
        lab_num=$(extract_lab_number "$file")
        sample_name="${organism}_${lab_num}"
        lib_id="${organism}_${sample}"
    else
        # Default case for any other pattern
        sample=$(echo "$file" | sed -E 's/\.fastq.*//')
        lab_num=$(extract_lab_number "$file")
        sample_name="${organism}_${lab_num}"
        lib_id="${organism}_${sample}"
    fi

    # Initialise as unpaired by default
    is_paired=false
    paired_file=""

    # Check for different paired patterns
    # paired reads w lane info                              # LAB3_M2H_B_9_S1_L001_R1_001.fastq.gz
    if [[ "$file" =~ _L[0-9]+_R1_ ]] && grep -q "${file/_R1_/_R2_}" temp_fastq_files.txt; then
        is_paired=true
        paired_file="${file/_R1_/_R2_}"
    
    # paired reads w lane info but different suffix        # Lab4_M2R_B5-010_TTCTTAGC-GGGGGGGG_L001_R2.fastq.gz
    elif [[ "$file" =~ _L[0-9]+_R1\.fastq ]] && grep -q "${file/_R1./_R2.}" temp_fastq_files.txt; then
        is_paired=true
        paired_file="${file/_R1./_R2.}"        
    
    # paired reads wout lane info
    elif [[ "$file" =~ _R1_ ]] && grep -q "${file/_R1_/_R2_}" temp_fastq_files.txt; then
        is_paired=true
        paired_file="${file/_R1_/_R2_}"
    
    # other R1/R2 pairs  
    elif [[ "$file" =~ _R1\.fastq ]] && grep -q "${file/_R1./_R2.}" temp_fastq_files.txt; then
        is_paired=true
        paired_file="${file/_R1./_R2.}"
    
    # R.1/F.1 paired reads
    elif [[ "$file" =~ \.R\.1\.fastq ]] && grep -q "${file/.R.1./.F.1.}" temp_fastq_files.txt; then
        is_paired=true
        paired_file="${file/.R.1./.F.1.}"
    # R.2/F.2 paired reads
    elif [[ "$file" =~ \.R\.2\.fastq ]] && grep -q "${file/.R.2./.F.2.}" temp_fastq_files.txt; then
        is_paired=true
        paired_file="${file/.R.2./.F.2.}"
    fi


    # Output based on paired status
    if [[ "$is_paired" = true ]]; then
        echo "$sample_name,$lib_id,$file,$paired_file" >> "$output_paired"
    else
        # For unpaired reads, only output if this is the first read (to avoid duplicates)
        if ! [[ "$file" =~ _R2_ || "$file" =~ _R2\. || "$file" =~ \.F\.1\. || "$file" =~ \.F\.2\. ]]; then
            echo "$sample_name,$lib_id,$file," >> "unpaired.csv"
        fi
    fi
done < temp_fastq_files.txt

# Track processed and unprocessed files
processed_files=$(awk -F',' 'NR>1 {print $3; if ($4 != "") print $4}' "$output_paired" "unpaired.csv" | sort | uniq)
comm -23 <(sort temp_fastq_files.txt) <(echo "$processed_files" | sort) >> "unprocessed.csv"

total_files=$(wc -l < temp_fastq_files.txt)
processed_files_count=$(( $(wc -l < "$output_paired")*2 + $(wc -l < "unpaired.csv") + $(wc -l < "unprocessed.csv") - 4 ))

if [[ "$total_files" -ne "$processed_files_count" ]]; then
    echo "Warning: Mismatch in file counts! Expected: $total_files fastq files, Processed: $processed_files_count"
fi

echo "Generated entries:    Paired: $(($(wc -l < "$output_paired") - 1)), Unpaired: $(($(wc -l < "unpaired.csv") - 1)), Unprocessed: $(($(wc -l < "unprocessed.csv") - 1))."
# echo "Generated $(grep -c "," "$output_paired" | awk '{print $1-1}') AND $(grep -c "," "unpaired.csv" | awk '{print $1-1}') entries."

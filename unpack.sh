#!/bin/bash

: << 'COMMENT'

SAMUEL ALBERSHTEIN - unpack [-r] [-v] file [file...]

This script mimics the unpack [-r] [-v] file [file...] command with 4 unpacking options - gunzip, bunzip2, unzip, uncompress.
With an automatic recursion and verbose output, utilizing unpacking for each file recursively.

When unpacking, I implemented a special name (PID) for each directory containing the unpacked file to prevent 
an error of 'File exists.' - generate_unique_dir_name().

I used a special file --mime-type option to identify the file format and decompress it with the right tool.

decompressed_count is used to count the total of the uncompressed files

A Very Important Note: 

During process_target() it is not allowed to run the while loop in a subshell when using the find command. 
In a subshell, any changes to variables (like decompressed_count) do not affect the parent shell’s variables. This is why the count wasn’t updating correctly.

To fix this, i stored the output of the find command in a variable and then processed it in a while loop using a here-string (<<<). 
This ensures that the loop runs in the parent shell, allowing the decompressed_count to be updated correctly.

Example of the previous wrong interpretation i used: 

process_target() {
    local target="$1"
    find "$target" -type f | while read -r file; do
        echo "Decompressing $file"  # Verbose output for each file
        decompress_file "$file"
    done
}

COMMENT

# Initialize counter for decompressed files
decompressed_count=0

# Function to generate a unique directory name
generate_unique_dir_name() {
    local base_name="$1"
    local unique_suffix
    unique_suffix=$(openssl rand -hex 6)_$$ # $$ Defines the process id and generates a 6 byte (48 bits) value = 12 numerical value  
    echo "${base_name}_$unique_suffix"
}

# Function to decompress a file using the appropriate method
decompress_file() {
    local file="$1"
    local output_dir

    case "$(file --mime-type -b "$file")" in
        "application/gzip")
            output_dir=$(generate_unique_dir_name "$file")
            mkdir -p "$output_dir"
            if gunzip -c "$file" > "$output_dir/$(basename "${file%.*}")"; then
                ((decompressed_count++))
                echo "Unpacking $file..."
                process_target "$output_dir"  # Recursively process extracted files
            fi
            ;;
        "application/x-bzip2")
            output_dir=$(generate_unique_dir_name "$file")
            mkdir -p "$output_dir"
            if bunzip2 -c "$file" > "$output_dir/$(basename "${file%.*}")"; then
                ((decompressed_count++))
                echo "Unpacking $file..."
                process_target "$output_dir"  # Recursively process extracted files
            fi
            ;;
        "application/zip")
            output_dir=$(generate_unique_dir_name "$file")
            if unzip -o "$file" -d "$output_dir"; then
                ((decompressed_count++))
                echo "Unpacking $file..."
                process_target "$output_dir"  # Recursively process extracted files
            fi
            ;;
        "application/x-compress")
            output_dir=$(generate_unique_dir_name "$file")
            mkdir -p "$output_dir"
            if uncompress -c "$file" > "$output_dir/$(basename "${file%.*}")"; then
                ((decompressed_count++))
                echo "Unpacking $file..."
                process_target "$output_dir"  # Recursively process extracted files
            fi
            ;;
        *)
            echo "Ignoring $file"
            ;;
    esac
}

# Function to process files and directories recursively
# Pushing the files varible with the file names to the while for decompressing so the decompressed_count++ will work in the main shell (and not subshell)
process_target() {
    local target="$1"
    local files
    files=$(find "$target" -type f)
    while IFS= read -r file; do
        decompress_file "$file"
    done <<< "$files"
}

# Main loop to process all arguments passed to the script (as a list stored in $@)
for target in "$@"; do 
    if [ -d "$target" ]; then
        echo "Processing directory $target"
        process_target "$target"
    elif [ -f "$target" ]; then
        decompress_file "$target"
    else
        echo "Skipping $target (not a valid file or directory)"
    fi
done

# Output the number of successfully decompressed archives
echo "Decompressed $decompressed_count archive(s)"

# Return success status
exit 0

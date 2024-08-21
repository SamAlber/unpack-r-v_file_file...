#!/bin/bash

: << 'COMMENT'

SAMUEL ALBERSHTEIN - unpack [-r] [-v] file [file...]

This script mimics the unpack [-r] [-v] file [file...] command with 4 unpacking options - gunzip, bunzip2, unzip, uncompress.
With an automatic recursion and verbose output, utilizing unpacking for each file recursively.

I implemented a special name for each unpacked file to prevent 
an error of 'File exists.' - generate_unique_file_name().

I used a special file --mime-type option to identify the file format and decompress it with the right tool.

decompressed_count is used to count the total of the uncompressed files

Very Important Notes: 

NOTE1:

I implemeted an exit value based on the success of files decompression passed
to the script as arguments ONLY! (Not recursive)

2 Flags are used: 

The first one is is_initial which is passed as true with the first iteration of the file argument.
The second one is decompress_success which starts as a local false to the decompress_file() function. 

If none of the tools were able to decompress the file, the flag will stay as False and the if statement at the end will return 
initial_failed=true. 

The initial_failed will stay in this mode for the whole time the script is running and decompressing the other 
files passed as arguments.

When the script is finished it wil return exit 1 based on the initial_failed=true flag. 

NOTE2: 

During process_target() it is not allowed to run the while loop in a subshell when using the find command. 
In a subshell, any changes to variables (like decompressed_count) do not affect the parent shell’s variables. This is why the count wasn’t updating correctly.

To fix this, I stored the output of the find command in a variable and then processed it in a while loop using a here-string (<<<). 
This ensures that the loop runs in the parent shell, allowing the decompressed_count to be updated correctly.

Example of the previous wrong interpretation I used: 

process_target() {
    local target="$1"
    find "$target" -type f | while read -r file; do
        echo "Decompressing $file"  # Verbose output for each file
        decompress_file "$file"
    done
}

COMMENT

# Initialize counters for decompressed files and a failure flag
decompressed_count=0
initial_failed=false

# Function to generate a unique file name to avoid "File exists." error
generate_unique_file_name() {
    local base_name="$1"
    local unique_suffix
    unique_suffix=$(openssl rand -hex 4)  # Generates a unique random suffix 
    echo "${base_name}_unpack_$unique_suffix"
}

# Function to decompress a file using the appropriate method
decompress_file() {
    local file="$1"
    local file_name
    local is_initial="$2"
    local decompress_success=false

    # Determine the MIME type of the file and select the appropriate decompression tool
    case "$(file --mime-type -b "$file")" in
        "application/gzip")
            # Generate a unique file name for the decompressed file
            file_name=$(generate_unique_file_name "${file}")
            # Decompress the file using gunzip and save to the generated file name
            if gunzip -c "$file" > "$file_name"; then
                decompress_success=true
                ((decompressed_count++))  # Increment the decompressed file count
                echo "Unpacking $file..."
                process_target "$file_name"  # Recursively process extracted files
            fi
            ;;
        "application/x-bzip2")
            file_name=$(generate_unique_file_name "${file}")
            if bunzip2 -c "$file" > "$file_name"; then
                decompress_success=true
                ((decompressed_count++))
                echo "Unpacking $file..."
                process_target "$file_name"  # Recursively process extracted files
            fi
            ;;
        "application/zip")
            # For ZIP files, unzip to a unique directory
            file_name=$(generate_unique_file_name "${file}")
            if unzip -o "$file" -d "$file_name"; then
                decompress_success=true
                ((decompressed_count++))
                echo "Unpacking $file..."
                process_target "$file_name"  # Recursively process extracted files
            fi
            ;;
        "application/x-compress")
            file_name=$(generate_unique_file_name "${file}")
            if uncompress -c "$file" > "$file_name"; then
                decompress_success=true
                ((decompressed_count++))
                echo "Unpacking $file..."
                process_target "$file_name"  # Recursively process extracted files
            fi
            ;;
        *)
            echo "Ignoring $file (unsupported format)"
            ;;
    esac

    # If decompression failed and it's an initial file, set the failure flag
    if [ "$decompress_success" = false ] && [ "$is_initial" = true ]; then
        initial_failed=true
    fi
}

# Function to process files and directories recursively
# Pushing the files variable with the file names to the while loop for decompressing so the decompressed_count++ will work in the main shell (and not subshell)
process_target() {
    local target="$1"
    local files
    files=$(find "$target" -type f)
    
    while IFS= read -r file; do
        decompress_file "$file" false
    done <<< "$files"
}

# Main loop to process all arguments passed to the script (as a list stored in $@)
for target in "$@"; do 

    if [ -d "$target" ]; then
        echo "Processing directory $target"
        process_target "$target"

    elif [ -f "$target" ]; then

        decompress_file "$target" true # Passing the file argument together with the initial flag! 

    else
        echo "Skipping $target (not a valid file or directory)"
        initial_failed=true
    fi
done

# Output the number of successfully decompressed archives
echo "Decompressed $decompressed_count archive(s)"

# Return 1 if any of the files passed as arguments failed to decompress, otherwise return 0
if [ "$initial_failed" = true ]; then
    exit 1
else
    exit 0
fi

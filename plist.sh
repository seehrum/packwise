#!/bin/bash

# Usage message
usage() {
    echo "Usage: $0 [OPTIONS] file1 [file2]"
    echo "  -a            Add '[ADD]' at the beginning of all lines"
    echo "  -r            Add '[REMOVE]' at the beginning of all lines"
    echo "  -j            Join two lists into one, removing duplicates"
    echo "  -c            Check for duplicates in a file"
    echo "  -u [add|remove]  Remove specified prefix from all lines"
    echo "  -h            Display this help and exit"
}

# Check for at least one parameter
if [ $# -eq 0 ]; then
    usage
    exit 1
fi

# Function to prepend text to lines
prepend_text() {
    local file=$1
    local text=$2
    sed -i "s/^/$text /" "$file"
}

# Function to join two files and remove duplicates
join_files() {
    local list_a="$1"
    local list_b="$2"
    local output_list="new-list.txt"

    # Check if both files exist
    if [[ ! -f "$list_a" || ! -f "$list_b" ]]; then
        echo "Error: One or both files do not exist."
        return 1
    fi

    # Create associative arrays to store package statuses
    declare -A packages

    # Process list A
    while read -r line; do
        local package=${line#*[ ]}
        local status=${line% $package}
        packages["$package"]="$status"
    done < "$list_a"

    # Process list B
    while read -r line; do
        local package=${line#*[ ]}
        local status=${line% $package}
        # If package is already in the array from list A, and status is ADD, overwrite the status
        packages["$package"]="$status"
    done < "$list_b"

    # Output the result into a new list
    > "$output_list" # Clear or create the output file
    for package in "${!packages[@]}"; do
        echo "${packages[$package]} $package" >> "$output_list"
    done

    # Sort the output file for neatness
    sort "$output_list" -o "$output_list"
    echo "Merged list created as $output_list"
}


# Function to check for duplicates
#check_duplicates() {
#    local file=$1
#    sort "$file" | uniq -d
#}

# Function to check for duplicates, case-insensitively
check_duplicates() {
    local file=$1
    awk '{
        # Convert the line to lowercase for comparison
        line = tolower($0)
        count[line]++
        # Save the first occurrence of this line in its original form
        if (count[line] == 1) original[line] = $0
    }
    END {
        # Output original lines that have more than one occurrence
        for (line in count)
            if (count[line] > 1)
                print original[line]
    }' "$file"
}


# Function to handle -u option
remove_prefix_ADD() {
    local file=$1
    sed -i '/^\(\[ADD\]\|\[\*\]\)/d' "$file"
}

# Function to handle -u option
remove_prefix_REMOVE() {
    local file=$1
    sed -i '/^\(\[REMOVE\]\|\[\*\]\)/d' "$file"
}



# Parse command-line options
while getopts "arj:cdhuAR:" opt; do
    case $opt in
        a)
            prepend_text "$2" "[ADD]"
            ;;
        r)
            prepend_text "$2" "[REMOVE]"
            ;;
        j) join_files "$2" "$3"
            ;;
        c)
            check_duplicates "$2"
            ;;
        A)
            remove_prefix_ADD "$2"
            ;;
        R)  remove_prefix_REMOVE "$2"
            ;;
        h)
            usage
            exit 0
            ;;
        \?)
            usage
            exit 1
            ;;
    esac
done

shift $((OPTIND -1))

#!/bin/bash
# PackWise v1.0
# GNU bash, versão 5.1.16(1)-release (x86_64-pc-linux-gnu)

# Define the file that contains the package list
PACKAGE_FILE="packages.list"
INSTALL_LOG="addpkg.log"
REMOVE_LOG="removepkg.log"

# Function to show help instructions
show_help() {
    echo "Usage: $0 [option] [argument]"
    echo "Options:"
    echo "  -i                             Install packages listed as [ADD] in $PACKAGE_FILE"
    echo "  -r                             Remove packages listed as [REMOVE] in $PACKAGE_FILE"
    echo "  -A package-name                Add a package to the $PACKAGE_FILE with [ADD] prefix"
    echo "  -R package-name                Replace [ADD] with [REMOVE] in $PACKAGE_FILE for the specified package"
    echo "  -l                             Generate a list of all installed packages with [ADD] prefix"
    echo "  -f filename                    Add or modify packages from a provided list file"
    echo "  -c                             checks for duplicate package names in packages.list"
    echo "  -h                             Display this help"
}

# Function to check if packlist.list exists
check_packlist_exist() {
    local file_path="$PACKAGE_FILE"
    if [ ! -f "$file_path" ]; then
        echo "Error: File '$file_path' does not exist."
        exit 1  # Return a non-zero status to indicate the file does not exist
    else
        echo "File '$file_path' found."
    fi
}

# Function to install packages
install_packages() {
    check_packlist_exist
    grep "\[ADD\]" $PACKAGE_FILE | sed 's/\[ADD\]//' | while read -r package; do
        echo "Installing $package"
        sudo apt-get install -y -V $package &>> $INSTALL_LOG
        if [ $? -eq 0 ]; then
            echo "$package installation successful."
        else
            echo "Error installing $package."
        fi
    done
}

# Function to remove packages
remove_packages() {
    check_packlist_exist
    grep "\[REMOVE\]" $PACKAGE_FILE | sed 's/\[REMOVE\]//' | while read -r package; do
        echo "Removing $package"
        sudo apt-get remove --purge -y -V $package &>> $REMOVE_LOG
        if [ $? -eq 0 ]; then
            echo "$package removal successful."
        else
            echo "Error removing $package."
        fi
    done
}

# Function to add a package to the list
add_package() {
    if grep -qE "\[ADD\]$1|\[REMOVE\]$1" $PACKAGE_FILE; then
        echo "Package $1 is already in the list."
    else
        echo "[ADD]$1" >> $PACKAGE_FILE
	echo "$1 package added to $PACKAGE_FILE for installation."
    fi
}

# Function to replace [ADD] with [REMOVE] in the list
replace_with_remove() {
    if grep -q "\[ADD\]$1" $PACKAGE_FILE; then
        sed -i "s/\[ADD\]$1/\[REMOVE\]$1/" $PACKAGE_FILE
	echo "package added to $PACKAGE_FILE for removal"
    else
        echo "Package $1 not found as [ADD]"
    fi
}

# Function to handle adding from a provided list
#add_from_list() {
#    while read -r line; do
#        if grep -qE "\[ADD\]$line|\[REMOVE\]$line" $PACKAGE_FILE; then
#            sed -i "s/\[REMOVE\]$line/\[ADD\]$line/" $PACKAGE_FILE
#	   echo "Packages added, some packages already exist and have been added to $PACKAGE_FILE for non-removal area"
#        else
#            echo "[ADD]$line" >> $PACKAGE_FILE
#	   echo "packages added to $PACKAGE_FILE for installation"
#        fi
#    done < "$1"
#}

# Function to handle adding from a provided list
add_from_list() {
    while read -r line; do
        # First check if the line is not empty and does not just contain whitespace
        if [[ ! "$line" =~ ^\s*$ ]]; then
            # Check if the package is already in the list with any prefix
            if grep -qE "^\[.*\]$line$" $PACKAGE_FILE; then
                # Normalize all entries for this package to [ADD]
                sed -i -r "s/^\[.*\]$line$/[ADD]$line/" $PACKAGE_FILE
                echo "Normalized $line to [ADD] in $PACKAGE_FILE"
            else
                echo "[ADD]$line" >> $PACKAGE_FILE
                echo "Added $line to $PACKAGE_FILE for installation"
            fi
        fi
    done < "$1"
}

# Function to list all installed packages
create_package_list() {
        dpkg --get-selections | awk '{print "[ADD]" $1}' > "$PACKAGE_FILE"
        echo "Generated package list with installed packages."
}

check_repeated_packages() {
    check_packlist_exist
    local counts=$(cut -d']' -f2 < "$PACKAGE_FILE" | sort | uniq -c | awk '$1 > 1 {print $2}')
    if [ -z "$counts" ]; then
        echo "No repeated packages found."
    else
        echo "Repeated packages detected:"
        echo "$counts"
        return 1 # Return a non-zero status to indicate duplicates were found
    fi
}

OPT_FOUND=0

# Parse command line options
while getopts ":iraA:R:lcf:h" opt; do
    case ${opt} in
        i ) install_packages
            OPT_FOUND=1
            ;;
        r ) remove_packages
            OPT_FOUND=1
            ;;
        A ) add_package "$OPTARG"
            OPT_FOUND=1
            ;;
        R ) replace_with_remove "$OPTARG"
            OPT_FOUND=1
            ;;
        l ) create_package_list
            OPT_FOUND=1
            ;;
        f ) add_from_list "$OPTARG"
            OPT_FOUND=1
            ;;
        c ) check_repeated_packages 
            OPT_FOUND=1
	   ;;
        h ) show_help
            OPT_FOUND=1
            ;;
       \? ) echo "Invalid option: $OPTARG" 1>&2
            show_help
            exit 1
            ;;
        : ) echo "Invalid option: $OPTARG requires an argument" 1>&2
            show_help
            exit 1
            ;;
    esac
done
shift $((OPTIND -1))

if [ $OPT_FOUND -eq 0 ]; then
    show_help
    exit 1
fi

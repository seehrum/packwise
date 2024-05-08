#!/bin/bash
# PackWise v1.0
# GNU bash, versão 5.1.16(1)-release (x86_64-pc-linux-gnu)

# Define the file that contains the package list
PACKAGE_FILE="packages.list"
INSTALL_LOG="addpkg.log"
REMOVE_LOG="removepkg.log"

# Function to show help instructions
show_help() {
    echo "PackWise v1.0 - Advanced Package Management Utility"
    echo "Usage: $0 [option] [argument]"
    echo
    echo "Options:"
    echo "  -i                             Install all packages marked with [ADD] in $PACKAGE_FILE."
    echo "  -r                             Remove all packages marked with [REMOVE] from the system and clean entries from $PACKAGE_FILE."
    echo "  -A package-name                Add a new package entry with [ADD] prefix to $PACKAGE_FILE. Marks package for installation."
    echo "  -R package-name                Completely remove any package entry (regardless of its current state) from $PACKAGE_FILE."
    echo "  -S package-name                Toggle the status of a specific package between [ADD], [REMOVE], and [*]."
    echo "  -l                             Re-generate $PACKAGE_FILE with all currently installed packages, marked with [ADD]."
    echo "  -f filename                    Import package names from a specified file and add them to $PACKAGE_FILE with [ADD] prefix, ready for installation."
    echo "  -c                             Check for and report any duplicate package entries in $PACKAGE_FILE, helping maintain a clean package list."
    echo "  -T                             Toggle all packages in $PACKAGE_FILE between [REMOVE] and [ADD] to [*], facilitating bulk changes to package statuses."
    echo "  -h                             Display this help message and exit."
    echo
    echo "Understanding packages.list:"
    echo "  - [ADD]: Packages marked with [ADD] are scheduled for installation."
    echo "  - [REMOVE]: Packages marked with [REMOVE] are scheduled for uninstallation and will be removed from the system."
    echo "  - [*]: Packages marked with [*] are ignored during installation or removal processes."
    echo
    echo "Logging:"
    echo "  - All installation actions are logged to $INSTALL_LOG for auditing and review."
    echo "  - All removal actions are logged to $REMOVE_LOG for tracking and verification."
    echo
    echo "Note:"
    echo "  - Ensure you have the necessary administrative permissions to perform installation and removal of packages."
    echo "  - Operations such as -i and -r require sudo privileges to modify system packages."
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
add_package_list() {
    if grep -qE "\[\*\]$1|\[ADD\]$1|\[REMOVE\]$1" $PACKAGE_FILE; then
        echo "Package $1 is already in the list."
    else
        echo "[ADD]$1" >> $PACKAGE_FILE
	echo "$1 package added to $PACKAGE_FILE for installation."
    fi
}

# Function to remove a package from the list completely
remove_package_list() {
    # Verificar se o pacote com prefixo existe no arquivo
    if grep -qE "^\[(ADD|REMOVE|\*)\]$1\$" "$PACKAGE_FILE"; then
        # Usar sed para remover a linha seguinte ao pacote com o prefixo
        sed -i -r "/^\[(ADD|REMOVE|\*)\]$1\$/ {N; d;}" "$PACKAGE_FILE"
        echo "Package $1 removed from $PACKAGE_FILE."
    else
        echo "Package $1 not found in the list."
    fi
}

# Function to toggle package status between [ADD], [REMOVE], and [*]
toggle_package_status() {
    if grep -q "\[ADD\]$1" $PACKAGE_FILE; then
        # Change from [ADD] to [REMOVE]
        sed -i "s/\[ADD\]$1/\[REMOVE\]$1/" $PACKAGE_FILE
        echo "Package $1 status changed to [REMOVE] in $PACKAGE_FILE."
    elif grep -q "\[REMOVE\]$1" $PACKAGE_FILE; then
        # Change from [REMOVE] to [ADD]
        sed -i "s/\[REMOVE\]$1/\[ADD\]$1/" $PACKAGE_FILE
        echo "Package $1 status changed to [ADD] in $PACKAGE_FILE."
    elif grep -q "\[\*\]$1" $PACKAGE_FILE; then
        # Change from [*] to [ADD]
        sed -i "s/\[\*\]$1/\[ADD\]$1/" $PACKAGE_FILE
        echo "Package $1 status changed to [ADD] in $PACKAGE_FILE."
    else
        echo "Package $1 not found in any status in $PACKAGE_FILE."
    fi
}

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

# Function to toggle package statuses between [ADD], [REMOVE], and [*]
toggle_packages() {
    # Check if there are any [ADD] or [REMOVE] entries and toggle to [*]
    if grep -qE "\[ADD\]|\[REMOVE\]" $PACKAGE_FILE; then
        echo "Toggling [ADD] and [REMOVE] to [*]"
        sed -i 's/\(\[ADD\]\|\[REMOVE\]\)/[*]/g' $PACKAGE_FILE
    # If no [ADD] or [REMOVE] found, check for [*] and toggle to [ADD]
    elif grep -qE "^\[\*\]" $PACKAGE_FILE; then
        echo "Toggling [*] to [ADD]"
        sed -i 's/^\[\*\]/[ADD]/g' $PACKAGE_FILE
    # Else toggle [ADD] to [REMOVE]
    else
        echo "Toggling [ADD] to [REMOVE]"
        sed -i 's/\[ADD\]/[REMOVE]/g' $PACKAGE_FILE
    fi
}

OPT_FOUND=0

# Parse command line options
while getopts ":iraA:R:lcf:hTS" opt; do
    case ${opt} in
        i ) install_packages
            OPT_FOUND=1
            ;;
        r ) remove_packages
            OPT_FOUND=1
            ;;
        A ) add_package_list "$OPTARG"
            OPT_FOUND=1
            ;;
        R ) remove_package_list "$OPTARG"
            OPT_FOUND=1
            ;;
        S ) toggle_package_status "$OPTARG"
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
        T ) toggle_packages
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

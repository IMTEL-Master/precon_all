#!/bin/bash

# Pre-download/install neuroimaging dependencies
# Supports both Docker container and bare-metal installation

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Required versions
FSL_VERSION="5.0.11"
FREESURFER_VERSION="6.0.0"
ANTS_VERSION="2.3.1"
WORKBENCH_VERSION="1.5.0"

# Installation mode (will be set by user)
INSTALL_MODE=""

print_message() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
        echo "windows"
    else
        echo "unknown"
    fi
}

format_bytes() {
    local bytes=$1
    if [ $bytes -ge 1073741824 ]; then
        echo "$(($bytes / 1073741824))GB"
    elif [ $bytes -ge 1048576 ]; then
        echo "$(($bytes / 1048576))MB"
    elif [ $bytes -ge 1024 ]; then
        echo "$(($bytes / 1024))KB"
    else
        echo "${bytes}B"
    fi
}

check_fsl_version() {
    if [ -n "$FSLDIR" ] && [ -f "$FSLDIR/etc/fslversion" ]; then
        cat "$FSLDIR/etc/fslversion"
        return 0
    fi
    return 1
}

check_freesurfer_version() {
    if [ -n "$FREESURFER_HOME" ] && [ -f "$FREESURFER_HOME/build-stamp.txt" ]; then
        grep -oP "v\K[0-9.]+" "$FREESURFER_HOME/build-stamp.txt" | head -1
        return 0
    fi
    return 1
}

check_ants_version() {
    if command -v antsRegistration &> /dev/null; then
        antsRegistration --version 2>&1 | grep -oP "Version: \K[0-9.]+" || echo "unknown"
        return 0
    fi
    return 1
}

check_workbench_version() {
    if command -v wb_command &> /dev/null; then
        wb_command -version 2>&1 | grep -oP "Version: \K[0-9.]+" || echo "unknown"
        return 0
    fi
    return 1
}

ask_user_confirmation() {
    local software=$1
    local version=$2
    
    echo
    print_message $YELLOW "Could not automatically detect $software $version"
    print_message $BLUE "Do you have $software $version installed? (y/n): "
    read -p "" -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0
    else
        return 1
    fi
}

show_verification_instructions() {
    local software=$1
    local version=$2
    
    print_message $BLUE "To verify your $software installation manually:"
    
    case $software in
        "FSL")
            print_message $YELLOW "  Run: cat \$FSLDIR/etc/fslversion"
            print_message $YELLOW "  Should show: $version"
            print_message $YELLOW "  Also verify \$FSLDIR is set: echo \$FSLDIR"
            ;;
        "FreeSurfer")
            print_message $YELLOW "  Run: cat \$FREESURFER_HOME/build-stamp.txt | grep 'v$version'"
            print_message $YELLOW "  Should show: v$version"
            print_message $YELLOW "  Also verify \$FREESURFER_HOME is set: echo \$FREESURFER_HOME"
            ;;
        "ANTs")
            print_message $YELLOW "  Run: antsRegistration --version"
            print_message $YELLOW "  Should show: Version: $version"
            print_message $YELLOW "  Also verify ANTs is in PATH: which antsRegistration"
            ;;
        "Workbench")
            print_message $YELLOW "  Run: wb_command -version"
            print_message $YELLOW "  Should show: Version: $version"
            print_message $YELLOW "  Also verify Workbench is in PATH: which wb_command"
            ;;
    esac
    echo
}

check_existing_software() {
    print_message $BLUE "=== Checking for existing installations ==="
    
    # Check FSL
    if current_version=$(check_fsl_version); then
        if [ "$current_version" == "$FSL_VERSION" ]; then
            print_message $GREEN "✓ FSL $FSL_VERSION found at $FSLDIR"
            FSL_FOUND=true
        else
            print_message $YELLOW "⚠ FSL found (v$current_version) but need v$FSL_VERSION"
            FSL_FOUND=false
        fi
    else
        print_message $YELLOW "✗ FSL $FSL_VERSION not found automatically"
        if ask_user_confirmation "FSL" "$FSL_VERSION"; then
            print_message $GREEN "✓ User confirmed FSL $FSL_VERSION is installed"
            show_verification_instructions "FSL" "$FSL_VERSION"
            print_message $BLUE "Proceeding with user confirmation..."
            FSL_FOUND=true
        else
            FSL_FOUND=false
        fi
    fi
    
    # Check FreeSurfer
    if current_version=$(check_freesurfer_version); then
        if [ "$current_version" == "$FREESURFER_VERSION" ]; then
            print_message $GREEN "✓ FreeSurfer $FREESURFER_VERSION found at $FREESURFER_HOME"
            FREESURFER_FOUND=true
        else
            print_message $YELLOW "⚠ FreeSurfer found (v$current_version) but need v$FREESURFER_VERSION"
            FREESURFER_FOUND=false
        fi
    else
        print_message $YELLOW "✗ FreeSurfer $FREESURFER_VERSION not found automatically"
        if ask_user_confirmation "FreeSurfer" "$FREESURFER_VERSION"; then
            print_message $GREEN "✓ User confirmed FreeSurfer $FREESURFER_VERSION is installed"
            show_verification_instructions "FreeSurfer" "$FREESURFER_VERSION"
            print_message $BLUE "Proceeding with user confirmation..."
            FREESURFER_FOUND=true
        else
            FREESURFER_FOUND=false
        fi
    fi
    
    # Check ANTs
    if current_version=$(check_ants_version); then
        if [[ "$current_version" == "$ANTS_VERSION"* ]]; then
            print_message $GREEN "✓ ANTs $ANTS_VERSION found"
            ANTS_FOUND=true
        else
            print_message $YELLOW "⚠ ANTs found (v$current_version) but need v$ANTS_VERSION"
            ANTS_FOUND=false
        fi
    else
        print_message $YELLOW "✗ ANTs $ANTS_VERSION not found automatically"
        if ask_user_confirmation "ANTs" "$ANTS_VERSION"; then
            print_message $GREEN "✓ User confirmed ANTs $ANTS_VERSION is installed"
            show_verification_instructions "ANTs" "$ANTS_VERSION"
            print_message $BLUE "Proceeding with user confirmation..."
            ANTS_FOUND=true
        else
            ANTS_FOUND=false
        fi
    fi
    
    # Check Workbench
    if current_version=$(check_workbench_version); then
        if [[ "$current_version" == "$WORKBENCH_VERSION"* ]]; then
            print_message $GREEN "✓ Workbench $WORKBENCH_VERSION found"
            WORKBENCH_FOUND=true
        else
            print_message $YELLOW "⚠ Workbench found (v$current_version) but need v$WORKBENCH_VERSION"
            WORKBENCH_FOUND=false
        fi
    else
        print_message $YELLOW "✗ Workbench $WORKBENCH_VERSION not found automatically"
        if ask_user_confirmation "Workbench" "$WORKBENCH_VERSION"; then
            print_message $GREEN "✓ User confirmed Workbench $WORKBENCH_VERSION is installed"
            show_verification_instructions "Workbench" "$WORKBENCH_VERSION"
            print_message $BLUE "Proceeding with user confirmation..."
            WORKBENCH_FOUND=true
        else
            WORKBENCH_FOUND=false
        fi
    fi
    
    echo
}

download_with_retry() {
    local url=$1
    local output=$2
    local description=$3
    local max_attempts=3

    if [ -f "$output" ]; then
        local size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null || echo 0)
        print_message $GREEN "✓ $description already downloaded ($(format_bytes $size))"
        return 0
    fi

    print_message $BLUE "Downloading $description..."
    
    for attempt in $(seq 1 $max_attempts); do
        print_message $BLUE "Attempt $attempt of $max_attempts..."
        
        if wget -c --timeout=30 --tries=3 --progress=bar:force:noscroll "$url" -O "$output.tmp"; then
            mv "$output.tmp" "$output"
            local size=$(stat -f%z "$output" 2>/dev/null || stat -c%s "$output" 2>/dev/null || echo 0)
            print_message $GREEN "✓ Downloaded! ($(format_bytes $size))"
            return 0
        else
            print_message $RED "Attempt $attempt failed."
            [ $attempt -lt $max_attempts ] && sleep 5
        fi
    done

    print_message $RED "ERROR: Failed to download $description"
    return 1
}

install_fsl_baremetal() {
    local os_type=$(detect_os)
    local install_dir="$HOME/fsl-${FSL_VERSION}"
    
    print_message $BLUE "Installing FSL ${FSL_VERSION} to $install_dir..."
    
    if [ "$os_type" == "linux" ]; then
        local url="https://fsl.fmrib.ox.ac.uk/fsldownloads/fsl-5.0.11-centos6_64.tar.gz"
        local tarball="/tmp/fsl-${FSL_VERSION}.tar.gz"
        
        download_with_retry "$url" "$tarball" "FSL ${FSL_VERSION}"
        mkdir -p "$install_dir"
        tar -xzf "$tarball" -C "$install_dir" --strip-components=1
        
        print_message $GREEN "✓ FSL installed to $install_dir"
        print_message $YELLOW "Add to your ~/.bashrc:"
        print_message $YELLOW "export FSLDIR=$install_dir"
        print_message $YELLOW "source \$FSLDIR/etc/fslconf/fsl.sh"
    else
        print_message $YELLOW "FSL ${FSL_VERSION} bare-metal install not supported on $os_type"
        print_message $YELLOW "Please use Docker mode or install manually"
    fi
}

install_freesurfer_baremetal() {
    local os_type=$(detect_os)
    local install_dir="$HOME/freesurfer-${FREESURFER_VERSION}"
    
    print_message $BLUE "Installing FreeSurfer ${FREESURFER_VERSION} to $install_dir..."
    
    if [ "$os_type" == "linux" ]; then
        local url="https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/6.0.0/freesurfer-Linux-centos6_x86_64-stable-pub-v6.0.0.tar.gz"
        local tarball="/tmp/freesurfer-${FREESURFER_VERSION}.tar.gz"
        
        download_with_retry "$url" "$tarball" "FreeSurfer ${FREESURFER_VERSION}"
        mkdir -p "$(dirname "$install_dir")"
        tar -xzf "$tarball" -C "$(dirname "$install_dir")"
        mv "$(dirname "$install_dir")/freesurfer" "$install_dir" 2>/dev/null || true
        
        print_message $GREEN "✓ FreeSurfer installed to $install_dir"
        print_message $YELLOW "Add to your ~/.bashrc:"
        print_message $YELLOW "export FREESURFER_HOME=$install_dir"
        print_message $YELLOW "source \$FREESURFER_HOME/SetUpFreeSurfer.sh"
        print_message $YELLOW "Note: You need a license file at \$FREESURFER_HOME/license.txt"
    else
        print_message $YELLOW "FreeSurfer ${FREESURFER_VERSION} bare-metal install not supported on $os_type"
    fi
}

install_ants_baremetal() {
    local os_type=$(detect_os)
    local install_dir="$HOME/ants-${ANTS_VERSION}"
    
    print_message $BLUE "Installing ANTs ${ANTS_VERSION} to $install_dir..."
    
    if [ "$os_type" == "linux" ]; then
        local url="https://github.com/ANTsX/ANTs/releases/download/v2.4.3/ants-2.4.3-centos7-X64-gcc.zip"
        local zipfile="/tmp/ants-${ANTS_VERSION}.zip"
        
        download_with_retry "$url" "$zipfile" "ANTs ${ANTS_VERSION}"
        mkdir -p "$install_dir"
        unzip -q "$zipfile" -d "$install_dir"
        
        print_message $GREEN "✓ ANTs installed to $install_dir"
        print_message $YELLOW "Add to your ~/.bashrc:"
        print_message $YELLOW "export ANTSPATH=$install_dir/bin"
        print_message $YELLOW "export PATH=\$ANTSPATH:\$PATH"
    else
        print_message $YELLOW "ANTs ${ANTS_VERSION} bare-metal install not supported on $os_type"
    fi
}

install_workbench_baremetal() {
    local os_type=$(detect_os)
    local install_dir="$HOME/workbench-${WORKBENCH_VERSION}"
    
    print_message $BLUE "Installing Connectome Workbench ${WORKBENCH_VERSION} to $install_dir..."
    
    if [ "$os_type" == "linux" ]; then
        local url="https://www.humanconnectome.org/storage/app/media/workbench/workbench-linux64-v1.5.0.zip"
        local zipfile="/tmp/workbench-${WORKBENCH_VERSION}.zip"
        
        download_with_retry "$url" "$zipfile" "Workbench ${WORKBENCH_VERSION}"
        mkdir -p "$install_dir"
        unzip -q "$zipfile" -d "$install_dir"
        
        print_message $GREEN "✓ Workbench installed to $install_dir"
        print_message $YELLOW "Add to your ~/.bashrc:"
        print_message $YELLOW "export PATH=$install_dir/workbench/bin_linux64:\$PATH"
    else
        print_message $YELLOW "Workbench ${WORKBENCH_VERSION} bare-metal install not supported on $os_type"
    fi
}

install_docker_mode() {
    print_message $BLUE "=== Docker Mode: Downloading & Packaging ==="
    mkdir -p ./cache
    
    # FreeSurfer
    if [ "$FREESURFER_FOUND" != true ]; then
        download_with_retry \
            "https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/6.0.0/freesurfer-Linux-centos6_x86_64-stable-pub-v6.0.0.tar.gz" \
            "./cache/freesurfer.tar.gz" \
            "FreeSurfer ${FREESURFER_VERSION}"
    fi
    
    # FSL
    if [ "$FSL_FOUND" != true ]; then
        download_with_retry \
            "https://fsl.fmrib.ox.ac.uk/fsldownloads/fsl-5.0.11-centos6_64.tar.gz" \
            "./cache/fsl.tar.gz" \
            "FSL ${FSL_VERSION}"
    fi
    
    # ANTs
    if [ "$ANTS_FOUND" != true ]; then
        download_with_retry \
            "https://github.com/ANTsX/ANTs/releases/download/v2.4.3/ants-2.4.3-centos7-X64-gcc.zip" \
            "./cache/ants.zip" \
            "ANTs ${ANTS_VERSION}"
    fi
    
    # Workbench
    if [ "$WORKBENCH_FOUND" != true ]; then
        download_with_retry \
            "https://www.humanconnectome.org/storage/app/media/workbench/workbench-linux64-v1.5.0.zip" \
            "./cache/workbench.zip" \
            "Workbench ${WORKBENCH_VERSION}"
    fi
    
    # Miniconda
    download_with_retry \
        "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh" \
        "./cache/miniconda.sh" \
        "Miniconda"
    
    print_message $GREEN "=== Cache ready for Docker build ==="
    ls -lh ./cache/ 2>/dev/null || dir ./cache/
}

install_baremetal_mode() {
    print_message $BLUE "=== Bare-Metal Installation ==="
    
    [ "$FSL_FOUND" != true ] && install_fsl_baremetal
    [ "$FREESURFER_FOUND" != true ] && install_freesurfer_baremetal
    [ "$ANTS_FOUND" != true ] && install_ants_baremetal
    [ "$WORKBENCH_FOUND" != true ] && install_workbench_baremetal
    
    print_message $GREEN "=== Installation complete ==="
    print_message $YELLOW "Remember to add the export commands to your ~/.bashrc and restart your terminal"
}

main() {
    print_message $BLUE "=== Neuroimaging Dependencies Setup ==="
    print_message $BLUE "Required versions: FSL ${FSL_VERSION}, FreeSurfer ${FREESURFER_VERSION}, ANTs ${ANTS_VERSION}, Workbench ${WORKBENCH_VERSION}"
    echo
    
    OS_TYPE=$(detect_os)
    print_message $BLUE "Detected OS: $OS_TYPE"
    echo
    
    check_existing_software
    
    # Ask user for installation mode
    print_message $BLUE "Select installation mode:"
    print_message $YELLOW "1) Docker (package for container)"
    print_message $YELLOW "2) Bare-metal (install directly on system)"
    echo
    read -p "Enter choice (1 or 2): " choice
    
    case $choice in
        1)
            install_docker_mode
            ;;
        2)
            install_baremetal_mode
            ;;
        *)
            print_message $RED "Invalid choice. Exiting."
            exit 1
            ;;
    esac
}

main

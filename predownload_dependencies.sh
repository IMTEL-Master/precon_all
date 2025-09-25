#!/bin/bash

# Pre-download large dependencies for Docker build
# Run this script before building your Docker image
# 
# USAGE:
# For long-running downloads on a server via SSH, use screen:
#   screen -S precon_download
#   ./predownload-dependencies.sh
#   # Press Ctrl+A, then D to detach
#   # Later: screen -r precon_download to reattach

set -e  # Exit on error

echo "Creating cache directory..."
mkdir -p ./cache

# Function to check if we're in screen/tmux
check_session() {
    if [[ -z "$STY" && -z "$TMUX" ]]; then
        echo "WARNING: Not running in screen or tmux session."
        echo "For SSH stability, consider running:"
        echo "  screen -S precon_download"
        echo "  ./predownload-dependencies.sh"
        echo ""
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
}

check_session

# Function to download with retry and resume capability
download_with_retry() {
    local url=$1
    local output=$2
    local description=$3
    local max_attempts=5
    
    if [ -f "$output" ]; then
        echo "$description already downloaded ($(du -h "$output" | cut -f1))."
        return 0
    fi
    
    echo "Downloading $description..."
    echo "URL: $url"
    echo "Output: $output"
    echo ""
    
    for attempt in $(seq 1 $max_attempts); do
        echo "Attempt $attempt of $max_attempts..."
        
        # Use wget with resume (-c), timeout settings, and retry logic
        if wget -c \
            --timeout=30 \
            --tries=3 \
            --retry-connrefused \
            --waitretry=5 \
            --progress=bar:force:noscroll \
            --show-progress \
            "$url" -O "$output.tmp"; then
            
            mv "$output.tmp" "$output"
            echo "$description downloaded successfully!"
            echo "Final size: $(du -h "$output" | cut -f1)"
            echo ""
            return 0
        else
            echo "Download attempt $attempt failed."
            if [ $attempt -lt $max_attempts ]; then
                echo "Waiting 10 seconds before retry..."
                sleep 10
            fi
        fi
    done
    
    echo "ERROR: Failed to download $description after $max_attempts attempts."
    return 1
}

# Download FreeSurfer (largest file - ~9GB)
download_with_retry \
    "https://surfer.nmr.mgh.harvard.edu/pub/dist/freesurfer/7.4.1/freesurfer-linux-centos7_x86_64-7.4.1.tar.gz" \
    "./cache/freesurfer.tar.gz" \
    "FreeSurfer 7.4.1"

# Handle FSL installation
handle_fsl() {
    local fsl_cache="./cache/fsl.tar.gz"
    local fsl_installer="./cache/getfsl.sh"
    local host_fsl_dir="$HOME/fsl"
    
    if [ -f "$fsl_cache" ]; then
        echo "[$(date)] FSL package already exists ($(du -h "$fsl_cache" | cut -f1))."
        return 0
    fi
    
    # Check if FSL is already installed on host
    if [ -d "$host_fsl_dir" ]; then
        echo "[$(date)] Found existing FSL installation at $host_fsl_dir"
        echo "[$(date)] Packaging FSL for Docker use..."
        tar -czf "$fsl_cache" -C "$(dirname "$host_fsl_dir")" "$(basename "$host_fsl_dir")" 2>/dev/null
        if [ $? -eq 0 ]; then
            echo "[$(date)] FSL packaged successfully! Size: $(du -h "$fsl_cache" | cut -f1)"
            return 0
        else
            echo "[$(date)] Failed to package existing FSL installation"
        fi
    fi
    
    # Download installer if not exists
    if [ ! -f "$fsl_installer" ]; then
        echo "[$(date)] Downloading FSL installer..."
        wget -c --progress=bar:force:noscroll \
            "https://fsl.fmrib.ox.ac.uk/fsldownloads/fslconda/releases/getfsl.sh" \
            -O "$fsl_installer"
        chmod +x "$fsl_installer"
    fi
    
    # Run installer to temporary location
    echo "[$(date)] Installing FSL to temporary location for packaging..."
    local temp_fsl="/tmp/fsl_temp"
    rm -rf "$temp_fsl"
    
    # Run installer non-interactively
    FSLDIR="$temp_fsl" bash "$fsl_installer" --skip_registration --no_self_update
    
    if [ -d "$temp_fsl" ]; then
        echo "[$(date)] Packaging temporary FSL installation..."
        tar -czf "$fsl_cache" -C "/tmp" "fsl_temp"
        rm -rf "$temp_fsl"
        echo "[$(date)] FSL installation packaged! Size: $(du -h "$fsl_cache" | cut -f1)"
    else
        echo "[$(date)] ERROR: FSL installation failed"
        return 1
    fi
}

# Call FSL handler instead of direct download
handle_fsl

# Download ANTs
download_with_retry \
    "https://github.com/ANTsX/ANTs/releases/download/v2.6.2/ants-2.6.2-ubuntu-22.04-X64-gcc.zip" \
    "./cache/ants.zip" \
    "ANTs 2.6.2"

# Download Miniconda
download_with_retry \
    "https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh" \
    "./cache/miniconda.sh" \
    "Miniconda"

echo ""
echo "=== DOWNLOAD COMPLETE ==="
echo "All dependencies downloaded to ./cache/"
echo ""
echo "Cache contents:"
ls -lh ./cache/
echo ""
echo "Total cache size: $(du -sh ./cache | cut -f1)"
echo ""
echo "Next steps:"
echo "1. Run: ./Precon_all_docker_cached.sh"
echo "2. Build: DOCKER_BUILDKIT=1 docker-compose build"
echo ""
echo "If running via SSH, you can safely disconnect now."

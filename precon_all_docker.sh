# Precon_all_docker.sh
# Generate the initial Dockerfile using Neurodocker
neurodocker generate docker \
    --pkg-manager apt \
    --base-image debian:bullseye-slim \
    --yes \
    --fsl version=6.0.7.1 \
    --freesurfer version=7.4.1 \
    --ants version=2.4.3 \
    --miniconda version=latest conda_install="nipype notebook" \
    --user nonroot > precon_all_dockerfile

# Append instructions to the Dockerfile
cat <<'EOF' >> precon_all_dockerfile
# Ensure FSL license acceptance is non-interactive
ENV FS_LICENSE_ACCEPTED=Yes

# Append instructions to the Dockerfile for installing Connectome Workbench and precon_all
# Install dependencies for Connectome Workbench, git, and echo command
RUN apt-get update && apt-get install -y wget unzip git \
    && rm -rf /var/lib/apt/lists/*

# Download and install Connectome Workbench
RUN wget https://www.humanconnectome.org/storage/app/media/workbench/workbench-linux64-v2.1.0.zip \
    && unzip workbench-linux64-v2.1.0.zip -d /opt/ \
    && rm workbench-linux64-v2.1.0.zip \
    && chmod +x /opt/workbench/bin_linux64/*

# Add Workbench to PATH
ENV PATH=/opt/workbench/bin_linux64:$PATH

# Clone the precon_all repository
RUN git clone https://github.com/neurabenn/precon_all.git /opt/precon_all

# Set up precon_all environment variables
ENV PCP_PATH=/opt/precon_all
ENV PATH=$PCP_PATH/bin:$PATH

# Note: Adjust the clone directory (/opt/precon_all) and paths as needed for your setup
EOF
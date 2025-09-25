#!/bin/bash

# Generate Dockerfile that uses pre-downloaded cache
cat <<'EOF' > precon_all_dockerfile

FROM debian:bullseye-slim

# Set non-interactive frontend
ENV DEBIAN_FRONTEND=noninteractive
ENV FS_LICENSE_ACCEPTED=Yes

# Install system dependencies
RUN apt-get update -qq && apt-get install -y -q --no-install-recommends \
    wget curl unzip git ca-certificates \
    build-essential tcsh bc tar libgomp1 \
    && rm -rf /var/lib/apt/lists/*

# Copy pre-downloaded files from host cache
COPY cache/freesurfer.tar.gz /tmp/
COPY cache/fsl.tar.gz /tmp/
COPY cache/ants.zip /tmp/
COPY cache/miniconda.sh /tmp/

# Install FreeSurfer
RUN echo "Installing FreeSurfer from cache..." && \
    mkdir -p /opt && \
    tar -xzf /tmp/freesurfer.tar.gz -C /opt && \
    rm /tmp/freesurfer.tar.gz

# Install FSL
RUN echo "Installing FSL from cache..." && \
    mkdir -p /opt && \
    tar -xzf /tmp/fsl.tar.gz -C /opt && \
    rm /tmp/fsl.tar.gz

# Install ANTs
RUN echo "Installing ANTs from cache..." && \
    mkdir -p /usr/local/sbin && \
    unzip /tmp/ants.zip -d /usr/local/sbin && \
    rm /tmp/ants.zip

# Install Miniconda
RUN echo "Installing Miniconda from cache..." && \
    bash /tmp/miniconda.sh -b -p /opt/miniconda-latest && \
    rm /tmp/miniconda.sh

# Install conda packages
RUN /opt/miniconda-latest/bin/conda install -y nipype notebook && \
    /opt/miniconda-latest/bin/conda clean -a

# Create non-root user
RUN useradd -m -s /bin/bash nonroot

# Set environment variables
ENV FSLDIR=/opt/fsl
ENV FREESURFER_HOME=/opt/freesurfer
ENV ANTSPATH=/usr/local/sbin/ants/bin
ENV PATH=/opt/miniconda-latest/bin:$ANTSPATH:$FSLDIR/bin:$FREESURFER_HOME/bin:$PATH

# Download and install Connectome Workbench (small download)
RUN wget https://www.humanconnectome.org/storage/app/media/workbench/workbench-linux64-v2.1.0.zip \
    && unzip workbench-linux64-v2.1.0.zip -d /opt/ \
    && rm workbench-linux64-v2.1.0.zip \
    && chmod +x /opt/workbench/bin_linux64/*

# Clone precon_all repository
RUN git clone https://github.com/neurabenn/precon_all.git /opt/precon_all

# Set up precon_all environment
ENV PCP_PATH=/opt/precon_all
ENV PATH=$PCP_PATH/bin:/opt/workbench/bin_linux64:$PATH

# Switch to non-root user
USER nonroot
WORKDIR /home/nonroot

EOF

echo "Cached Dockerfile created. Make sure to run './predownload-dependencies.sh' first!"

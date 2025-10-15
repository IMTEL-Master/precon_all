# precon_all: Animal Surface Generation Pipeline

precon_all is a neuroimaging pipeline designed for cortical surface reconstruction from T1-weighted MRI images across multiple animal species. Built on FreeSurfer, it provides automated surface generation with species-specific adaptations.

## Table of Contents
- [Overview](#overview)
- [System Requirements](#system-requirements)
- [Setup Methods](#setup-methods)
- [Quick Start](#quick-start)
- [Data Requirements](#data-requirements)
- [Usage Guide](#usage-guide)
- [Pipeline Modules](#pipeline-modules)
- [Troubleshooting](#troubleshooting)

## Overview

precon_all processes T1-weighted MRI images to generate cortical surfaces for animal subjects. The pipeline handles:
- Brain extraction
- Tissue segmentation (gray matter, white matter, CSF)
- White matter surface reconstruction
- Pial surface generation
- Surface mesh optimization

**Typical runtime**: 2-5 hours per subject (up to 18 hours for highly gyrified brains)

## System Requirements

### Minimum Hardware
- **RAM**: 16GB minimum, 32GB recommended
- **Storage**: 50GB free space for Docker images and processing
- **CPU**: Multi-core processor (4+ cores recommended)

### Software Dependencies (Bare-Metal Installation)
- FreeSurfer 6.0+ 
- FSL 5.0.11+
- ANTs 2.3.1+
- Connectome Workbench 1.5.0+

### Docker Requirements
- Docker Engine 20.10+
- 50GB+ available disk space

## Setup Methods

The setup process has been streamlined with two new scripts:
- `predownload-dependencies.sh`: Automatically handles software dependencies
- `generate-dockerfile.sh`: Creates optimized Docker containers

### Method 1: Bare-Metal Installation (Recommended)

Direct installation on your system provides the best performance and flexibility.

#### Prerequisites
1. **FreeSurfer License**: Required for operation
   - Obtain free license at: https://surfer.nmr.mgh.harvard.edu/registration.html
   - Save as `license.txt` in the repository root

#### Setup Steps

1. **Clone Repository**:
   ```bash
   git clone https://github.com/neurabenn/precon_all.git
   cd precon_all
   ```

2. **Download and Install Dependencies**:
   ```bash
   chmod +x predownload-dependencies.sh
   ./predownload-dependencies.sh
   ```
   
   The `predownload-dependencies.sh` script will:
   - Check for existing installations of required software
   - Download and install missing dependencies automatically
   - Set up proper environment variables
   - Verify installations work correctly
   
   Choose option 2 (bare-metal) when prompted. The script supports automatic installation on Linux and provides guidance for other platforms.

3. **Set Environment Variables**:
   Add the suggested export commands to your `~/.bashrc` and restart your terminal, or source the file:
   ```bash
   source ~/.bashrc
   ```

4. **Verify Installation**:
   ```bash
   export PCP_PATH=/path/to/precon_all
   export PATH=$PCP_PATH/bin:$PATH
   which surfing_safari.sh
   ```

### Method 2: Docker Installation

Docker provides a containerized environment with all dependencies pre-installed.

#### Setup Steps

1. **Clone Repository**:
   ```bash
   git clone https://github.com/neurabenn/precon_all.git
   cd precon_all
   ```

2. **Download Dependencies** (Optional - for faster builds):
   ```bash
   chmod +x predownload-dependencies.sh
   ./predownload-dependencies.sh
   ```
   Choose option 1 (Docker) to pre-download all dependencies to a local cache.

3. **Generate Dockerfile**:
   ```bash
   chmod +x generate-dockerfile.sh
   ./generate-dockerfile.sh cached  # Use cached build if you ran step 2
   # OR
   ./generate-dockerfile.sh direct  # Direct download during build
   ```
   
   The `generate-dockerfile.sh` script replaces the old compose method and:
   - Creates an optimized Dockerfile for your build type
   - Handles both cached (faster) and direct (simpler) builds
   - Automatically configures all software dependencies
   - Sets up proper environment variables

4. **Build Docker Image**:
   ```bash
   docker build -t precon_all -f precon_all_dockerfile .
   ```

5. **Run Container**:
   ```bash
   docker run -it \
     -v $(pwd)/data:/data \
     -v $(pwd)/license.txt:/opt/freesurfer/license.txt \
     precon_all bash
   ```

## Data Requirements

### Input Data Types

#### Input Images with T1-Like Contrast
- **Formats**: NIfTI (.nii or .nii.gz), NRRD (.nrrd)
- **Resolution**: 0.2mm to 0.8mm isotropic (0.2mm minimum due to pial expansion limits)
- **Orientation**: Any standard orientation (pipeline handles reorientation)
- **Acquisition types**: Both in-vivo and post-mortem data supported

**Supported Contrast Types:**
- **Native T1-weighted**: Direct input (recommended)
- **T2-weighted**: Requires contrast inversion (see preprocessing guide)
- **Diffusion-weighted**: Requires processing through FSL's BedpostX
- **Magnetization Transfer Ratio (MTR)**: Can be used directly
- **Proton Density (PD)**: Can be used directly

**Preprocessing for Non-T1 Images:**
- T2 inversion: `multiply by -1, add absolute minimum value, apply brain mask`
- DWI processing: `sum squares of BedpostX samplesf1 and samplesf2, take square root`

#### Required Masks (for new species setup)

All masks must be binary (0s and 1s) in the same space as your T1 image:

1. **Brain Mask** (`brain_mask.nii.gz`)
   - Includes all brain tissue
   - Excludes skull, scalp, and non-brain tissue

2. **Left Hemisphere** (`left_hem.nii.gz`)
   - Contains only left hemisphere cortical tissue
   - Should not overlap with right hemisphere

3. **Right Hemisphere** (`right_hem.nii.gz`)
   - Contains only right hemisphere cortical tissue
   - Should not overlap with left hemisphere

4. **Subcortical Mask** (`sub_cort.nii.gz`)
   - Includes corpus callosum, brainstem, ventricles
   - Area filled by medial wall during processing

5. **Non-Cortical Mask** (`non_cort.nii.gz`)
   - Brainstem, cerebellum, and other structures to exclude
   - These areas won't appear in final surfaces

#### Optional: Tissue Priors
Place in `seg_priors/` folder:
- `csf.nii.gz`: Probability map for cerebrospinal fluid
- `gm.nii.gz`: Probability map for gray matter  
- `wm.nii.gz`: Probability map for white matter

**Note**: Priors improve segmentation accuracy but are not required.

## Quick Start

### Single Subject Processing

For a new species with custom masks:
```bash
# 1. Organize your data
mkdir -p myproject/masks
cp brain_mask.nii.gz myproject/masks/
cp left_hem.nii.gz myproject/masks/
cp right_hem.nii.gz myproject/masks/
cp sub_cort.nii.gz myproject/masks/
cp non_cort.nii.gz myproject/masks/

# 2. Run pipeline
cd myproject
surfing_safari.sh -i subject_T1.nii.gz -r precon_all -a masks
```

### Batch Processing with Standard Template

For established species (e.g., pig):
```bash
surfing_safari.sh -i subject_T1.nii.gz -r precon_all -a pig
```

## Usage Guide

### Setting Up a New Species Template

1. **Create species directory**:
   ```bash
   mkdir -p $PCP_PATH/standards/myspecies
   ```

2. **Set up extraction folder**:
   ```bash
   mkdir -p $PCP_PATH/standards/myspecies/extraction
   # Place these files:
   # - myspecies_temp.nii.gz (whole head template)
   # - brain_mask.nii.gz (brain extraction mask)
   # - myspecies_brain.nii.gz (brain-extracted template)
   ```

3. **Set up fill folder**:
   ```bash
   mkdir -p $PCP_PATH/standards/myspecies/fill
   # Place these files:
   # - left_hem.nii.gz, right_hem.nii.gz
   # - sub_cort.nii.gz, non_cort.nii.gz
   ```

4. **Optional: Add tissue priors**:
   ```bash
   mkdir -p $PCP_PATH/standards/myspecies/seg_priors
   # Place: csf.nii.gz, gm.nii.gz, wm.nii.gz
   ```

### Command Line Options

```bash
surfing_safari.sh -i <input.nii.gz> -r <module> -a <species> [options]
```

**Required Arguments**:
- `-i`: Input T1 image
- `-r`: Pipeline module (see modules below)
- `-a`: Species name or 'masks' for custom masks

**Optional Flags**:
- `-n`: Skip brain extraction (for pre-extracted brains)
- `-s`: Use ANTs instead of FSL FAST for segmentation
- `-L`: Process left hemisphere only
- `-R`: Process right hemisphere only
- `-v <N>`: Downsample to N vertices
- `-t <threshold>`: Custom white matter segmentation threshold

## Validated Species & Public Datasets

### Tested Species (28+ species validated)

**Primates:**
- Great Apes: Chimpanzee, Gibbon
- Old World Monkeys: Macaque, Mangabey, Colobus
- New World Monkeys: Capuchin, Marmoset, Night Monkey
- Prosimians: Galago

**Carnivores (18 species):**
- Canids: Domestic Dog, Dingo, Grey Wolf, African Wild Dog, Bush Dog, Fennec Fox, Red Fox
- Felids: Domestic Cat, Asiatic Lion, Amur Leopard, Eurasian Lynx
- Bears: Brown Bear
- Other: Raccoon, Red Panda, Meerkat, South American Coati, Asian Small-clawed Otter, Eurasian Badger

**Artiodactyls:**
- Domestic Pig

### Recommended Public Datasets

Based on successful validations and community resources:

**Allen Institute Mouse Brain Atlas:**
- **URL**: https://download.alleninstitute.org/informatics-archive/current-release/mouse_ccf/
- **Details**: Allen CCF v3 (1675 adult C57Bl6/J specimens)
- **Resolution**: 0.01 mm³ (10 µm isotropic) - *Note: Below precon_all's current 0.2mm minimum*

**Digital Brain Zoo:**
- **URL**: https://open.win.ox.ac.uk/DigitalBrainBank/
- **Species**: 24+ species with diffusion-weighted and structural data
- **Used for**: Majority of carnivore and primate validations in precon_all

**PRIME-DE (PRIMatE Data Exchange):**
- **URL**: http://fcon_1000.projects.nitrc.org/indi/indiPRIME.html  
- **Species**: Multiple non-human primate datasets
- **Used for**: Macaque template generation and validation

**National Chimpanzee Brain Resource:**
- Individual subject data for great ape processing

**Additional Resources:**
- Marmoset Brain: https://www.scidb.cn/en/detail?dataSetId=8d8589a8c6014f90b69f1a5ce1949dc9
- Waxholm Rat Space: https://www.nitrc.org/projects/whs-sd-atlas (39 µm resolution)
- MEBRAINS Macaque: https://search.kg.ebrains.eu/instances/de58ab47-b980-437c-8906-87f1123e14fb

**Note on Resolution Limits**: precon_all currently requires minimum 0.2mm isotropic resolution. High-resolution datasets like the Allen Mouse Atlas (10 µm) would need downsampling for compatibility.

### Usage Examples

```bash
# Standard pig processing
surfing_safari.sh -i pig_brain.nii.gz -r precon_all -a pig

# Pre-extracted brain with ANTs segmentation
surfing_safari.sh -i extracted_brain.nii.gz -r precon_all -a pig -n -s

# Left hemisphere only, downsampled
surfing_safari.sh -i subject.nii.gz -r precon_all -a pig -L -v 10000

# Custom masks for new species
surfing_safari.sh -i novel_species.nii.gz -r precon_all -a masks

# Process T2-weighted image (requires preprocessing)
# First invert contrast: multiply by -1, add absolute minimum, apply brain mask
surfing_safari.sh -i inverted_t2.nii.gz -r precon_all -a masks
```

## Dependency Management

### predownload-dependencies.sh

This script streamlines the setup process by automatically handling software dependencies:

**Features:**
- **Automatic Detection**: Checks for existing installations and versions
- **Smart Installation**: Only downloads/installs missing or incorrect versions
- **Dual Mode Support**: 
  - Bare-metal: Direct system installation
  - Docker: Pre-downloads to cache for faster container builds
- **Cross-Platform**: Supports Linux, macOS, and Windows (with guidance)
- **Interactive Verification**: Prompts user confirmation when automatic detection fails

**Usage:**
```bash
./predownload-dependencies.sh
# Follow prompts to select installation mode
```

The script handles:
- FreeSurfer 6.0.0
- FSL 5.0.11  
- ANTs 2.3.1
- Connectome Workbench 1.5.0
- Miniconda (for Python dependencies)

### generate-dockerfile.sh

This script replaces the old docker-compose workflow with a more flexible approach:

**Features:**
- **Cached Builds**: Use pre-downloaded dependencies for faster builds
- **Direct Builds**: Download during build process (simpler but slower)
- **Unified Dockerfile**: Single file handles both build types
- **Automatic Optimization**: Configures paths and permissions correctly
- **License Integration**: Automatically includes FreeSurfer license

**Usage:**
```bash
# For cached build (faster, requires predownload-dependencies.sh first)
./generate-dockerfile.sh cached

# For direct build (simpler, downloads during build)
./generate-dockerfile.sh direct
```

**Build Process:**
1. Generates optimized Dockerfile as `precon_all_dockerfile`
2. Sets up all required software with proper paths
3. Creates non-root user for security
4. Configures environment variables automatically

## Pipeline Modules

### precon_all (Complete Pipeline)
- Full cortical surface reconstruction from raw T1 image
- Includes all processing steps

### precon_1 (Brain Extraction Only)
- Performs only brain extraction
- Useful for batch preprocessing

### precon_2 (Processing Without Extraction)
- Denoising, segmentation, WM fill, surface generation
- Use when brain is already extracted

### precon_3 (Surface Generation Only)
- WM filling and surface generation only
- Requires existing segmentation

### precon_4 (Surface Downsampling)
- Downsamples existing surfaces
- Requires `-v` flag with vertex count
- Run after successful precon_all completion

### precon_art (Visualization)
- Generates surfaces including non-cortical structures
- For visualization and figures only
- Not for quantitative analysis
- Run only after successful precon_all

### pet_sounds.sh (Group Template Generation)
- Creates population-level surface templates for spherical registration
- Enables group-level statistical analysis similar to human neuroimaging
- Iterative registration process (4 iterations) for optimal template creation
- Outputs average surfaces compatible with multimodal surface matching
- **Usage**: `pet_sounds.sh -s <subject_list> -t <reference_subject>`

## Applications & Research Impact

precon_all enables several cutting-edge research applications in comparative neuroscience:

### Cross-Species Translation
- **Connectivity blueprints**: Map white matter tract terminations across species
- **Phylogenetic alignment**: Compare cortical organization between distantly related species
- **Evolutionary analysis**: Study how cortical folding and structure evolved across mammalian lineages

### Novel Applications
- **Digital atlas creation**: Build anatomical atlases for species new to neuroimaging
- **Sulcal morphology studies**: Characterize cortical folding patterns (validated across 18 carnivore species)
- **Preclinical translation**: Bridge animal model findings to human clinical applications

### Integration with Existing Tools
- **XTRACT compatibility**: Standardized tractography protocols for cross-species connectivity
- **Connectome Workbench**: Direct GIFTI format output for advanced visualization
- **Multimodal Surface Matching (MSM)**: Enable HCP-style processing workflows for animal data
- **Non-negative matrix factorization**: Hypothesis-free tract identification in unstudied species

### Research Publications
Recent studies using precon_all surfaces:
- Carnivore cortical morphology across 18 species
- Pig-human connectivity translations  
- Primate evolutionary hierarchy analysis
- Cross-species cortical alignment studies

## Surface Editing

To manually correct surfaces (following FreeSurfer conventions):

1. Edit the white matter segmentation in your favorite editor
2. Save as `wm_hand_edit.nii.gz` in the subject's `/mri/` folder
3. Re-run surface generation

This follows the standard [FreeSurfer pial editing workflow](https://surfer.nmr.mgh.harvard.edu/fswiki/FsTutorial/PialEditsV6.0).

1. Edit the white matter segmentation in your favorite editor
2. Save as `wm_hand_edit.nii.gz` in the subject's `/mri/` folder
3. Re-run surface generation

This follows the standard [FreeSurfer pial editing workflow](https://surfer.nmr.mgh.harvard.edu/fswiki/FsTutorial/PialEditsV6.0).

## Output Structure

```
subject_directory/
├── mri/                    # Segmentation and volume data
│   ├── T1.nii.gz
│   ├── wm.nii.gz
│   └── aseg.nii.gz
├── surf/                   # Surface files
│   ├── lh.white
│   ├── lh.pial
│   ├── rh.white
│   └── rh.pial
└── stats/                  # Surface statistics
    ├── lh.curv.stats
    └── rh.curv.stats
```

## Troubleshooting

### Common Issues

**Pipeline hangs/takes too long**:
- Kill process if runtime exceeds 18 hours
- Check input image quality and resolution
- Consider manual brain extraction first

**Segmentation errors**:
- Try ANTs segmentation with `-s` flag
- Adjust WM threshold with `-t` flag
- Add tissue priors if available

**Surface defects**:
- Use manual editing workflow
- Check mask quality for new species
- Verify template registration

**Docker issues**:
- Ensure sufficient disk space (50GB+)
- Verify FreeSurfer license path at repository root
- Use `generate-dockerfile.sh` instead of manual Dockerfile creation
- For build failures, try `direct` mode instead of `cached`

**Dependency issues**:
- Run `predownload-dependencies.sh` to verify all software is properly installed
- Check that environment variables are set correctly in your shell
- Ensure FreeSurfer license is valid and in the correct location

**Migration from older versions**:
- Remove any old `precon_all_dockerfile` - use `generate-dockerfile.sh` instead
- The new scripts replace docker-compose workflows
- Bare-metal installation is now the recommended primary method

### Performance Tips

- **Bare-metal installation** provides better performance than Docker
- Use SSD storage for faster I/O
- Process hemispheres separately for very large brains (`-L` or `-R` flags)
- Use tissue priors when available for better segmentation
- Pre-download dependencies with `predownload-dependencies.sh` for faster Docker builds

## Support

For questions and issues:
- Email: **r.austinbenn@gmail.com**
- Include: species, command used, error messages, and input data description

## Citation

If you use precon_all in your research, please cite:

```bibtex
@article{benn2025precon,
  title={Precon_all: A species-agnostic automated pipeline for non-human cortical surface reconstruction},
  author={Benn, R Austin and Xu, Ting and Mars, Rogier B and Boch, Magdalena and Roumazeilles, Lea and Heuer, Katja and Toro, Roberto and Margulies, Daniel S and Manzano-Patron, JP and Montesinos, Paula and others},
  journal={bioRxiv},
  pages={2025--04},
  year={2025},
  publisher={Cold Spring Harbor Laboratory}
}
```

Additionally, please cite the underlying tools used in your specific workflow:
- **FreeSurfer**: Fischl, B. (2012). FreeSurfer. NeuroImage, 62(2), 774-781.
- **FSL**: Jenkinson, M., et al. (2012). FSL. NeuroImage, 62(2), 782-790.
- **ANTs**: Avants, B.B., et al. (2009). Advanced Normalization Tools (ANTS). Insight Journal.
- **Connectome Workbench**: Marcus, D.S., et al. (2011). Informatics and data mining tools for the Human Connectome Project.
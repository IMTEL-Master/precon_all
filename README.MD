# precon_all: Animal Surface Generation Pipeline

precon_all is a neuroimaging pipeline designed for cortical surface reconstruction from T1-weighted MRI images across multiple animal species. Built on FreeSurfer, it provides automated surface generation with species-specific adaptations.

## Table of Contents
- [Overview](#overview)
- [System Requirements](#system-requirements)
- [Installation Methods](#installation-methods)
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

### Software Dependencies (Native Installation)
- FreeSurfer 6.0+ 
- FSL 6.0+
- ANTs 2.3.5+
- Connectome Workbench 1.5.0+

### Docker Requirements
- Docker Engine 20.10+
- Docker Compose 2.0+ (recommended)
- 50GB+ available disk space

## Installation Methods

### Method 1: Docker (Recommended)

Docker installation provides a containerized environment with all dependencies pre-installed.

#### Prerequisites
1. **FreeSurfer License**: Required for operation
   - Obtain free license at: https://surfer.nmr.mgh.harvard.edu/registration.html
   - Save as `license.txt`

2. **Python Environment**:
   ```bash
   python3 -m venv precon_env
   source precon_env/bin/activate  # Linux/Mac
   # precon_env\Scripts\activate  # Windows
   pip install neurodocker
   ```

#### Setup Steps

1. **Clone Repository**:
   ```bash
   git clone https://github.com/neurabenn/precon_all.git
   cd precon_all
   ```

2. **Prepare Data Directory**:
   ```bash
   mkdir -p data
   # Place your T1 images and masks in data/
   ```

3. **Generate Dockerfile**:
   ```bash
   chmod +x precon_all_docker.sh
   ./precon_all_docker.sh
   ```

4. **Build Docker Image** (⚠️ This takes 30-60 minutes):
   ```bash
   # For Intel/AMD processors
   sudo docker build --platform linux/amd64 -t precon_all -f precon_all_dockerfile .
   
   # For Apple Silicon Macs
   sudo docker build --platform linux/arm64 -t precon_all -f precon_all_dockerfile .
   ```

5. **Run Container**:
   ```bash
   sudo docker run -it \
     -v $(pwd)/data:/data \
     -v $(pwd)/license.txt:/opt/freesurfer/license.txt \
     precon_all bash
   ```

#### Docker Compose Method (Automated)

Create `docker-compose.yml`:
```yaml
version: '3.8'
services:
  precon_all:
    build:
      context: .
      dockerfile: precon_all_dockerfile
      platform: linux/amd64  # Change to linux/arm64 for Apple Silicon
    volumes:
      - ./data:/data
      - ./license.txt:/opt/freesurfer/license.txt
      - ./output:/output
    working_dir: /data
    stdin_open: true
    tty: true
    environment:
      - SUBJECTS_DIR=/output
```

Run with:
```bash
docker-compose up --build
docker-compose exec precon_all bash
```

### Method 2: Native Installation

1. Install dependencies following each package's documentation
2. Clone repository: `git clone https://github.com/neurabenn/precon_all.git`
3. Set environment variable: `export PCP_PATH=/path/to/precon_all`
4. Add to PATH: `export PATH=$PCP_PATH/bin:$PATH`

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
- Verify FreeSurfer license path
- Check platform specification in build command

### Performance Tips

- Use SSD storage for faster I/O
- Allocate maximum available RAM to Docker
- Process hemispheres separately for very large brains
- Use tissue priors when available

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
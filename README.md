# Stack_stitcher_Maatlab

This repository provides a MATLAB-based implementation for high-precision alignment and stitching of serial-section imaging data. It is specifically designed to handle large-scale volumetric datasets, such as those used for mapping individual sensory nerve axons across multiple spinal levels.

### 📌 Background
This project is a MATLAB implementation based on the **"StitchIt" pipeline** introduced in the following research:
> **Paper:** *Mapping of individual sensory nerve axons from digits to spinal cord with the transparent embedding solvent system*  
> **Journal:** *Cell Research* (2024)  
> **Authors:** Zhang, X., et al.

While the original pipeline was developed in Python to enable 3D reconstruction of long-range axonal projections, this version provides a MATLAB alternative to support researchers within the MATLAB scientific computing environment.

---

### ✨ Key Features
- **XY Plane Stitching (`main_xy.m`)**: Performs seamless stitching of multiple fields of view (FOV) within a single tissue section.
- **Z-Axis Alignment (`main_z.m`)**: Aligns sequential tissue stacks to ensure continuity in 3D reconstructions.
- **Library Support**:
  - **`+stitchlib`**: A dedicated MATLAB package for custom stitching and alignment functions.
  - **`bfmatlab`**: Integration with the Bio-Formats library to support various microscopy formats (e.g., .czi, .nd2, .lif).

---

### 🚀 Getting Started

#### Prerequisites
- **MATLAB**: Recommended version R2020b or later.
- **Note**: Ensure the folder structure is maintained. Do not rename or remove the `+` prefix from the `+stitchlib` folder, as it is a MATLAB package directory.

#### Installation & Setup
1. Clone or download this repository to your local machine.
2. Download `bfmatlab` from the official OME website if you haven't already.
3. In MATLAB, add both this project and the `bfmatlab` folder to your path:
   ```matlab
   % Add this project
   addpath(genpath('your_path_to/Stack_stitcher'));
   % Add Bio-Formats
   addpath('your_path_to/bfmatlab');
   savepath;

#### Usage
- **Horizontal Stitching**: Open main_xy.m, configure your input data paths, and run the script to stitch FOVs within sections.
- **Vertical Alignment**: Use main_z.m to align processed stacks for volumetric continuity.

---

### Acknowledgments
Special thanks to the authors of the "StitchIt" pipeline for their contribution to the field of large-scale neural mapping and for developing the original algorithms. This MATLAB implementation aims to extend the accessibility of their work to the broader biological imaging community.


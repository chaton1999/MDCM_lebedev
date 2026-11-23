# DCM Reference Data Preparation Workflow

This directory contains the complete workflow for preparing the DCM reference data used in the MDCM fitting procedure.

The workflow is:

```text
DCM XYZ
   ↓
xTB molecular dynamics
   ↓
RMSD selection of 4 diverse structures
   ↓
Gaussian MP2 calculations
   ↓
MP2 density + ESP cubes
   ↓
copy completed Gaussian data to master/gaussian
   ↓
prepare optimized + conformer cubes
   ↓
generate local frames
   ↓
single/ + frames.txt
```

The main working directory is:

```text
/cluster/home/chaton/MDCM-project-pantelis/organic_molecules/ref/dcm
```

---

# 1. Create the Conda environment

Create a dedicated environment first:

```bash
conda create -n xtb_env -c conda-forge python=3.12
```

Activate it:

```bash
conda activate xtb_env
```

Install the required packages:

```bash
conda install -c conda-forge ase xtb openbabel numpy
```

The `openbabel` package provides the `obabel` executable.

Verify the installation:

```bash
python --version
xtb --version
obabel -V
```

Optional checks:

```bash
python -c "import ase; print(ase.__version__)"
python -c "import numpy; print(numpy.__version__)"
```

Whenever this workflow is used later, activate the environment with:

```bash
conda activate xtb_env
```

---

# 2. Directory layout

The top-level DCM directory should contain:

```text
dcm/
├── README.md
├── ref_prepare.sh
├── get_frame.py
├── fix_cube.pl
├── frames.txt
├── single/
└── master/
    ├── gaussian/
    └── data_prep/
```

The structure-generation and Gaussian calculations are performed inside:

```text
master/data_prep/
```

Enter it with:

```bash
cd /cluster/home/chaton/MDCM-project-pantelis/organic_molecules/ref/dcm/master/data_prep
```

---

# 3. Initial files in `master/data_prep`

The working directory should contain at least:

```text
dcm.xyz

xtb.sh
select_4_rmsd.py

create.sh
submit.sh
gaussian.slurm
cube.sh
```

`dcm.xyz` is the starting/reference DCM structure.

---

# 4. Run xTB molecular dynamics

Activate the environment:

```bash
conda activate xtb_env
```

Run:

```bash
./xtb.sh dcm.xyz
```

The MD trajectory is written under:

```text
dcm_xtb_md/
```

The important trajectory is:

```text
dcm_xtb_md/xtb.trj
```

After this step:

```text
data_prep/
├── dcm.xyz
├── dcm_xtb_md/
│   ├── xtb.trj
│   ├── xtb_md.log
│   └── mdrestart
└── ...
```

---

# 5. Select four RMSD-diverse structures

Run:

```bash
python select_4_rmsd.py dcm_xtb_md/xtb.trj
```

The RMSD selection uses Kabsch alignment and chooses four geometrically diverse structures from the MD trajectory.

The selected structures are:

```text
dcm1.xyz
dcm2.xyz
dcm3.xyz
dcm4.xyz
```

The RMSD information is stored in:

```text
selected_frames.dat
selected_pairwise_rmsd.dat
```

The reference geometry remains:

```text
dcm.xyz
```

Therefore the complete set is:

```text
dcm.xyz     reference structure
dcm1.xyz    RMSD-selected structure
dcm2.xyz    RMSD-selected structure
dcm3.xyz    RMSD-selected structure
dcm4.xyz    RMSD-selected structure
```

---

# 6. Generate Gaussian inputs

Run:

```bash
./create.sh
```

`create.sh` processes all available `.xyz` files.

The structure that should be optimized is explicitly selected inside `create.sh`, for example:

```bash
OPT_XYZ="dcm.xyz"
```

Only this XYZ file receives the optimization keywords.

For the reference structure:

```text
dcm.xyz
```

the route is:

```text
# opt Freq=NoRaman mp2/aug-cc-pvtz density=current scf=maxcycle=200
```

The RMSD-selected structures:

```text
dcm1.xyz
dcm2.xyz
dcm3.xyz
dcm4.xyz
```

must **not** be optimized.

Their route is:

```text
# mp2/aug-cc-pvtz density=current scf=maxcycle=200
```

This preserves the structural diversity obtained from the MD/RMSD procedure.

The keyword:

```text
density=current
```

is important because the MP2 density must be stored in the Gaussian checkpoint for later MP2 density and ESP cube generation.

`create.sh` creates:

```text
data_prep/gaussian/
├── dcm.com
├── dcm1.com
├── dcm2.com
├── dcm3.com
├── dcm4.com
├── submit.sh
├── gaussian.slurm
└── cube.sh
```

Before submitting, check the Gaussian routes:

```bash
grep "^#" gaussian/*.com
```

---

# 7. Submit the Gaussian calculations

Enter:

```bash
cd gaussian
```

Submit all Gaussian calculations with:

```bash
./submit.sh
```

Monitor them with:

```bash
squeue -u $USER
```

To submit only one structure manually:

```bash
sbatch --job-name=dcm1 gaussian.slurm dcm1.com
```

The SLURM script runs Gaussian using scratch space and copies the persistent files back into the current Gaussian directory.

After successful calculations there should be:

```text
dcm.chk
dcm.out

dcm1.chk
dcm1.out

dcm2.chk
dcm2.out

dcm3.chk
dcm3.out

dcm4.chk
dcm4.out
```

Check normal termination:

```bash
grep "Normal termination" *.out
```

All five calculations should show normal termination before continuing.

---

# 8. Generate MP2 density and ESP cubes

Still inside:

```text
master/data_prep/gaussian/
```

run:

```bash
./cube.sh
```

For every checkpoint the script performs:

```text
.chk
 ↓
.fchk
 ↓
MP2 density cube
MP2 ESP cube
```

For example:

```text
dcm1.chk
   ↓
dcm1.fchk
   ↓
dcm1_dens.cube
dcm1_esp.cube
```

The script uses:

```text
Density=MP2
```

and:

```text
Potential=MP2
```

for the corresponding cubes.

---

# 9. Verify that MP2 density exists

The formatted checkpoint should contain the MP2 density.

For example:

```bash
grep -E "Total (SCF|MP2) Density" dcm1.fchk
```

A correct calculation should contain:

```text
Total SCF Density
Total MP2 Density
```

If only:

```text
Total SCF Density
```

is present, check that the corresponding Gaussian input contained:

```text
density=current
```

before continuing.

---

# 10. Copy the completed Gaussian directory one level back

The calculations are performed under:

```text
master/data_prep/gaussian/
```

After the Gaussian calculations and cube generation are complete, keep the final Gaussian reference data separately under:

```text
master/gaussian/
```

From:

```text
master/data_prep/
```

first check whether an older `master/gaussian` directory already exists:

```bash
ls -ld ../gaussian
```

If an older version should be preserved, rename it first:

```bash
mv ../gaussian ../gaussian_backup
```

Then copy the completed Gaussian directory:

```bash
cp -a gaussian ../gaussian
```

The layout is now:

```text
master/
├── data_prep/
│   ├── dcm.xyz
│   ├── dcm1.xyz
│   ├── dcm2.xyz
│   ├── dcm3.xyz
│   ├── dcm4.xyz
│   ├── dcm_xtb_md/
│   └── gaussian/
│
└── gaussian/
    ├── dcm.com
    ├── dcm.chk
    ├── dcm.out
    ├── dcm.fchk
    ├── dcm_dens.cube
    ├── dcm_esp.cube
    ├── dcm1...
    ├── dcm2...
    ├── dcm3...
    └── dcm4...
```

`master/data_prep/` therefore remains the preparation/work directory, while:

```text
master/gaussian/
```

contains the completed Gaussian reference data used by the next stage.

---

# 11. Prepare the cube filenames expected by `ref_prepare.sh`

The current `cube.sh` produces names such as:

```text
dcm_dens.cube
dcm_esp.cube

dcm1_dens.cube
dcm1_esp.cube
...
```

However, the current `ref_prepare.sh` expects:

```text
dcm.cube
esp-dcm.cube

dcm1.cube
esp-dcm1.cube

dcm2.cube
esp-dcm2.cube

dcm3.cube
esp-dcm3.cube

dcm4.cube
esp-dcm4.cube
```

Therefore, inside:

```text
master/gaussian/
```

create the expected names while retaining the original cube files.

For the optimized/reference structure:

```bash
cp dcm_dens.cube dcm.cube
cp dcm_esp.cube  esp-dcm.cube
```

For the four conformers:

```bash
for i in 1 2 3 4; do
    cp "dcm${i}_dens.cube" "dcm${i}.cube"
    cp "dcm${i}_esp.cube"  "esp-dcm${i}.cube"
done
```

Check:

```bash
ls -lh dcm.cube esp-dcm.cube \
       dcm1.cube esp-dcm1.cube \
       dcm2.cube esp-dcm2.cube \
       dcm3.cube esp-dcm3.cube \
       dcm4.cube esp-dcm4.cube
```

These names match the current configuration of `ref_prepare.sh`.

---

# 12. Return to the top-level DCM directory

From:

```text
master/gaussian/
```

return to:

```text
/cluster/home/chaton/MDCM-project-pantelis/organic_molecules/ref/dcm
```

for example:

```bash
cd ../..
```

Check:

```bash
pwd
```

The result should be:

```text
/cluster/home/chaton/MDCM-project-pantelis/organic_molecules/ref/dcm
```

---

# 13. Configure `ref_prepare.sh`

Before running, check the user configuration section.

For DCM:

```bash
MASTER_DIR="./master/gaussian"

MOL_NAME="conf"

N_ATOMS=5

REF_DENSITY="dcm.cube"
REF_ESP="esp-dcm.cube"

N_CONFORMERS=4
```

The conformer density files should be:

```bash
CONFORMER_DENSITY=(
    "dcm1.cube"
    "dcm2.cube"
    "dcm3.cube"
    "dcm4.cube"
)
```

The conformer ESP files should be:

```bash
CONFORMER_ESP=(
    "esp-dcm1.cube"
    "esp-dcm2.cube"
    "esp-dcm3.cube"
    "esp-dcm4.cube"
)
```

For testing, the script may use:

```bash
OUTDIR="./single_test"
```

For the final production data, set:

```bash
OUTDIR="./single"
```

if `single/` is the desired final output directory.

---

# 14. Run the final reference preparation

From the top-level `dcm/` directory:

```bash
./ref_prepare.sh
```

The script checks:

```text
MASTER_DIR
N_ATOMS
N_CONFORMERS
density file list
ESP file list
duplicate filenames
optimized/reference cubes
all conformer cubes
```

It then prepares the optimized/reference files as:

```text
d_opt.cube
e_opt.cube
```

and the four conformers as:

```text
d_conf1.cube
e_conf1.cube

d_conf2.cube
e_conf2.cube

d_conf3.cube
e_conf3.cube

d_conf4.cube
e_conf4.cube
```

inside the configured output directory.

---

# 15. Local-frame generation

`ref_prepare.sh` automatically calls:

```bash
python3 get_frame.py \
    "$OPT_DENSITY_OUT" \
    "$RESNAME" \
    "$N_ATOMS"
```

Only the optimized/reference density cube is used to determine molecular connectivity and construct the local frames.

`get_frame.py` internally calls Open Babel:

```bash
obabel -icube <cube_file> -osdf
```

which is why `openbabel`/`obabel` must be installed in `xtb_env`.

The script validates the atom count and connectivity before constructing the frames.

For DCM:

```text
N_ATOMS=5
```

The generated local-frame definition is written to:

```text
frames.txt
```

in the top-level `dcm/` directory.

---

# 16. Final expected directory structure

After the complete workflow:

```text
dcm/
├── README.md
├── ref_prepare.sh
├── get_frame.py
├── fix_cube.pl
├── frames.txt
│
├── single/
│   ├── d_opt.cube
│   ├── e_opt.cube
│   ├── d_conf1.cube
│   ├── e_conf1.cube
│   ├── d_conf2.cube
│   ├── e_conf2.cube
│   ├── d_conf3.cube
│   ├── e_conf3.cube
│   ├── d_conf4.cube
│   └── e_conf4.cube
│
└── master/
    ├── gaussian/
    │   ├── dcm.cube
    │   ├── esp-dcm.cube
    │   ├── dcm1.cube
    │   ├── esp-dcm1.cube
    │   ├── dcm2.cube
    │   ├── esp-dcm2.cube
    │   ├── dcm3.cube
    │   ├── esp-dcm3.cube
    │   ├── dcm4.cube
    │   ├── esp-dcm4.cube
    │   └── Gaussian calculation files
    │
    └── data_prep/
        ├── dcm.xyz
        ├── dcm1.xyz
        ├── dcm2.xyz
        ├── dcm3.xyz
        ├── dcm4.xyz
        ├── dcm_xtb_md/
        ├── selected_frames.dat
        ├── selected_pairwise_rmsd.dat
        ├── xtb.sh
        ├── select_4_rmsd.py
        ├── create.sh
        ├── submit.sh
        ├── gaussian.slurm
        ├── cube.sh
        └── gaussian/
```

---

# Complete command sequence

For an existing installation, the normal sequence is:

```bash
# Activate environment
conda activate xtb_env

# Go to data preparation directory
cd /cluster/home/chaton/MDCM-project-pantelis/organic_molecules/ref/dcm/master/data_prep

# 1. xTB MD
./xtb.sh dcm.xyz

# 2. RMSD selection
python select_4_rmsd.py dcm_xtb_md/xtb.trj

# 3. Create Gaussian inputs
./create.sh

# 4. Enter Gaussian directory
cd gaussian

# 5. Submit Gaussian calculations
./submit.sh

# 6. Monitor jobs
squeue -u $USER

# 7. Verify completion
grep "Normal termination" *.out

# 8. Generate cubes
./cube.sh

# 9. Return to data_prep
cd ..

# 10. Copy completed Gaussian data to master/gaussian
# Archive/remove an older ../gaussian first if necessary.
cp -a gaussian ../gaussian

# 11. Enter the final Gaussian reference directory
cd ../gaussian

# 12. Create filenames expected by ref_prepare.sh
cp dcm_dens.cube dcm.cube
cp dcm_esp.cube  esp-dcm.cube

for i in 1 2 3 4; do
    cp "dcm${i}_dens.cube" "dcm${i}.cube"
    cp "dcm${i}_esp.cube"  "esp-dcm${i}.cube"
done

# 13. Return to DCM root
cd ../..

# 14. Prepare final cubes and local frames
./ref_prepare.sh
```

The final products required for the subsequent MDCM workflow are the prepared cube files in:

```text
single/
```

together with:

```text
frames.txt
```


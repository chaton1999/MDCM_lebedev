# MDCM Lebedev

DCM example workflow for MDCM fitting with sparse ESP grids based on
Lebedev-inspired angular sampling.

## Layout

```text
MDCM_lebedev/
├── bin_sym/
├── templates/
├── ref/
│   └── dcm/
│       └── single/
│           ├── e_*.cube
│           ├── d_*.cube
│           ├── frames.txt
│           ├── n1 ... n6
│           └── resp_lebedev_14/26/38/50
├── run/
│   └── dcm/
├── create.sh
├── create.cluster-original.sh
└── submit_dcm.sh
```

## Prepare the run

```bash
./create.sh
```

The repository copy of `create.sh` is configured for DCM and uses paths relative
to the repository root.

## Submit

Run Steps 0-3:

```bash
./submit_dcm.sh
```

Dry run:

```bash
./submit_dcm.sh --dry-run
```

Only Step 3:

```bash
./submit_dcm.sh --only-step3
```

Only selected Lebedev variants:

```bash
STEP3_VARIANTS="ml50 sl50" ./submit_dcm.sh --only-step3
```

Skip completed stages:

```bash
./submit_dcm.sh --skip 0,1,2
```

The default Step-3 variants are:

```text
ml14 ml26 ml38 ml50 sl14 sl26 sl38 sl50
```

The submission helper uses fixed waits between major stages because the Step-2
and Step-3 scripts themselves submit child Slurm jobs. These waits are not strict
dependencies. Always check the queue:

```bash
squeue -u "$USER"
```

## Notes

- `create.cluster-original.sh` preserves the original cluster copy.
- `create.sh` is the portable repository version.
- `templates/` is included because `create.sh` requires it.
- Cluster-specific partitions, exclusions, and binaries may need adjustment on
  another machine.

## Large cube files

The reference cube files can be large. Git LFS is recommended for `*.cube` files.
The repository includes a `.gitattributes` entry for them.

```bash
git lfs install
git lfs track "*.cube"
git init
git add .
git commit -m "Initial MDCM Lebedev DCM workflow"
```

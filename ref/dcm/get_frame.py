#!/usr/bin/env python3
# by khamlek

# ============================================================
# Automatically define local DCM frames from a Gaussian cube
#
# Usage:
#
#   python3 get_frame.py cube_file RESNAME N_ATOMS
#
# Example:
#
#   python3 get_frame.py master/dcm.cube DCM 5
#
# Output:
#
#   frames.txt
#
# Example format:
#
#   DCM
#   1    2    3      BO
#   4    2    1      BO
#
# ============================================================

import sys
import os
import subprocess


# ============================================================
# Usage
# ============================================================

def usage():
    print(
        "Usage: python3 get_frame.py "
        "<cube_file> <resname> <n_atoms>"
    )


if len(sys.argv) != 4:
    usage()
    sys.exit(1)


cube_file = sys.argv[1]
resname = sys.argv[2]

try:
    natm = int(sys.argv[3])
except ValueError:
    raise RuntimeError(
        "N_ATOMS must be an integer."
    )


if natm <= 0:
    raise RuntimeError(
        "N_ATOMS must be greater than zero."
    )


# ============================================================
# Check input cube
# ============================================================

if not os.path.isfile(cube_file):
    raise RuntimeError(
        "Cube file does not exist: {}".format(cube_file)
    )


print()
print("============================================================")
print(" Local frame generation")
print("============================================================")
print("Cube file       :", cube_file)
print("Residue         :", resname)
print("Declared atoms  :", natm)
print()


# ============================================================
# Double-check number of atoms from cube header
# ============================================================
#
# Gaussian cube:
#
# line 1 : comment
# line 2 : comment
# line 3 : NATOM origin_x origin_y origin_z
#
# ============================================================

try:

    with open(cube_file, "r") as fin:

        fin.readline()
        fin.readline()

        third_line = fin.readline().split()

        if len(third_line) < 4:
            raise RuntimeError(
                "Could not read atom count from cube header."
            )

        cube_natm = abs(int(third_line[0]))

except Exception as exc:

    raise RuntimeError(
        "Failed to read cube header from {}: {}".format(
            cube_file,
            exc
        )
    )


print("Atoms in cube    :", cube_natm)


if cube_natm != natm:

    raise RuntimeError(
        "\nAtom-count mismatch:\n"
        "  N_ATOMS in prepare.sh : {}\n"
        "  atoms in cube file     : {}\n".format(
            natm,
            cube_natm
        )
    )


if natm < 3:

    raise RuntimeError(
        "At least 3 atoms are required to define a frame."
    )


print("Atom-count check : OK")


# ============================================================
# Convert CUBE -> SDF using Open Babel
# ============================================================

sdf_file = "babel.sdf"
err_file = "babel.err"


print()
print("Running Open Babel:")
print(
    "obabel -icube {} -osdf".format(cube_file)
)
print()


with open(sdf_file, "w") as sdf_out, \
     open(err_file, "w") as err_out:

    result = subprocess.run(
        [
            "obabel",
            "-icube",
            cube_file,
            "-osdf"
        ],
        stdout=sdf_out,
        stderr=err_out
    )


if result.returncode != 0:

    raise RuntimeError(
        "Open Babel failed. Check {}".format(err_file)
    )


if (
    not os.path.isfile(sdf_file)
    or os.path.getsize(sdf_file) == 0
):

    raise RuntimeError(
        "Open Babel did not generate a valid {}".format(
            sdf_file
        )
    )


# ============================================================
# Read SDF
# ============================================================

with open(sdf_file, "r") as sdf:
    lines = sdf.readlines()


if len(lines) < 4:

    raise RuntimeError(
        "{} is too short to be a valid SDF file.".format(
            sdf_file
        )
    )


# ============================================================
# Read counts line
# ============================================================

counts = lines[3].split()


if len(counts) < 2:

    raise RuntimeError(
        "Could not read atom/bond counts from {}".format(
            sdf_file
        )
    )


try:

    sdf_natm = int(counts[0])
    nbond = int(counts[1])

except ValueError:

    raise RuntimeError(
        "Invalid SDF counts line:\n{}".format(
            lines[3].rstrip()
        )
    )


print()
print("Open Babel atoms :", sdf_natm)
print("Open Babel bonds :", nbond)


# ============================================================
# Check atom count again
# ============================================================

if sdf_natm != natm:

    raise RuntimeError(
        "\nAtom-count mismatch after Open Babel:\n"
        "  N_ATOMS     : {}\n"
        "  Open Babel  : {}\n".format(
            natm,
            sdf_natm
        )
    )


if nbond == 0:

    raise RuntimeError(
        "Open Babel detected zero bonds."
    )


# ============================================================
# Read bond block
# ============================================================

bond_start = 4 + natm
bond_end = bond_start + nbond

bonds = []


for line_number in range(
    bond_start,
    bond_end
):

    if line_number >= len(lines):

        raise RuntimeError(
            "Unexpected end of SDF while reading bonds."
        )


    fields = lines[line_number].split()


    if len(fields) < 3:

        raise RuntimeError(
            "Invalid bond line:\n{}".format(
                lines[line_number].rstrip()
            )
        )


    atom1 = int(fields[0])
    atom2 = int(fields[1])

    bonds.append(
        [atom1, atom2]
    )


print()
print("Bonded pairs:")

for bond in bonds:
    print(
        "  {} - {}".format(
            bond[0],
            bond[1]
        )
    )


# ============================================================
# Construct neighbor list
# ============================================================

stoich = []
neighbor = []


for i in range(natm):

    stoich.append(0)
    neighbor.append([])

    for j in range(nbond):

        if bonds[j][0] == i + 1:

            stoich[i] += 1

            neighbor[i].append(
                bonds[j][1]
            )

        elif bonds[j][1] == i + 1:

            stoich[i] += 1

            neighbor[i].append(
                bonds[j][0]
            )


# ============================================================
# Check every atom has a bonded neighbor
# ============================================================

inmol = []
inframe = []


for i in range(natm):

    if stoich[i] == 0:

        raise RuntimeError(
            "No bonded neighbors detected for atom {}".format(
                i + 1
            )
        )

    inmol.append(0)
    inframe.append(0)


# ============================================================
# Check connectivity
# ============================================================

def check_connectivity(atm):

    inmol[atm] = 1

    for i in range(stoich[atm]):

        connected_atom = (
            neighbor[atm][i] - 1
        )

        if inmol[connected_atom] == 0:

            check_connectivity(
                connected_atom
            )


inmol[0] = 1

check_connectivity(0)


for i in range(natm):

    if inmol[i] == 0:

        raise RuntimeError(
            "Atom {} is not connected to the molecule.".format(
                i + 1
            )
        )


# ============================================================
# Generate frames
# ============================================================

frames = []


# ============================================================
# First terminal atoms
# ============================================================

for i in range(natm):

    tframe = []

    at2 = -1
    at3 = -1


    if (
        stoich[i] == 1
        and inframe[i] == 0
    ):

        # First atom
        tframe.append(i + 1)

        inframe[i] = 1


        # Second atom
        tframe.append(
            neighbor[i][0]
        )

        at2 = (
            neighbor[i][0] - 1
        )

        inframe[at2] = 1


        # Try unused neighbor
        for j in range(
            stoich[at2]
        ):

            candidate = (
                neighbor[at2][j] - 1
            )

            if inframe[candidate] == 0:

                at3 = candidate

                tframe.append(
                    at3 + 1
                )

                inframe[at3] = 1

                break


        # Otherwise use existing neighbor
        if len(tframe) != 3:

            for j in range(
                stoich[at2]
            ):

                candidate = (
                    neighbor[at2][j] - 1
                )

                if candidate != i:

                    at3 = candidate

                    tframe.append(
                        at3 + 1
                    )

                    break


        if len(tframe) != 3:

            raise RuntimeError(
                "Could not complete frame {}".format(
                    tframe
                )
            )


        frames.append(
            tframe
        )


# ============================================================
# Remaining non-terminal atoms
# ============================================================

for i in range(natm):

    tframe = []

    at2 = -1
    at3 = -1


    if inframe[i] == 0:

        # First atom
        tframe.append(
            i + 1
        )

        inframe[i] = 1


        # Try unused bonded neighbor
        for j in range(
            stoich[i]
        ):

            candidate = (
                neighbor[i][j] - 1
            )

            if inframe[candidate] == 0:

                at2 = candidate

                tframe.append(
                    at2 + 1
                )

                inframe[at2] = 1

                break


        # Otherwise any bonded neighbor
        if at2 == -1:

            at2 = (
                neighbor[i][0] - 1
            )

            tframe.append(
                at2 + 1
            )


        # Third atom
        for j in range(
            stoich[at2]
        ):

            candidate = (
                neighbor[at2][j] - 1
            )

            if inframe[candidate] == 0:

                at3 = candidate

                tframe.append(
                    at3 + 1
                )

                inframe[at3] = 1

                break


        # Otherwise another neighbor
        if len(tframe) != 3:

            for j in range(
                stoich[i]
            ):

                candidate = (
                    neighbor[i][j] - 1
                )

                if candidate != at2:

                    at3 = candidate

                    tframe.append(
                        at3 + 1
                    )

                    break


        if len(tframe) != 3:

            raise RuntimeError(
                "Could not complete frame {}".format(
                    tframe
                )
            )


        frames.append(
            tframe
        )


# ============================================================
# Write frames.txt
# ============================================================
#
# Requested format:
#
# DCM
# 1    2    3      BO
# 4    2    1      BO
#
# There are two spaces before BO.
#
# ============================================================

output_file = "frames.txt"


with open(output_file, "w") as fr:

    fr.write(
        resname + "\n"
    )

    for frame in frames:

        fr.write(
            "%-4i %-4i %-4i  BO\n"
            % (
                frame[0],
                frame[1],
                frame[2]
            )
        )


# ============================================================
# Print generated frames
# ============================================================

print()
print("============================================================")
print(" Frames generated")
print("============================================================")
print()


for frame in frames:

    print(
        "%-4i %-4i %-4i  BO"
        % (
            frame[0],
            frame[1],
            frame[2]
        )
    )


print()
print(
    "{} has been written.".format(
        output_file
    )
)
print()

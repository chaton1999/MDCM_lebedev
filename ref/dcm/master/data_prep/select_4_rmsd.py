#!/usr/bin/env python3

import argparse
from pathlib import Path
import numpy as np


# ============================================================
# XYZ trajectory reader
# ============================================================

def read_xyz_trajectory(filename):

    filename = Path(filename)

    with open(filename, "r") as f:
        lines = f.readlines()

    frames = []
    comments = []
    symbols_ref = None

    i = 0

    while i < len(lines):

        # Skip empty lines
        if not lines[i].strip():
            i += 1
            continue

        try:
            natoms = int(lines[i].strip())
        except ValueError:
            raise RuntimeError(
                f"Could not read atom count at line {i + 1} "
                f"in {filename}"
            )

        if i + 1 >= len(lines):
            break

        comment = lines[i + 1].rstrip()

        symbols = []
        coords = []

        for j in range(natoms):

            line_index = i + 2 + j

            if line_index >= len(lines):
                raise RuntimeError(
                    f"Incomplete XYZ frame in {filename}"
                )

            fields = lines[line_index].split()

            if len(fields) < 4:
                raise RuntimeError(
                    f"Bad coordinate line:\n"
                    f"{lines[line_index]}"
                )

            symbols.append(fields[0])

            coords.append([
                float(fields[1]),
                float(fields[2]),
                float(fields[3])
            ])

        if symbols_ref is None:
            symbols_ref = symbols

        elif symbols != symbols_ref:
            raise RuntimeError(
                "Atom ordering/species changed between frames."
            )

        frames.append(
            np.array(coords, dtype=float)
        )

        comments.append(comment)

        i += natoms + 2

    if len(frames) == 0:
        raise RuntimeError(
            f"No XYZ frames found in {filename}"
        )

    return (
        symbols_ref,
        np.array(frames),
        comments
    )


# ============================================================
# Kabsch-aligned RMSD
# ============================================================

def kabsch_rmsd(P, Q, atom_indices=None):

    if atom_indices is not None:
        P = P[atom_indices]
        Q = Q[atom_indices]

    # Remove translation
    P0 = P - P.mean(axis=0)
    Q0 = Q - Q.mean(axis=0)

    # Covariance matrix
    H = P0.T @ Q0

    U, S, Vt = np.linalg.svd(H)

    # Rotation
    R = U @ Vt

    # Prevent improper reflection
    if np.linalg.det(R) < 0:

        U[:, -1] *= -1

        R = U @ Vt

    P_aligned = P0 @ R

    diff = P_aligned - Q0

    rmsd = np.sqrt(
        np.mean(
            np.sum(
                diff * diff,
                axis=1
            )
        )
    )

    return rmsd


# ============================================================
# Select maximally diverse structures
# ============================================================

def select_diverse_frames(
        frames,
        nselect=4,
        atom_indices=None):

    nframes = len(frames)

    if nframes < nselect:

        raise RuntimeError(
            f"Trajectory contains only {nframes} frames, "
            f"but {nselect} structures were requested."
        )

    # ========================================================
    # Reference = first MD frame
    # ========================================================

    reference = frames[0]

    print()
    print("Calculating RMSD from starting structure...")

    rmsd_reference = np.array([
        kabsch_rmsd(
            frame,
            reference,
            atom_indices
        )
        for frame in frames
    ])

    # ========================================================
    # First selected structure:
    # structure furthest from starting geometry
    # ========================================================

    first = int(
        np.argmax(rmsd_reference)
    )

    selected = [first]

    print(
        f"Selected 1: frame {first:6d}   "
        f"RMSD(reference) = "
        f"{rmsd_reference[first]:.6f} Å"
    )

    # ========================================================
    # Distance from every frame to first selected frame
    # ========================================================

    min_distance = np.array([
        kabsch_rmsd(
            frame,
            frames[first],
            atom_indices
        )
        for frame in frames
    ])

    min_distance[first] = -np.inf

    # ========================================================
    # Farthest-point / maximin selection
    # ========================================================

    while len(selected) < nselect:

        next_frame = int(
            np.argmax(min_distance)
        )

        diversity = (
            min_distance[next_frame]
        )

        selected.append(
            next_frame
        )

        print(
            f"Selected {len(selected)}: "
            f"frame {next_frame:6d}   "
            f"RMSD(reference) = "
            f"{rmsd_reference[next_frame]:.6f} Å   "
            f"minimum RMSD to selected = "
            f"{diversity:.6f} Å"
        )

        # RMSD from every frame to
        # newly selected structure
        new_distance = np.array([
            kabsch_rmsd(
                frame,
                frames[next_frame],
                atom_indices
            )
            for frame in frames
        ])

        # Keep distance to nearest selected structure
        min_distance = np.minimum(
            min_distance,
            new_distance
        )

        # Prevent re-selection
        for idx in selected:
            min_distance[idx] = -np.inf

    return (
        selected,
        rmsd_reference
    )


# ============================================================
# Write XYZ
# ============================================================

def write_xyz(
        filename,
        symbols,
        coords,
        comment):

    with open(filename, "w") as f:

        f.write(
            f"{len(symbols)}\n"
        )

        f.write(
            comment + "\n"
        )

        for symbol, xyz in zip(
                symbols,
                coords):

            f.write(
                f"{symbol:<2s} "
                f"{xyz[0]:16.10f} "
                f"{xyz[1]:16.10f} "
                f"{xyz[2]:16.10f}\n"
            )


# ============================================================
# Pairwise RMSD table
# ============================================================

def print_pairwise_table(
        selected,
        frames,
        atom_indices=None):

    n = len(selected)

    matrix = np.zeros(
        (n, n)
    )

    for i in range(n):

        for j in range(
                i + 1,
                n):

            value = kabsch_rmsd(
                frames[selected[i]],
                frames[selected[j]],
                atom_indices
            )

            matrix[i, j] = value
            matrix[j, i] = value

    print()
    print(
        "Pairwise RMSD between selected structures [Å]"
    )

    print(
        "------------------------------------------------"
    )

    print(
        "          " +
        "".join(
            f"dcm{i+1:>8d}  "
            for i in range(n)
        )
    )

    for i in range(n):

        print(
            f"dcm{i+1:<7d}",
            end=""
        )

        for j in range(n):

            print(
                f"{matrix[i,j]:10.5f}  ",
                end=""
            )

        print()

    return matrix


# ============================================================
# Process trajectory
# ============================================================

def process_trajectory(
        trajectory,
        nselect,
        heavy_only,
        prefix):

    trajectory = Path(
        trajectory
    )

    print()
    print("=" * 70)
    print(
        f"Trajectory : {trajectory}"
    )
    print("=" * 70)

    symbols, frames, comments = (
        read_xyz_trajectory(
            trajectory
        )
    )

    print(
        f"Frames     : {len(frames)}"
    )

    print(
        f"Atoms      : {len(symbols)}"
    )

    # ========================================================
    # Atom selection
    # ========================================================

    if heavy_only:

        atom_indices = np.array([
            i
            for i, s in enumerate(symbols)
            if s.upper() != "H"
        ])

        print(
            f"RMSD atoms : heavy atoms only "
            f"({len(atom_indices)} atoms)"
        )

    else:

        atom_indices = None

        print(
            f"RMSD atoms : all atoms "
            f"({len(symbols)} atoms)"
        )

    # ========================================================
    # Select structures
    # ========================================================

    selected, rmsd_reference = (
        select_diverse_frames(
            frames,
            nselect=nselect,
            atom_indices=atom_indices
        )
    )

    # ========================================================
    # Output directory
    #
    # We run this script from data_prep,
    # so selected XYZ files are written here.
    # ========================================================

    output_dir = Path.cwd()

    # ========================================================
    # Write selected structures
    # ========================================================

    print()
    print("Writing selected structures:")
    print()

    for rank, frame_index in enumerate(
            selected,
            start=1):

        output_file = (
            output_dir /
            f"{prefix}{rank}.xyz"
        )

        comment = (
            f"Selected from {trajectory.name}; "
            f"frame={frame_index}; "
            f"RMSD_from_initial="
            f"{rmsd_reference[frame_index]:.6f} Angstrom"
        )

        write_xyz(
            output_file,
            symbols,
            frames[frame_index],
            comment
        )

        print(
            f"  {output_file.name:<12s} "
            f"<- frame {frame_index}"
        )

    # ========================================================
    # Pairwise RMSD
    # ========================================================

    matrix = print_pairwise_table(
        selected,
        frames,
        atom_indices
    )

    # ========================================================
    # Save RMSD matrix
    # ========================================================

    matrix_file = (
        output_dir /
        "selected_pairwise_rmsd.dat"
    )

    np.savetxt(
        matrix_file,
        matrix,
        fmt="%12.6f"
    )

    # ========================================================
    # Save selected frame information
    # ========================================================

    info_file = (
        output_dir /
        "selected_frames.dat"
    )

    with open(
            info_file,
            "w") as f:

        f.write(
            "# rank frame "
            "RMSD_from_initial_Angstrom\n"
        )

        for rank, frame_index in enumerate(
                selected,
                start=1):

            f.write(
                f"{rank:4d} "
                f"{frame_index:8d} "
                f"{rmsd_reference[frame_index]:14.6f}\n"
            )

    print()
    print(
        f"RMSD matrix : {matrix_file.name}"
    )

    print(
        f"Frame info  : {info_file.name}"
    )

    print()
    print("=" * 70)
    print("RMSD selection finished")
    print("=" * 70)


# ============================================================
# Main
# ============================================================

def main():

    parser = argparse.ArgumentParser(
        description=(
            "Select maximally diverse structures "
            "from an xTB XYZ trajectory using "
            "Kabsch-aligned RMSD."
        )
    )

    parser.add_argument(
        "trajectory",
        help=(
            "xTB trajectory, for example "
            "dcm_xtb_md/xtb.trj"
        )
    )

    parser.add_argument(
        "-n",
        "--number",
        type=int,
        default=4,
        help=(
            "Number of structures "
            "to select (default: 4)"
        )
    )

    parser.add_argument(
        "-p",
        "--prefix",
        default="dcm",
        help=(
            "Output XYZ prefix "
            "(default: dcm)"
        )
    )

    parser.add_argument(
        "--heavy-only",
        action="store_true",
        help=(
            "Calculate RMSD using "
            "only non-H atoms"
        )
    )

    args = parser.parse_args()

    process_trajectory(
        args.trajectory,
        args.number,
        args.heavy_only,
        args.prefix
    )


if __name__ == "__main__":
    main()

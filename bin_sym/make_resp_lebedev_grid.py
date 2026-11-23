#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Generate an MSK/RESP-like radial grid with Lebedev angular sampling
and project the selected points onto an existing Gaussian cube lattice.

The original ESP cube is copied unchanged.

The output "density" cube is actually a Boolean selection mask:

    1.0 = selected ESP point
    0.0 = rejected ESP point

This mask is intended for pcubefit/main.f90 with the -respgrid option.

Construction
------------
For atom a, shell k and Lebedev direction j:

    r_akj = R_a + s_k * RvdW_a * u_j

where

    s_k = 1.4, 1.6, 1.8, 2.0

and u_j is a Lebedev unit vector.

Buried points are removed using vdW-scaled interatomic distances.
The surviving ideal points are then projected onto the nearest
Cartesian point of the supplied cube grid.

Supported Lebedev grids
-----------------------
14
26
38
50

The grid size itself should normally be selected in Step 0, e.g.

    LEBEDEV_POINTS=50

which is passed to this script using:

    --lebedev "$LEBEDEV_POINTS"
"""

import argparse
import itertools
import math
import shutil
from pathlib import Path

import numpy as np


# ============================================================
# CONSTANTS
# ============================================================

BOHR_TO_ANG = 0.52917721067
ANG_TO_BOHR = 1.0 / BOHR_TO_ANG


# ============================================================
# van der Waals radii in Angstrom
#
# Keep these consistent with pcubefit/main.f90.
# ============================================================

VDW_ANG = {
    1:  1.20,   # H
    6:  1.70,   # C
    7:  1.55,   # N
    8:  1.52,   # O
    9:  1.47,   # F
    15: 1.80,   # P
    16: 1.80,   # S
    17: 1.75,   # Cl
    35: 1.85,   # Br
    53: 1.98,   # I
}


# ============================================================
# MSK / RESP radial shells
# ============================================================

SHELLS = (
    1.4,
    1.6,
    1.8,
    2.0,
)


# ============================================================
# Boolean mask values
#
# main.f90 -respgrid should use something equivalent to:
#
#     selected = (rtmp > 0.5)
#
# Therefore:
#
#     1.0 = selected
#     0.0 = rejected
# ============================================================

MASK_ON = 1.0
MASK_OFF = 0.0


# ============================================================
# SUPPORTED LEBEDEV GRIDS
# ============================================================

SUPPORTED_LEBEDEV = (
    14,
    26,
    38,
    50,
)


# ============================================================
# LEBEDEV SYMMETRY-ORBIT HELPERS
# ============================================================

def add_axis_points(points):
    """
    Add the 6 Cartesian-axis directions:

        (+/-1, 0, 0)
        (0, +/-1, 0)
        (0, 0, +/-1)
    """

    for axis in range(3):

        for sign in (-1.0, 1.0):

            p = np.zeros(3, dtype=float)

            p[axis] = sign

            points.append(p)


def add_edge_points(points):
    """
    Add the 12 symmetry-related directions of type:

        (+/-a, +/-a, 0)

    including coordinate permutations, where

        a = 1/sqrt(2)
    """

    a = 1.0 / math.sqrt(2.0)

    for zero_axis in range(3):

        other = [
            i for i in range(3)
            if i != zero_axis
        ]

        for s1 in (-1.0, 1.0):

            for s2 in (-1.0, 1.0):

                p = np.zeros(3, dtype=float)

                p[other[0]] = s1 * a
                p[other[1]] = s2 * a

                points.append(p)


def add_cube_corner_points(points):
    """
    Add the 8 directions:

        (+/-a, +/-a, +/-a)

    where

        a = 1/sqrt(3)
    """

    a = 1.0 / math.sqrt(3.0)

    for sx, sy, sz in itertools.product(
        (-1.0, 1.0),
        repeat=3,
    ):

        points.append(
            np.array(
                [
                    sx * a,
                    sy * a,
                    sz * a,
                ],
                dtype=float,
            )
        )


def add_aab_points(points, a):
    """
    Add the 24 symmetry-related points of type

        (+/-a, +/-a, +/-b)

    with all positions of b among x,y,z.

    Normalization gives

        2*a^2 + b^2 = 1

    therefore

        b = sqrt(1 - 2*a^2)
    """

    b2 = 1.0 - 2.0 * a * a

    if b2 <= 0.0:
        raise ValueError(
            f"Invalid Lebedev parameter a={a}: "
            "1 - 2*a^2 must be positive."
        )

    b = math.sqrt(b2)

    # b may occupy x, y, or z
    for b_axis in range(3):

        other_axes = [
            i for i in range(3)
            if i != b_axis
        ]

        for s1 in (-1.0, 1.0):

            for s2 in (-1.0, 1.0):

                for sb in (-1.0, 1.0):

                    p = np.zeros(3, dtype=float)

                    p[other_axes[0]] = s1 * a
                    p[other_axes[1]] = s2 * a
                    p[b_axis] = sb * b

                    points.append(p)



# ============================================================
# LEBEDEV-14
# ============================================================

def lebedev_14():
    """
    14-point Lebedev angular grid.

    Orbit composition:
        6 Cartesian-axis directions
        8 cube-corner directions

    Total: 6 + 8 = 14

    Only directions are used for ESP sampling.
    """

    points = []

    add_axis_points(points)
    add_cube_corner_points(points)

    points = np.asarray(points, dtype=float)

    validate_lebedev_grid(
        points,
        expected_size=14,
        name="Lebedev-14",
    )

    return points


# ============================================================
# LEBEDEV-26
# ============================================================

def lebedev_26():
    """
    26-point Lebedev angular grid.

    Orbit composition:

        6  axis points
        12 edge points
        8  cube-corner points

    Total:

        6 + 12 + 8 = 26

    We use directions only; quadrature weights are not needed
    because these points are used as ESP fitting locations,
    not to evaluate a weighted spherical integral.
    """

    points = []

    add_axis_points(points)
    add_edge_points(points)
    add_cube_corner_points(points)

    points = np.asarray(
        points,
        dtype=float,
    )

    validate_lebedev_grid(
        points,
        expected_size=26,
        name="Lebedev-26",
    )

    return points

# ============================================================
# LEBEDEV-38
# ============================================================


def lebedev_38():
    import itertools
    import numpy as np

    points = []

    # 6 Cartesian-axis points
    for axis in range(3):
        for sign in (-1.0, 1.0):
            p = np.zeros(3)
            p[axis] = sign
            points.append(p)

    # 8 cube-corner points
    c = 1.0 / np.sqrt(3.0)

    for signs in itertools.product((-1.0, 1.0), repeat=3):
        points.append(np.array(signs) * c)

    # 24 points of the form (0, ±a, ±b)
    # Including permutations of a and b and of the zero axis
    a = np.sqrt((1.0 + 1.0 / np.sqrt(3.0)) / 2.0)
    b = np.sqrt((1.0 - 1.0 / np.sqrt(3.0)) / 2.0)

    for zero_axis in range(3):
        other = [i for i in range(3) if i != zero_axis]

        for u, v in ((a, b), (b, a)):
            for s1, s2 in itertools.product(
                (-1.0, 1.0), repeat=2
            ):
                p = np.zeros(3)
                p[other[0]] = s1 * u
                p[other[1]] = s2 * v
                points.append(p)

    points = np.asarray(points)

    assert points.shape == (38, 3)
    assert np.allclose(
        np.linalg.norm(points, axis=1), 1.0
    )
    assert np.unique(
        np.round(points, decimals=12), axis=0
    ).shape[0] == 38

    return points


# ============================================================
# LEBEDEV-50
# ============================================================

def lebedev_50():
    """
    50-point Lebedev angular grid.

    Orbit composition:

        6  axis points
        12 edge points
        8  cube-corner points
        24 additional (a,a,b)-type points

    Total:

        6 + 12 + 8 + 24 = 50
    """

    points = []

    add_axis_points(points)
    add_edge_points(points)
    add_cube_corner_points(points)

    # Parameter for the 24-point orbit.
    #
    # b follows automatically from
    #
    #     2*a^2 + b^2 = 1
    #
    a = 0.30151134457776363

    add_aab_points(
        points,
        a,
    )

    points = np.asarray(
        points,
        dtype=float,
    )

    validate_lebedev_grid(
        points,
        expected_size=50,
        name="Lebedev-50",
    )

    return points


# ============================================================
# LEBEDEV VALIDATION
# ============================================================

def validate_lebedev_grid(
    points,
    expected_size,
    name,
):
    """
    Basic safety checks for an angular grid.
    """

    if points.shape != (expected_size, 3):

        raise RuntimeError(
            f"{name} has incorrect shape "
            f"{points.shape}; expected "
            f"({expected_size}, 3)."
        )

    norms = np.linalg.norm(
        points,
        axis=1,
    )

    if not np.allclose(
        norms,
        1.0,
        atol=1.0e-12,
        rtol=1.0e-12,
    ):

        raise RuntimeError(
            f"{name} contains directions "
            "that are not normalized."
        )

    # Check for duplicate vectors
    rounded = np.round(
        points,
        decimals=12,
    )

    unique = np.unique(
        rounded,
        axis=0,
    )

    if len(unique) != expected_size:

        raise RuntimeError(
            f"{name} contains duplicate directions: "
            f"{len(unique)} unique points found, "
            f"expected {expected_size}."
        )


# ============================================================
# GRID SELECTOR
# ============================================================

def get_lebedev_grid(npoints):
    """
    Return the requested Lebedev angular grid.

    The Step-0 script controls npoints through --lebedev.
    """

    if npoints == 14:
        return lebedev_14()

    if npoints == 26:
        return lebedev_26()

    if npoints == 38:
        return lebedev_38()

    if npoints == 50:
        return lebedev_50()

    supported = ", ".join(
        str(x)
        for x in SUPPORTED_LEBEDEV
    )

    raise RuntimeError(
        f"Unsupported Lebedev grid: {npoints}. "
        f"Supported values are: {supported}"
    )


# ============================================================
# CUBE HEADER READER
# ============================================================

def read_cube_header(filename):
    """
    Read the structural/header information from a Gaussian cube.

    We do not need to load the scalar data here because:

      * ESP values remain in the original ESP cube.
      * the density cube is used only as a grid/header template.
    """

    filename = Path(filename)

    with filename.open("r") as f:

        comment1 = f.readline()
        comment2 = f.readline()

        if comment1 == "" or comment2 == "":
            raise RuntimeError(
                f"Cube file appears truncated: {filename}"
            )

        line = f.readline().split()

        if len(line) < 4:
            raise RuntimeError(
                f"Bad atom/origin line in cube: {filename}"
            )

        natom_signed = int(line[0])
        natom = abs(natom_signed)

        origin = np.array(
            list(map(float, line[1:4])),
            dtype=float,
        )

        ngrid_signed = []
        ngrid = []
        axes = []

        for _ in range(3):

            line = f.readline().split()

            if len(line) < 4:
                raise RuntimeError(
                    f"Bad grid-vector line in cube: "
                    f"{filename}"
                )

            n = int(line[0])

            ngrid_signed.append(n)
            ngrid.append(abs(n))

            axes.append(
                list(
                    map(
                        float,
                        line[1:4],
                    )
                )
            )

        atoms = []

        for _ in range(natom):

            line = f.readline().split()

            if len(line) < 5:
                raise RuntimeError(
                    f"Bad atom line in cube: {filename}"
                )

            Z = int(float(line[0]))

            nuclear_charge = float(
                line[1]
            )

            pos = np.array(
                list(
                    map(
                        float,
                        line[2:5],
                    )
                ),
                dtype=float,
            )

            atoms.append(
                (
                    Z,
                    nuclear_charge,
                    pos,
                )
            )

    # Standard cube convention used by your files:
    #
    # positive voxel counts -> Bohr
    # negative voxel counts -> Angstrom
    #
    if all(
        n > 0
        for n in ngrid_signed
    ):

        unit = "bohr"

    elif all(
        n < 0
        for n in ngrid_signed
    ):

        unit = "angstrom"

    else:

        raise RuntimeError(
            "Mixed signs in cube grid dimensions "
            "are unsupported."
        )

    return {
        "comment1": comment1,
        "comment2": comment2,

        "natom_signed": natom_signed,
        "natom": natom,

        "origin": origin,

        "ngrid_signed": np.array(
            ngrid_signed,
            dtype=int,
        ),

        "ngrid": np.array(
            ngrid,
            dtype=int,
        ),

        "axes": np.array(
            axes,
            dtype=float,
        ),

        "atoms": atoms,

        "unit": unit,
    }


# ============================================================
# VALIDATE ESP AND DENSITY CUBES
# ============================================================

def validate_same_grid(
    esp_cube,
    density_cube,
):
    """
    Ensure that ESP and density cubes describe the same
    Cartesian lattice and molecular geometry.
    """

    if esp_cube["natom"] != density_cube["natom"]:

        raise RuntimeError(
            "ESP and density cubes have different "
            "numbers of atoms."
        )

    if esp_cube["unit"] != density_cube["unit"]:

        raise RuntimeError(
            "ESP and density cubes use different units."
        )

    if not np.array_equal(
        esp_cube["ngrid"],
        density_cube["ngrid"],
    ):

        raise RuntimeError(
            "ESP and density cubes have different "
            "grid dimensions."
        )

    if not np.allclose(
        esp_cube["origin"],
        density_cube["origin"],
        atol=1.0e-10,
        rtol=1.0e-10,
    ):

        raise RuntimeError(
            "ESP and density cubes have different "
            "grid origins."
        )

    if not np.allclose(
        esp_cube["axes"],
        density_cube["axes"],
        atol=1.0e-10,
        rtol=1.0e-10,
    ):

        raise RuntimeError(
            "ESP and density cubes have different "
            "grid vectors."
        )

    # Check atom identities and coordinates
    for i, (
        esp_atom,
        dens_atom,
    ) in enumerate(
        zip(
            esp_cube["atoms"],
            density_cube["atoms"],
        ),
        start=1,
    ):

        Z_esp = esp_atom[0]
        Z_den = dens_atom[0]

        pos_esp = esp_atom[2]
        pos_den = dens_atom[2]

        if Z_esp != Z_den:

            raise RuntimeError(
                f"ESP/density atomic-number mismatch "
                f"for atom {i}: "
                f"{Z_esp} vs {Z_den}"
            )

        if not np.allclose(
            pos_esp,
            pos_den,
            atol=1.0e-8,
            rtol=1.0e-8,
        ):

            raise RuntimeError(
                f"ESP/density coordinate mismatch "
                f"for atom {i}."
            )


# ============================================================
# van der Waals RADIUS CONVERSION
# ============================================================

def vdw_radius_in_cube_units(
    Z,
    unit,
):

    if Z not in VDW_ANG:

        raise RuntimeError(
            f"No vdW radius defined for "
            f"atomic number Z={Z}."
        )

    radius_ang = VDW_ANG[Z]

    if unit == "bohr":

        return (
            radius_ang
            * ANG_TO_BOHR
        )

    if unit == "angstrom":

        return radius_ang

    raise RuntimeError(
        f"Unknown cube unit: {unit}"
    )


# ============================================================
# CUBE GRID TRANSFORMATIONS
# ============================================================

def point_to_grid_index(
    point,
    origin,
    axes,
):
    """
    Find the nearest cube lattice index to an arbitrary point.

    Cube lattice:

        r(i,j,k) =
            origin
            + i*a1
            + j*a2
            + k*a3
    """

    delta = (
        point
        - origin
    )

    fractional_index = np.linalg.solve(
        axes.T,
        delta,
    )

    return np.rint(
        fractional_index
    ).astype(int)


def grid_index_to_point(
    index,
    origin,
    axes,
):
    """
    Convert integer cube indices back into Cartesian coordinates.
    """

    i, j, k = index

    return (
        origin
        + i * axes[0]
        + j * axes[1]
        + k * axes[2]
    )


# ============================================================
# MSK BURIED-POINT TEST
# ============================================================

def point_is_exposed(
    point,
    center_atom,
    atoms,
    unit,
):
    """
    Test whether an MSK/Lebedev point generated around
    center_atom is exposed.

    For the generating atom a:

        d_a = |r - R_a| / RvdW_a

    For every other atom b:

        d_b = |r - R_b| / RvdW_b

    Reject the point if:

        d_b < d_a

    for any other atom.
    """

    Za = atoms[
        center_atom
    ][0]

    Ra = atoms[
        center_atom
    ][2]

    rvdw_a = (
        vdw_radius_in_cube_units(
            Za,
            unit,
        )
    )

    center_scaled_distance = (
        np.linalg.norm(
            point - Ra
        )
        / rvdw_a
    )

    for b, (
        Zb,
        _,
        Rb,
    ) in enumerate(atoms):

        if b == center_atom:
            continue

        rvdw_b = (
            vdw_radius_in_cube_units(
                Zb,
                unit,
            )
        )

        other_scaled_distance = (
            np.linalg.norm(
                point - Rb
            )
            / rvdw_b
        )

        if (
            other_scaled_distance
            <
            center_scaled_distance
        ):

            return False

    return True


# ============================================================
# MASK CUBE WRITER
# ============================================================

def write_mask_cube(
    cube,
    mask,
    filename,
    lebedev_points,
):
    """
    Write a Gaussian-cube-format Boolean selection mask.

    1.0 = selected
    0.0 = rejected
    """

    nx, ny, nz = (
        cube["ngrid"]
    )

    filename = Path(filename)

    filename.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    with filename.open("w") as f:

        f.write(
            "MSK + Lebedev ESP-selection mask\n"
        )

        f.write(
            f"Lebedev={lebedev_points}; "
            "1.0=selected; 0.0=rejected\n"
        )

        origin = cube["origin"]

        f.write(
            f"{cube['natom_signed']:5d}"
            f"{origin[0]:13.6f}"
            f"{origin[1]:13.6f}"
            f"{origin[2]:13.6f}\n"
        )

        for n, vec in zip(
            cube["ngrid_signed"],
            cube["axes"],
        ):

            f.write(
                f"{n:5d}"
                f"{vec[0]:13.6f}"
                f"{vec[1]:13.6f}"
                f"{vec[2]:13.6f}\n"
            )

        for (
            Z,
            charge,
            pos,
        ) in cube["atoms"]:

            f.write(
                f"{Z:5d}"
                f"{charge:13.6f}"
                f"{pos[0]:13.6f}"
                f"{pos[1]:13.6f}"
                f"{pos[2]:13.6f}\n"
            )

        # Gaussian cube ordering:
        #
        # i = outer
        # j = middle
        # k = inner
        #
        for i in range(nx):

            for j in range(ny):

                count = 0

                for k in range(nz):

                    f.write(
                        f"{mask[i,j,k]:13.5E}"
                    )

                    count += 1

                    if count == 6:

                        f.write("\n")

                        count = 0

                if count != 0:

                    f.write("\n")


# ============================================================
# XYZ DIAGNOSTIC WRITER
# ============================================================

def write_xyz(
    selected,
    cube,
    filename,
):
    """
    Write selected cube lattice points as dummy X atoms
    for visualization in VMD/ASE/etc.

    XYZ coordinates are always written in Angstrom.
    """

    filename = Path(filename)

    filename.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    coordinates = []

    for index in sorted(
        selected
    ):

        p = grid_index_to_point(
            np.array(
                index,
                dtype=int,
            ),
            cube["origin"],
            cube["axes"],
        )

        if cube["unit"] == "bohr":

            p = (
                p
                * BOHR_TO_ANG
            )

        coordinates.append(p)

    with filename.open("w") as f:

        f.write(
            f"{len(coordinates)}\n"
        )

        f.write(
            "Selected MSK/Lebedev ESP "
            "cube-lattice points\n"
        )

        for p in coordinates:

            f.write(
                "X "
                f"{p[0]:14.8f} "
                f"{p[1]:14.8f} "
                f"{p[2]:14.8f}\n"
            )


# ============================================================
# MAIN
# ============================================================

def main():

    parser = argparse.ArgumentParser(
        description=(
            "Generate an MSK/RESP-like radial grid "
            "with Lebedev angular sampling and "
            "project it onto an existing cube lattice."
        )
    )


    parser.add_argument(
        "--esp",
        required=True,
        help=(
            "Original QM ESP cube. "
            "Copied unchanged to --out-esp."
        ),
    )


    parser.add_argument(
        "--density",
        required=True,
        help=(
            "Original density cube used as the "
            "geometry/grid template."
        ),
    )


    parser.add_argument(
        "--out-esp",
        required=True,
        help=(
            "Output path for unchanged ESP cube."
        ),
    )


    parser.add_argument(
        "--out-density",
        required=True,
        help=(
            "Output path for Boolean RESP/Lebedev "
            "selection-mask cube."
        ),
    )


    parser.add_argument(
        "--xyz",
        required=True,
        help=(
            "Diagnostic XYZ containing selected "
            "cube-grid locations."
        ),
    )


    parser.add_argument(
        "--lebedev",
        type=int,
        default=50,
        help=(
            "Number of Lebedev angular points per "
            "radial shell. Supported: "
            + ", ".join(
                str(x)
                for x in SUPPORTED_LEBEDEV
            )
            + ". Default: 50."
        ),
    )


    args = parser.parse_args()


    # ========================================================
    # VALIDATE REQUESTED LEBEDEV GRID
    # ========================================================

    if (
        args.lebedev
        not in SUPPORTED_LEBEDEV
    ):

        supported = ", ".join(
            str(x)
            for x in SUPPORTED_LEBEDEV
        )

        raise RuntimeError(
            f"Unsupported Lebedev grid "
            f"{args.lebedev}. "
            f"Supported grids: {supported}"
        )


    # ========================================================
    # INPUT PATHS
    # ========================================================

    esp_path = Path(
        args.esp
    )

    density_path = Path(
        args.density
    )

    if not esp_path.is_file():

        raise FileNotFoundError(
            f"ESP cube not found: "
            f"{esp_path}"
        )

    if not density_path.is_file():

        raise FileNotFoundError(
            f"Density cube not found: "
            f"{density_path}"
        )


    # ========================================================
    # READ CUBE HEADERS
    # ========================================================

    esp_cube = read_cube_header(
        esp_path
    )

    density_cube = read_cube_header(
        density_path
    )


    validate_same_grid(
        esp_cube,
        density_cube,
    )


    # We use density cube merely as the output-grid template.
    cube = density_cube


    # ========================================================
    # GET REQUESTED LEBEDEV GRID
    # ========================================================

    directions = get_lebedev_grid(
        args.lebedev
    )


    nx, ny, nz = (
        cube["ngrid"]
    )


    # Set avoids duplicate cube voxels after projection.
    selected = set()


    # ========================================================
    # STATISTICS
    # ========================================================

    n_ideal = 0

    n_exposed_ideal = 0

    n_outside = 0

    n_projected_buried = 0

    n_projected_exposed = 0


    # ========================================================
    # GENERATE MSK + LEBEDEV POINTS
    # ========================================================

    for atom_index, (
        Z,
        _,
        center,
    ) in enumerate(
        cube["atoms"]
    ):

        rvdw = (
            vdw_radius_in_cube_units(
                Z,
                cube["unit"],
            )
        )

        for shell in SHELLS:

            radius = (
                shell
                * rvdw
            )

            for direction in directions:

                n_ideal += 1


                # --------------------------------------------
                # Exact ideal MSK/Lebedev position
                # --------------------------------------------

                ideal = (
                    center
                    + radius * direction
                )


                # --------------------------------------------
                # Remove buried ideal surface points
                # --------------------------------------------

                if not point_is_exposed(
                    ideal,
                    atom_index,
                    cube["atoms"],
                    cube["unit"],
                ):

                    continue


                n_exposed_ideal += 1


                # --------------------------------------------
                # Project onto nearest Cartesian cube voxel
                # --------------------------------------------

                index = point_to_grid_index(
                    ideal,
                    cube["origin"],
                    cube["axes"],
                )

                i, j, k = index


                # --------------------------------------------
                # Make sure projected point lies in cube
                # --------------------------------------------

                if not (
                    0 <= i < nx
                    and
                    0 <= j < ny
                    and
                    0 <= k < nz
                ):

                    n_outside += 1

                    continue


                # --------------------------------------------
                # Recover projected Cartesian coordinate
                # --------------------------------------------

                projected = (
                    grid_index_to_point(
                        index,
                        cube["origin"],
                        cube["axes"],
                    )
                )


                # --------------------------------------------
                # Projection can slightly move a point across
                # a molecular-surface boundary.
                #
                # Therefore run the buried-point criterion
                # again after projection.
                # --------------------------------------------

                if not point_is_exposed(
                    projected,
                    atom_index,
                    cube["atoms"],
                    cube["unit"],
                ):

                    n_projected_buried += 1

                    continue


                n_projected_exposed += 1


                selected.add(
                    (
                        int(i),
                        int(j),
                        int(k),
                    )
                )


    # ========================================================
    # SAFETY CHECK
    # ========================================================

    if len(selected) == 0:

        raise RuntimeError(
            "No MSK/Lebedev cube points survived "
            "selection. Refusing to write an empty mask."
        )


    # ========================================================
    # BUILD BOOLEAN MASK
    # ========================================================

    mask = np.full(
        (
            nx,
            ny,
            nz,
        ),
        MASK_OFF,
        dtype=float,
    )


    for (
        i,
        j,
        k,
    ) in selected:

        mask[
            i,
            j,
            k,
        ] = MASK_ON


    # ========================================================
    # CREATE OUTPUT DIRECTORIES
    # ========================================================

    out_esp = Path(
        args.out_esp
    )

    out_density = Path(
        args.out_density
    )

    out_xyz = Path(
        args.xyz
    )


    for output in (
        out_esp,
        out_density,
        out_xyz,
    ):

        output.parent.mkdir(
            parents=True,
            exist_ok=True,
        )


    # ========================================================
    # COPY ORIGINAL ESP UNCHANGED
    # ========================================================

    shutil.copy2(
        esp_path,
        out_esp,
    )


    # ========================================================
    # WRITE MASK
    # ========================================================

    write_mask_cube(
        cube,
        mask,
        out_density,
        args.lebedev,
    )


    # ========================================================
    # WRITE DIAGNOSTIC XYZ
    # ========================================================

    write_xyz(
        selected,
        cube,
        out_xyz,
    )


    # ========================================================
    # SUMMARY
    # ========================================================

    theoretical_max = (
        cube["natom"]
        * len(SHELLS)
        * len(directions)
    )


    print()
    print(
        "============================================================"
    )
    print(
        "MSK + LEBEDEV GRID"
    )
    print(
        "============================================================"
    )

    print(
        f"ESP input              : {esp_path}"
    )

    print(
        f"Grid template          : {density_path}"
    )

    print(
        f"Cube units             : {cube['unit']}"
    )

    print()

    print(
        f"Atoms                  : {cube['natom']}"
    )

    print(
        f"Radial shells          : "
        + " ".join(
            str(x)
            for x in SHELLS
        )
    )

    print(
        f"Lebedev points/shell   : "
        f"{len(directions)}"
    )

    print(
        f"Maximum candidates     : "
        f"{theoretical_max}"
    )

    print()

    print(
        f"Ideal candidates       : "
        f"{n_ideal}"
    )

    print(
        f"Exposed ideal          : "
        f"{n_exposed_ideal}"
    )

    print(
        f"Outside cube           : "
        f"{n_outside}"
    )

    print(
        f"Buried after projection: "
        f"{n_projected_buried}"
    )

    print(
        f"Exposed projected      : "
        f"{n_projected_exposed}"
    )

    print(
        f"Unique cube points     : "
        f"{len(selected)}"
    )

    print()

    print(
        f"ESP output             : {out_esp}"
    )

    print(
        f"Mask output            : {out_density}"
    )

    print(
        f"XYZ diagnostic         : {out_xyz}"
    )

    print(
        "============================================================"
    )

    print()


# ============================================================
# ENTRY POINT
# ============================================================

if __name__ == "__main__":
    main()

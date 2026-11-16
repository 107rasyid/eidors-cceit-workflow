# FEMM cross-solver check of B6

This isolated workflow builds a FEMM **Current Flow** model from the saved B6
Netgen boundary geometry. It reuses the B6 exterior and medium/ring interface
polylines and electrode IDs from `elmer_validation/B6_hmed2.00mm_hring0.35mm/B6_mesh_reference.mat`.
FEMM/Triangle creates a new interior triangulation, so this is not the identical
EIDORS element mesh. The target local sizes are read from B6 metadata (currently
2.00 mm in the medium and 0.35 mm in the ring).

## Setup

Install FEMM 4.2 for Windows, Python, and the packages `pyfemm`, `numpy`, and
`scipy` in the same Python environment. pyFEMM communicates with the FEMM
application; it does not replace the solver. The model uses FEMM's Current Flow
problem type, not Electrostatics.

## Run

From PowerShell in the project root, first solve one pair to inspect the setup:

```powershell
py -m pip install pyfemm numpy scipy
py femm_validation\run_b6_femm.py --tx 1 --rx 9
```

The script opens FEMM, saves `femm_validation/results/B6_FEMM_current_flow.fec`,
solves the selected pair, and writes `B6_FEMM_pair_check.csv`. If the result and
reported voltage/current checks look sensible, run all 120 unordered pairs:

```powershell
py femm_validation\run_b6_femm.py --all
```

The solve also creates `B6_FEMM_current_flow.anc`, FEMM's current-flow result
file. Add `--show-solver` to the one-pair command if you need FEMM's solver
console visible. The full scan writes `femm_validation/results/B6_FEMM_120_pairs.csv`
and flushes each row as it completes. Do not run multiple copies of the script
against the same FEMM instance simultaneously.

## Model and comparison limits

- Geometry and materials come from the saved B6 MAT: core radius 53 mm,
  explicit 2 mm dielectric ring, 16 electrode arcs, 500 kHz, and 1 m depth.
- Medium: 0.025 S/m and relative permittivity 80. Ring: 0 S/m and relative
  permittivity 3.
- Mesh-size targets come from the reference MAT; FEMM's Triangle mesh has
  different element connectivity and generally a different element count.
- Each transmitter is fixed at 1 V, the receiver at 0 V, and all other
  electrode conductors have prescribed total current 0 (floating). The script
  records conductor currents, normalized current imbalance, floating current,
  and terminal-voltage deviation.
- FEMM conductor terminals are ideal equipotential contacts. EIDORS B6 includes
  `z_el=0.01 Ohm.m`, so the contact condition is not exactly identical. Treat
  this as an explicit limitation when interpreting differences.
- FEMM's 2D planar current is computed for the configured 1 m depth, matching
  the EIDORS per-unit-depth convention numerically.

This folder is optional and does not change the EIDORS workflow or its results.

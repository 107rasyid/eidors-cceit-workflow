# Maxwell 2D validation of B6

This isolated workflow builds an explicit-layer, 16-electrode CCEIT case in
Maxwell 2D AC Conduction, solves its terminal admittance matrix, and reduces
that matrix to the 120 voltage-driven/current-sense pair measurements. It does
not modify the EIDORS models or results.

## Reference setup

The values follow the active EIDORS B6 reference:

- 16 electrodes; medium radius 53 mm; explicit ring thickness 2 mm
- electrode arc width 18 mm at the outer radius (55 mm)
- 2D model depth 1 m; drive frequency 500 kHz; pair voltage difference 1 V
- medium: conductivity 0.025 S/m, relative permittivity 80
- ring: conductivity set to a numerical floor of `1e-12 S/m`, relative
  permittivity 3 (the target EIDORS value is 0 S/m)
- EIDORS outer contact impedance: 0.01 Ohm.m

The script approximates the small outer contact impedance with a 0.1 mm
resistive contact sector of conductivity 0.01 S/m, which gives
thickness/conductivity = 0.01 Ohm.m. Maxwell creates its own mesh, so its
elements are not the identical Netgen B6 elements. The 2D depth is set to 1 m
so total terminal currents correspond to current per metre of depth.
The tiny ring conductivity floor is negligible relative to its displacement
admittivity at 500 kHz, but it is recorded as a small physical-model difference.
For the AEDT Student license, the script uses very coarse polygon arcs (4
segments per electrode, 1 per gap) and one adaptive pass to target the 2D
triangle cap. This discretization is only a feasibility run, not a
mesh-converged cross-solver validation.

## Run from the Maxwell GUI

1. Launch Ansys Electronics Desktop v252.
2. Choose **File > New** to create a blank project. Do not add a design; the
   script inserts the Maxwell 2D AC Conduction design.
3. Choose **Tools > Run Script**, then select
   `ansys_validation/run_b6_maxwell.py`. Use a fresh blank project for each
   retry; a failed run may already have inserted the design and geometry.
4. Wait for the solve and matrix export to finish. The script saves the project
   and matrix under `ansys_validation/results/`.
5. From PowerShell at the repository root, reduce the exported matrix to the
   120 pair admittances:

   ```powershell
   py .\ansys_validation\export_ymatrix_csv.py
   ```

Run the script once per fresh blank project. The CLI gRPC route is not used:
   this installed AEDT build returns `UNIMPLEMENTED` for its project open/create
   endpoints.

## Outputs

Files are written to `ansys_validation/results/`:

- `B6_Maxwell_ACConduction.aedt`: Maxwell project
- `B6_Maxwell_G_uS.csv`, `B6_Maxwell_C_pF.csv`: 15-by-15 grounded matrix
  reports with electrode 16 as reference
- `B6_Maxwell_Yre_uS.csv`, `B6_Maxwell_Yim_uS.csv`: direct complex-Y reports
  (alternative inputs to the postprocessor)
- `B6_Maxwell_pairs_120.csv`: 120 acquisition-order rows with only `Yreal`,
  `Yim`, `abs_Y`, and `phase` (admittance values are S per m depth; phase is
  degrees)
- `maxwell_console.log`: AEDT run log

The postprocessor reconstructs the 16-terminal matrix using current
conservation and Kron-reduces the 14 unselected electrodes for each pair.
Pair order is `(1,2), (1,3), ..., (1,16), (2,3), ...`.

The postprocessor reads the 15-by-15 G/C reports (or direct Re(Y)/Im(Y)
reports), reconstructs the 16-terminal matrix using current conservation, then
Kron-reduces the 14 unselected electrodes for each pair. Its default input path
is `ansys_validation/results/`, even when launched from the repository root.
If Maxwell's real-conductance report is all zero, the exporter preserves zero
and warns; it cannot recover conductive loss from the capacitance report alone.

## Validation status and limits

The scripts have **not completed a Maxwell solve**. The matrix assignment
structure has been corrected. The first solve hit the AEDT Student 2D mesh cap
at 9,400 surface elements; coarsening reduced it to 4,156, still above the
documented 2,000-triangle cap. The script now uses very coarse arcs and one
adaptive pass; the resulting field, if it runs, is only a feasibility check.
It cannot support quantitative cross-solver validation.
Then compare at least TX 1 / RX 9 against EIDORS B6 at `h_ring=0.35 mm` before
interpreting the 120-pair sweep. Check phase sign convention as well as
magnitude: solvers can use opposite complex phasor conventions. Maxwell uses
its own adaptive mesh, and the thin resistive contact approximation is not an
identical implementation of EIDORS CEM. Therefore this workflow is a
cross-solver comparison candidate, not yet a successful validation result.

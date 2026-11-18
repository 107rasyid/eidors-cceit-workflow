# This still doesn't work
# Elmer FEM validation: B6 mesh export

This folder prepares the explicit-layer EIDORS Model B6 mesh for an independent
Elmer FEM forward-solver comparison. It calls the existing `cceit_mesh_B6`
function, so Netgen creates the geometry and the exported nodes and triangles
are reused directly. No second meshing or Gmsh step is involved.

## Generate the shared mesh

From GNU Octave, with the current directory set to `CCEIT_forward`:

```octave
setup_paths
run('elmer_validation/export_B6_mesh_for_elmer.m')
```

The exporter uses the current `cceit_params.m` values, including
`P.h_int_B6` and `P.h_ring_B6_coarse` (currently 2.00 mm and 0.35 mm). It writes
to a resolution-named folder under `elmer_validation/` (with current settings:
`B6_hmed2.00mm_hring0.35mm/`). This step creates mesh and metadata files only;
it does not run a forward scan or start Elmer.

## Exported files

- `mesh.header`, `mesh.nodes`, `mesh.elements`, `mesh.boundary`: Elmer text mesh.
- `region_materials.csv`: body IDs, conductivity, relative permittivity, and
  complex admittivity at the configured frequency.
- `boundary_ids.csv`: boundary IDs, segment counts, and configured electrode
  contact impedance.
- `simulation_parameters.csv`: frequency, drive voltage, geometry, depth, and
  contact impedance.
- `B6_mesh_reference.mat`: full EIDORS `fmdl_B6`, ring mask, parameters, and
  exported IDs/connectivity for later same-mesh checks.

Body IDs are 1 for the medium and 2 for the dielectric ring. Boundary IDs are
1 for the outer wall, 2 for the medium/ring interface, and 11 through 26 for
electrodes 1 through 16. B6 also has `z_el` on the electrodes in addition to
the explicit dielectric ring; preserve that contact condition in the Elmer
model. Bulk triangles use Elmer type 303 and line boundaries use type 202.
Coordinates are in metres, with `z=0`.

## End-to-end tutorial: Elmer to 120 pair responses

Use the generated `mesh.*` files directly. Do not send them through another
mesher. The current exported mesh has 6,433 nodes, 11,872 triangles (6,451
medium and 5,421 ring), and 1,301 boundary segments. The configured case is
500 kHz, 1 V, 1 m model depth, and `z_el=0.01 Ohm.m` on every electrode. The
dielectric ring remains explicit **and** the electrode contact impedance is
retained, as in EIDORS B6.

### 1. Restore a clean Elmer case

The ElmerGUI project must be kept separate from the exported reference folder.
The reference mesh is preserved in `B6_hmed2.00mm_hring0.35mm/B6_mesh_reference.mat`.
If ElmerGUI has overwritten the flat `mesh.*` export files, restore the exact
saved mesh (without rerunning Netgen) from Octave at the project root:

```octave
setup_paths
run('elmer_validation/restore_elmer_case_from_mat.m')
```

This creates `elmer_validation/elmer_case/mesh/mesh.*` and copies the basis-1
input from `case_basis01_template.sif` to `elmer_validation/elmer_case/case.sif`.
The SIF uses `Mesh DB "." "mesh"`, which points to that `mesh/` subfolder.
Do not make the original export folder the ElmerGUI project directory.

### 2. Open the mesh and run it in ElmerGUI

`case.sif` is plain text, not MATLAB or Octave code. It defines the forward
physics and boundary conditions; ElmerGUI loads the mesh, launches the solver,
and displays its log.

In ElmerGUI:

1. Start **ElmerGUI** from the Windows Start menu.
2. Choose **File → New project...**. Set the project directory to
   `elmer_validation/elmer_case` and select its `mesh` subfolder as the Elmer
   mesh directory. This loads the four restored `mesh.*` files.
3. Choose **Sif → Edit...**. Replace the editor contents with the full text of
   `elmer_validation/elmer_case/case.sif`, then save it in the project
   directory. This is the first solve: electrode 1 is at 1 V and electrodes
   2–16 are at 0 V through the Robin contact condition.
4. Choose **Run → Start solver**. The solver log appears in ElmerGUI; generated
   files, including `phi_boundary.dat`, are written to the project directory.

The SIF is also a regular file, so it can be edited in Notepad or VS Code.
ElmerGUI is the program that starts `ElmerSolver` and shows its log; the SIF
contains the actual physics and boundary conditions. The GUI menu names above
follow the ElmerGUI manual. Do not choose **Mesh → Remesh**.

### 3. Harmonic material problem

`case.sif` already contains the complete setup below, including all 16 Robin
electrodes. It uses Elmer's `StatCurrentSolve` with harmonic mode enabled.
Material properties and frequency match the exported CSV files:

```text
Simulation
  Coordinate System = "Cartesian 2D"
  Simulation Type = Steady State
  Steady State Max Iterations = 1
  Angular Frequency = 3141592.65358979
End

Constants
  Permittivity of Vacuum = 8.8541878128e-12
End

Solver 1
  Exec Solver = Always
  Equation = "Stat Current"
  Procedure = "StatCurrentSolve" "StatCurrentSolver"
  Variable = Potential
  Variable DOFs = 1
  Harmonic Mode = Logical True
  Linear System Solver = Direct
  Linear System Direct Method = UMFPACK
  Calculate Volume Current = Logical True
  Calculate Joule Heating = Logical False
End

Material 1
  Electric Conductivity = Real 0.025
  Relative Permittivity = Real 80
End

Material 2
  Electric Conductivity = Real 0
  Relative Permittivity = Real 3
End
```

Keep `Variable DOFs = 1` with `Harmonic Mode = Logical True`. The harmonic
system forms its real/imaginary unknown pair internally; setting two field
DOFs here creates an unintended extra pair and can make the solve singular.

Assign body 1 to material 1 and body 2 to material 2. For example:

```text
Equation 1
  Name = "Stat Current"
  Active Solvers(1) = 1
End

Body 1
  Target Bodies(1) = 1
  Equation = 1
  Material = 1
End

Body 2
  Target Bodies(1) = 2
  Equation = 1
  Material = 2
End
```

The harmonic current
solver combines conductivity and relative permittivity using `Angular
Frequency`; do not enter the already-complex gamma values from the CSV as
conductivity. The expected admittivities at this baseline are
`0.025 + j*0.002225300110895741 S/m` in the medium and
`j*8.344875415859028e-5 S/m` in the ring.

### 4. Define the electrodes as CEM Robin contacts

Leave the non-electrode outer boundary (ID 1) insulated by its natural zero
flux condition. Do not add a condition at the medium/ring interface (ID 2):
the conforming mesh already enforces continuity there. On each electrode
boundary ID 11 through 26, use the Robin contact condition with
`External Conductivity = 100` (because `1/z_el = 100 1/(Ohm.m)`) and a constant
`External Potential`. Do **not** set the mesh-boundary `Potential` directly;
that would remove the finite contact impedance from the CEM. The current Elmer
solver assembles its Robin term as `C*(Potential - External Potential)`, which
is the contact law needed here.

For each solve, the SaveScalars solver writes boundary integrals of the real
and imaginary potential on each electrode. The file uses `Potential Re` and
`Potential Im` with `Operator = "boundary int"`; each electrode condition sets
`Save Scalars = Logical True`.

```text
Boundary Condition 11
  Name = "Electrode 1"
  Target Boundaries(1) = 11
  External Conductivity = Real 100
  External Potential = Real 1
  Save Scalars = Logical True
End
```

For basis solve 2, change only electrode 2 (boundary ID 12) to
`External Potential = Real 1`; set electrode 1 back to 0 V. Continue this
one-at-a-time change through basis solve 16. Save each run's output under a
distinct name or copy its `phi_boundary.dat` before starting the next run, so
the next run does not overwrite it.
There is no Dirichlet `Potential` assignment on these electrode boundaries.
Check the generated `.names` file to associate each saved integral with IDs 11
through 26.

The SaveScalars solver block is:

```text
Solver 2
  Exec Solver = After All
  Equation = "SaveScalars"
  Procedure = "SaveData" "SaveScalars"
  Filename = "phi_boundary.dat"
  Variable 1 = "Potential Re"
  Operator 1 = "boundary int"
  Variable 2 = "Potential Im"
  Operator 2 = "boundary int"
End
```

### 5. Run 16 unit-voltage basis solves

Make 16 copies of the SIF. In basis solve `b`, set the `External Potential` to
1 V on electrode `b`, and 0 V on the other 15 electrodes. All 16 electrodes
remain Robin contacts in every solve. Run `ElmerSolver case_b.sif` once for
each basis. These solves form the complex port admittance matrix `Yport`:
column `b` is the electrode-current vector produced by the basis voltage on
electrode `b`.

For each solve, let `S[a,b] = integral(Potential) ds` on electrode `a` and
`L[a]` be that electrode's boundary length. Compute the port current as

```text
I[a,b] = (U_basis[a,b]*L[a] - S[a,b])/z_el
Yport[a,b] = I[a,b] / 1 V
```

Here `U_basis` is
1 V at electrode `b` and 0 V elsewhere. For the imaginary part, the imposed
basis voltage has zero imaginary part, so `Im(I[a,b]) = -Im(S[a,b])/z_el`.
Use line lengths in metres and keep currents/admittances per metre of model
depth. This integral uses the Robin contact current, not a guessed current
from the bulk field near an electrode edge.

Before continuing, check that `Yport` is complex-symmetric
(`Yport ≈ transpose(Yport)`), its row sums are near zero, and its diagonal real
parts are nonnegative. If these fail, stop and inspect the harmonic SIF,
boundary IDs, SaveScalars column names, and current sign convention.

### 6. Reduce the port matrix to the 120 voltage-driven measurements

For each acquisition pair `tx < rx`, set `U(tx)=1 V`, `U(rx)=0 V`, and solve
the remaining 14 electrode potentials from the zero-current floating
condition:

```text
F = all electrodes except tx and rx
U(F) = -Yport(F,F) \ Yport(F,tx)
I = Yport * U
Ypair(tx,rx) = I(tx) / 1 V
```

This produces the same drive/virtual-ground/floating-port condition as the
EIDORS scan for a linear model, using 16 FEM solves instead of 120. Save one
CSV row for every pair in acquisition order: `(1,2)..(1,16),(2,3)..(15,16)`.
Include `tx`, `rx`, real/imaginary current, magnitude, phase, and pair
admittance. With `Vtx=1 V`, the complex transmitter current and pair admittance
have the same numerical value, with units A/m and S/m respectively.

### 7. Convert the port matrix to the 120-row CSV

Enter the real and imaginary parts of `Yport` into two numeric 16-by-16 CSV
files named `Yport_re.csv` and `Yport_im.csv`, with rows as current electrodes
and columns as basis-voltage electrodes. Keep these files in the exported mesh
folder. Then in Octave, from `CCEIT_forward`, run:

```octave
setup_paths
P = cceit_params();
export_dir = fullfile(P.project_root, 'elmer_validation', ...
    'B6_hmed2.00mm_hring0.35mm');
Yport = dlmread(fullfile(export_dir, 'Yport_re.csv'), ',') + ...
        1i*dlmread(fullfile(export_dir, 'Yport_im.csv'), ',');
assert(isequal(size(Yport), [16 16]));
pairs = cceit_pair_list(16);
fid = fopen(fullfile(export_dir, 'elmer_120_pairs.csv'), 'w');
fprintf(fid, 'pair_index,tx,rx,I_re_A_per_m,I_im_A_per_m,I_abs_A_per_m,I_phase_deg,Y_re_S_per_m,Y_im_S_per_m,dcc,dfloat\n');
for k = 1:size(pairs,1)
    tx = pairs(k,1); rx = pairs(k,2);
    floating = setdiff(1:16, [tx rx]);
    U = zeros(16,1);
    U(tx) = P.Vtx;
    U(floating) = -(Yport(floating,floating) \ ...
        (Yport(floating,tx)*P.Vtx));
    I = Yport*U;
    It = I(tx);
    Ypair = It/P.Vtx;
    dcc = abs(sum(I))/abs(It);
    dfloat = max(abs(I(floating)))/abs(It);
    fprintf(fid, '%d,%d,%d,%.16g,%.16g,%.16g,%.12g,%.16g,%.16g,%.6g,%.6g\n', ...
        k,tx,rx,real(It),imag(It),abs(It),angle(It)*180/pi, ...
        real(Ypair),imag(Ypair),dcc,dfloat);
end
fclose(fid);
fprintf('Saved %d acquisition-ordered pairs: %s\n', size(pairs,1), ...
    fullfile(export_dir, 'elmer_120_pairs.csv'));
```

This uses the same acquisition order as `cceit_pair_list`: `(1,2)` through
`(1,16)`, then `(2,3)` through `(15,16)`. `I_re_A_per_m` and
`I_im_A_per_m` are the requested 120 complex current responses; with 1 V drive,
their numerical values also equal the real and imaginary pair-admittance
values in S/m.

### 8. Verify against the matching EIDORS mesh

Compare Elmer to `B6_mesh_reference.mat`, not to a newly rebuilt mesh or an old
run whose Netgen connectivity may differ. Compare all 120 complex pair values
using relative vector error, maximum per-pair relative error, magnitude, and
phase. Also check `sum(I)`, the 14 floating currents, the prescribed terminal
voltages, and reciprocity. A mismatch in phase sign can indicate a different
harmonic time convention; confirm it with Elmer's `e^(+j*omega*t)` convention
before comparing complex values. The recorded B6 response scale is roughly
0.4 mA/m at 1 V, which is only a sanity check, not a pass criterion.

The SIF has been written but has not yet been run or tested on this
workstation. First run basis 1 in ElmerGUI and inspect `phi_boundary.dat` and
its names/metadata output. Confirm the 16 integrals are present before
repeating the 15 remaining basis solves.

The text mesh layout follows Appendix A of the
[ElmerSolver Manual](https://ftp.csc.fi/index/files/Historical/pub/index/elmer/doc/ElmerSolverManual.pdf).

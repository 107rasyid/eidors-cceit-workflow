# Progress

## Paper workflow

The paper goals are (1) verify EIDORS voltage-driven/current-sense operation,
(2) compare lumped contact impedance A3 with explicit-layer B6, and (3) study
frequency/layer/medium sensitivity in Model A. Goal 2 is partially supported:
the tested `delta_layer` values are about 7.9–8.5%, above the former 5% target.
Do not tune A3 to B6 and claim independent equivalence.

The active forward workflow is manual and goal-by-goal. `run_all.m` is archived;
the optional reconstruction demo is separate and does not change the paper workflow.

## Elmer FEM validation scaffold

- Added `elmer_validation/export_B6_mesh_for_elmer.m` to rebuild the explicit
  B6 mesh through the existing Netgen/EIDORS function and export Elmer-native
  mesh files, body/boundary maps, and the original EIDORS model for comparison.
- The exporter uses shared parameters and currently targets the B6 coarse
  reference (`h_int_B6=2 mm`, `h_ring_B6_coarse=0.35 mm`). `setup_paths.m` adds
  the exporter folder to the Octave path.
- This is mesh generation only. Elmer harmonic material laws, Robin electrode
  contacts, floating-electrode constraints, current extraction, and numerical
  comparison are documented in `elmer_validation/README.md` as a 16-basis-run
  route to all 120 pair responses. Added a complete `case.sif` for basis 1
  (electrode 1 at 1 V; all other electrode ports at 0 V through Robin
  contacts) and GUI run instructions. The SIF has not been run or tested; no
  Elmer solve was performed.
- Kept a master copy at `elmer_validation/case_basis01_template.sif` because
  ElmerGUI may regenerate or overwrite the project `case.sif` when editing or
  saving the project. Restore the run copy from this template if needed.
- ElmerGUI was pointed at the export folder itself and overwrote its flat
  `mesh.*` files with an empty mesh. The reference MAT remains the source of
  truth. Added `restore_elmer_case_from_mat.m` to reconstruct the exact saved
  mesh records into an isolated `elmer_validation/elmer_case/mesh/` folder
  (without re-running Netgen), and copy the basis-1 SIF into the isolated case.
  The SIF now uses `Mesh DB "." "mesh"` for this folder layout. The reported
  `External Conductivity` warnings are not the stopping error: `StatCurrentSolve`
  registers that Robin-boundary keyword dynamically. Recovery has not yet been
  run; the mesh files must be restored before the next solver attempt.
- The first loaded-mesh solve reached assembly but returned NaN. The SIF had
  `Variable DOFs = 2` together with `Harmonic Mode = True`; corrected all case
  copies to one scalar DOF so the harmonic system can form the real/imaginary
  pair internally. This correction has not yet been rerun.
- The next harmonic run ended but solved the trivial zero field; `SaveScalars`
  also requested a nonexistent `Potential Re` variable. Added
  `elmer_case/case_dirichlet_check.sif` as a diagnostic-only case: fixed 1 V on
  electrode 1 and 0 V on the others, preserving mesh/materials/frequency, to
  isolate solver and electrode-tag behavior from the Robin CEM condition. It
  has not been run and is not a validation result.

## Maxwell validation scaffold

- Added `ansys_validation/` for a separate Maxwell 2D AC Conduction comparison
  of explicit-layer B6. Reference parameters and saved geometry are available
  under the Elmer B6 export folder.
- The workstation's ANSYS Student v252 installation contains
  `AnsysEM/ansysedtng.exe`. Maxwell supports command-line scripting and AC
  conduction admittance matrices; a reduced terminal matrix can represent the
  zero-current constraints on unselected electrodes.
- Added `ansys_validation/run_b6_maxwell.ps1`, the embedded AEDT model script
  `run_b6_maxwell.py`, and standard-Python postprocessor
  `export_ymatrix_csv.py`.
  The model constructs a 16-electrode explicit-ring approximation, sets depth
  to 1 m, assigns a thin resistive contact sector, and exports a grounded
  15-port Y matrix. The postprocessor reconstructs the 16-terminal matrix and
  reduces it to the 120 pair responses with the other 14 electrodes at zero
  net current.
- The one-command workflow is documented in `ansys_validation/README.md`.
  Maxwell remeshes the geometry, so it will not share Netgen element
  connectivity; the thin contact sector only approximates EIDORS CEM. The AEDT
  geometry, matrix export, postprocessor parsing, and one-pair numerical
  comparison have not been run. This is an implementation candidate, not a
  completed cross-solver validation.
- The PowerShell launcher stops if the current run does not create/update the
  Y-matrix file, instead of passing a missing or stale file to postprocessing.
- A GUI run created the geometry but failed when assigning `B6_YMatrix`:
  AC Conduction requires `MatrixEntry` and `GroundSources` directly under the
  matrix name. The prior `GCMatrix` wrapper caused Maxwell to ignore the ground
  source. Corrected the array structure in `run_b6_maxwell.py`; this fix still
  needs a fresh-project GUI run. Older `SetActiveProjectByPath` messages in the
  AEDT message pane are from earlier attempts; the current script uses the
  active GUI project.
- The next GUI run passed matrix setup but hit the AEDT Student 2D mesh cap at
  9,400 surface elements. Coarsening to 8/2 segments reduced it to 4,156,
  still over the documented 2,000-triangle limit. Reduced the exploratory
  script further to 4/1 segments and one adaptive pass. This very coarse attempt
  has not been run and, even if it solves, is only a feasibility check rather
  than quantitative B6 validation.
- Inspected the newer GUI-generated Maxwell project and report CSVs. The AEDT
  project stores medium conductivity as 0.025 S/m and assigns that material to
  the medium disk, but both exported `G_uS` and `Re(Y)_uS` matrices contain 225
  exact zeros while the C and Im(Y) matrices are nonzero. Therefore the zero
  real pair values originate in Maxwell's solved/reported matrix, not in the
  pair reduction. The matrix result inside AEDT must be checked to distinguish
  solver assembly from report-expression behavior. This current script also
  uses a 1 mm, epsr=1.58 layer and a 1 mm contact region (sigma=0.1 S/m,
  epsr=10); this is not the original 2 mm B6 model or a purely real 0.01 Ohm.m
  contact, so phase differences are expected.
- Rewrote `ansys_validation/export_ymatrix_csv.py` to use the grounded 15-port
  Maxwell G/C reports, reconstruct and Kron-reduce the 16-port matrix, and
  export exactly four columns named `Yreal`, `Yim`, `abs_Y`, and `phase`, with
  rows in acquisition order.
  Removed the old sign-flip heuristic and added a warning when the source
  conductance matrix is identically zero. No Maxwell solve or postprocessor run
  was performed after this change.
- AEDT v252's `ansysedtng` JSON mode executes through a gRPC wrapper. It does
  not implement `RestoreWindow()` or `OpenProject()`, so those calls were
  removed. The wrapper's `InsertDesign` signature also differs from the legacy
  COM API: the script now inserts the design using the gRPC signature, then
  calls `SetSolutionType("AC Conduction", "XY")`. This path has not yet been
  rerun.
- Running the corrected path reached AEDT startup but failed because its
  configured `C:\Temp\ansoft` directory is read-only. The launcher now passes
  `TempDirectory` with AEDT's command-line batch option, pointing to the
  writable `ansys_validation/results/aedt_temp` directory.

## Active structure

- `core/`: parameters, A3/B6 meshes and solvers, pair scans, metadata.
- `scripts/`: verification, A3/B6 comparison and ring-resolution study, and
  Model A parameter sweeps.
- `plots/`: saved-result plots, pair-series plots, mesh display, sweep summary.
- `demo_reconstruction/`: helper functions for the optional 6-case demo.
- `results/`: clean output folder for the manual runs; an old locked report may
  remain until its viewer releases it.
- `arsip/manual_run_reset_20261104/`: prior results and archived `run_all.m`.
- `arsip/superseded_B4_workflow/`: scripts/functions tied to the superseded B4
  comparison workflow.

## Current numerical evidence

- Latest A3/B6 verification: A3 has 5,182 elements, `dcc=1.27e-12`, floating
  current ratio `5.75e-16`, zero voltage deviation, and reciprocity error
  `5.72e-13` on 30 pairs.
- Latest B6 verification uses 11,872 elements, including 5,421 ring elements;
  `dcc=8.45e-12`, floating current ratio `2.16e-12`, zero voltage deviation,
  and reciprocity error `6.48e-12` on 30 pairs.
- Latest A3/B6 `delta_layer` is 8.45% at `h_ring=0.35 mm`; finer checks report
  8.24%, 8.00%, and 7.90% at 0.25, 0.20, and 0.15 mm.

## Recent cleanup and demo status

- `run_all.m` is archived. Run the scripts one goal at a time, beginning with
  `run_verify_models`; inspect its MAT and console log before moving to Goal 2.
- Previous results were moved to `arsip/manual_run_reset_20261104/`; the old
  report remained locked by another process.
- `demo_reconstruction.m` is intended to execute three example inclusion
  layouts for A3 and coarse B6 through forward current, ideal TIA, complex transfer-impedance
  difference, and regularized complex-Jacobian reconstruction of real and
  imaginary admittivity changes. Its helper functions are in
  `demo_reconstruction/`. It has not been run in Octave; outputs are a workflow
  demonstration, not validated tissue reconstructions.
- No Octave code was run during this cleanup/demo implementation.

## 2026-11-04 sweep workflow fixes

- Fixed the frequency list construction in `run_sweepA.m` to append 500 kHz
  horizontally, preserving a row vector and preventing the 1x13 vs 1x1 mismatch.
- Aligned `run_sweepA3.m` result struct fields with the fields it actually
  writes. Old MAT files with a different field schema are ignored and rebuilt
  instead of being concatenated into an incompatible struct array.
- Updated `summary_sweeps.m` to compute frequency `Delta_p` relative to the
  configured baseline frequency and to read the current A3 field names.
- Updated `plot_results.m` to use the active `cceit_runA3_mesh` solver.
- `run_all.m` has been archived; run each goal manually. These edits were
  inspected statically; Octave was not run.

## Manual Goal 1/2 checkpoint

- Goal 1 verification completed on 2026-11-04: A3 has 5,182 elements and B6
  has 11,872 elements at `h_ring=0.35 mm`; current/voltage checks and 30-pair
  reciprocity errors are within the observed numerical tolerances. Its console
  log is `run_verify_models_console_20261104_141851.txt`.
- Goal 2 coarse A3/B6 comparison completed at 500 kHz, `h_medium=2 mm`, and
  `h_ring=0.35 mm`: `delta_layer=0.0844945`, median magnitude ratio 0.916203.
  The B6 resolution study is the next step. Removed automatic `best` legend
  placement from this comparison plot; regenerate after the resolution run if
  a refreshed coarse figure is needed.
- B6 resolution study completed at `h_ring=0.35/0.25/0.20/0.15 mm`, giving
  `delta_layer=8.449/8.242/8.000/7.896%`; differences remain above 5% and have
  not fully plateaued. `plot_B6_resolution_study.m` refreshes its figure from
  the MAT without rebuilding meshes.
- Updated the coarse A3/B6 runner to time mesh generation and the 120-pair
  scan separately for both models, saving the measurements to
  `AB_A3_B6_timing.csv`. The timing values require rerunning that coarse stage;
  the existing 0.35 mm result predates these timing fields.

## Goal 3 metric standardization

- `Delta_p` is now the primary measure in all sensitivity plots. Median
  magnitude and phase remain descriptive; ratio-`r` sensitivity plots and
  sweep outputs were removed. The A3 medium summary plot shows mean `Delta_p`
  over tested factors for each thickness/frequency condition.
- A2 perturbs one parameter at a time around the configured 500 kHz baseline;
  its layer-conductivity sweep is absolute because baseline conductivity is
  zero. A3 uses the same medium baseline, with separate fixed-thickness and
  frequency scenarios. With a lossless layer, thickness and layer permittivity
  are coupled in the lumped contact admittance and should not be described as
  independently identifiable.
- No Octave run was performed; regenerate sweep results and Goal 3 plots
  manually before using these updated outputs.

## Frequency and mesh sweep correction

- The first rerun of `run_sweepA` exposed a real mesh-study defect: it varied
  `P.h_int`/`P.h_el`, while `cceit_mesh_A3` built every mesh from fixed
  `P.h_int_A3`. All three reported 5,182 elements and zero change, so those
  mesh-convergence values are invalid. The frequency sweep from that run is
  independent of this defect.
- Added opt-in `mesh_h_int_A3` and `mesh_h_el_A3` overrides to
  `cceit_mesh_A3`; calls without overrides retain the prior production mesh
  settings. `run_sweepA` now passes its per-level mesh sizes explicitly and
  errors if fewer than two distinct mesh sizes are produced.
- Octave was not run. Rerun `run_sweepA` and confirm element counts differ and
  the coarse-to-fine `delta_mesh_A` values are nonzero before using them.

## 2026-11-04 plot layout cleanup

- Moved figure legends out of data regions in `plot_results.m`,
  `plot_sweepA2.m`, `plot_sweepA3_medium.m`, and `plot_mesh_AB.m`.
- Removed a free-floating mesh annotation that could overlay the convergence
  curve. No plot uses automatic `best` legend placement now.
- Static source inspection only; regenerate figures by running the plot scripts.

## Goal 3 layer sensitivity figure update

- Restored the direct `Delta_p` plots for thickness, permittivity, and
  conductivity. The three parameter curves now have connecting lines and the
  configured baseline is marked with a filled diamond.
- Static inspection only; regenerate the figure from the saved A2 MAT.

## Goal 3 figure selection and layout

- `plot_results.m` now generates only the retained Goal 3 figures from saved
  sweep results; it no longer computes the pair map, separation plot, or
  current-density field, and no longer rebuilds a mesh or repeats scans.
- Frequency response is one standalone plot. Layer response is one three-panel
  plot using direct `Delta_p` axes and connecting lines. Medium sensitivity is
  one 4-by-2 figure: four frequencies by conductivity and permittivity. It omits
  the baseline points (`Delta_p=0`) and uses one shared legend so perturbed
  responses are easier to compare.
- `summary_sweeps.m` now writes its table CSV/MAT only; frequency visualization
  comes from `plot_results.m`. Goal 2 plots remain available from their
  dedicated scripts.
- Removed the duplicate two-panel frequency PNG from `run_sweepA.m`; it now
  saves sweep data only, and `plot_results.m` creates the single retained
  frequency figure after the sweeps.
- Added `export_sweep_csv.m` to convert existing frequency, mesh, layer, and
  medium MAT results into tidy CSV tables without rerunning any simulations.
- Figure exporters use `PaperPositionMode='auto'` and larger canvas sizes to
  reduce cropped labels. The medium plot reserves space for a shared legend
  and panel spacing. Octave rendering was not run; inspect regenerated PNGs.
- Static source review only; regenerate PNGs from the existing sweep MAT files.

## Medium-sensitivity plot Octave legend fix

- Octave 11 raised an error while deleting a manually positioned legend during
  figure close, even though it had written the PNG. Replaced that shared legend
  with figure annotations in a reserved top strip to avoid the failing legend
  callback. Rerun `plot_results` to refresh the medium PNG; Octave was not run
  here.

## 2026-11-04 report schema fix

- Updated `generate_report.m` for the current sweep MAT schemas: frequency
  `Delta_p` is derived from `Yf` against the baseline frequency, A2 median
  fields use `median_abs`/`median_phase`, and A3 sensitivity uses
  `Delta_p_sig`/`Delta_p_eps`.
- Static inspection only; run `generate_report.m` manually to produce a fresh
  report.

## Reconstruction demo review and model update

- Added step-by-step comments to the demo driver and case helper, including
  phantom/model choices, the forward → ideal TIA → differential impedance →
  reconstruction flow, saved outputs, and illustrative-only limitations.
- Clarified that `plot_current_diff.m` redraws current plots from saved data and that generated
  files go under `results/reconstruction_demo/`; old archived outputs are not
  fresh-run inputs.
- Updated the demo from legacy A2/B5 builders to the active `cceit_mesh_A3` and
  `cceit_mesh_B6` functions; B6 uses `P.h_ring_B6_coarse`. Updated the model
  names in the optional current plots and README accordingly.
- Connected `plot_current_diff.m` to the end of the demo after it saves the
  status MAT. Each completed phantom/model case now gets a current plot with
  homogeneous and inclusion responses across the 120 pairs in acquisition
  order; the script can also redraw these plots from saved data alone.
- Demo reconstruction and current plots now open in the Octave GUI and remain
  open for editing/manual SVG export; PNG export is disabled for these plots.
- The prior undefined-function risk from legacy filenames is removed by these
  call-site changes. Octave was not run, so a fresh demo run is still needed to
  confirm the end-to-end reconstruction pipeline on A3/B6.

## Legacy current-solver NETGEN path fix

- `cceit_sim_v2_sebelumnya_masih_I_solver.m` now calls `setup_paths()` and reads
  the validated NETGEN folder through `cceit_params()` before adding it to
  `PATH`. It no longer depends on `CCEIT_NETGEN_BIN` already being set in the
  Octave process. The script was not run; verify it manually in a fresh session.

## Isolated Goal 2 interpretation diagnostics

- Added `diagnostics_goal2/check_electrode_arcs.m` to compare realized A3/B6
  electrode boundary arcs and node counts without solving the forward model.
- Added `diagnostics_goal2/run_thickness_trend.m` to compare A3/B6 `Delta_layer`
  at d=1, 2, 3, and 5 mm. It keeps the active B6 ring target up to 0.35 mm,
  reduces it to d/4 for thinner layers, catches failures per thickness, and
  stores diagnostic outputs under `results/goal2_diagnostics/`.
- These scripts do not alter the production workflow or its saved results.
  They have not been run in Octave.

## Reconstruction demo complex inverse correction

- Replaced independent inversions of the real and imaginary impedance data
  with a real-augmented system that jointly solves for conductivity change
  and imaginary-admittivity change using both quadratures of the complex
  Jacobian.
- The demo now converts imaginary admittivity change to relative-permittivity
  change and plots ground truth and reconstruction for both conductivity and
  relative permittivity on separate, unit-consistent scales. Ground-truth and
  estimate panels use independent color limits; the console reports peak
  estimate-to-ground-truth ratios to make under-recovery explicit.
- The existing ideal TIA forward conversion is unchanged. Octave was not run;
  regenerate the six reconstruction figures and inspect the recovered maps
  before using them as paper results.

## Goal 3 plots remain open in Octave GUI

- plot_results.m now opens Fig. 4a, 4b, and 4c visibly and leaves them open
  after saving their PNG copies. It no longer closes all existing figures at
  startup.
- Split the former layer-sensitivity triptych into thickness,
  permittivity, and conductivity figures, each saved as its own PNG and left
  open in the GUI.
- Replaced the medium figure's annotation-based shared legend with a small
  axes-based legend to avoid Octave annotation property errors.
- The medium-sensitivity output is now four frequency-specific figures, each
  with separate conductivity and permittivity panels; this avoids the crowded
  4-by-2 canvas and its overlapping titles. Filenames include the frequency.
- Octave was not run; use run_logged('plot_results') and export SVG from the
  open figure windows as needed.

## Elmer CEM solver diagnosis (2026-11-16)

- Confirmed from Elmer 26.1 `StatCurrentSolve.F90` that `StatCurrentSolver`
  assembles Robin electrode terms from `External Conductivity` and
  `External Potential`; a separate FEM solver plug-in is not inherently
  required for the CEM boundary law.
- Re-ran an isolated basis-1 case using a copy of the exact B6 mesh, tiny
  positive ring conductivity (`1e-12 S/m`), and legacy assembly. Elmer parsed
  the 16 boundary conditions but reported `Solution trivially zero!`; the
  saved potential field was identically zero. Therefore no B6 current result
  is valid yet, and the earlier Elmer comparison numbers must not be cited.
- An attempted alternative boundary-current source was rejected by the SIF
  parser. It is not a valid CEM solve and was not used for results.
- Repeated the clean basis case with a confirmed `1e-12 S/m` ring, corrected
  `SaveScalars` real-variable name, a local keyword registry, and both vector
  and legacy assembly. Robin voltage drive still gave a trivial-zero field.
  The same mesh/material/frequency with electrode Dirichlet voltages did solve
  nontrivially once the ring was regularized. A boundary-current diagnostic
  produced an extremely ill-conditioned field, consistent with the Robin
  contact matrix not contributing in this installed build.
- Final control: rebuilt a DC Robin case from the known-good Dirichlet SIF,
  with positive conductivity in both regions and the same electrode tags. It
  again reported `Solution trivially zero!`, while the Dirichlet control on the
  same mesh solves nontrivially. This isolates the failure to the installed
  Elmer Robin/CEM path rather than harmonic material assembly.
- The custom CEM plug-in was not implemented in this attempt; do not claim
  Elmer as a software platform is mathematically incapable. The evidence only
  supports that this Elmer 26.1 workflow could not reproduce the CCEIT solve.
- The isolated attempt is retained at
  `elmer_validation/cem_basis01_recovery_test/` for diagnosis. Next required
  step: identify a supported way to inject the Robin source term in this Elmer
  build, then verify a nonzero basis field and contact-current integral before
  generating the port matrix or 120 pairs. No custom solver plug-in has been
  compiled, and no cross-solver validation has been completed.

## FEMM Current Flow cross-solver setup

- Added an isolated `femm_validation/` workflow, at the user's request, to
  compare the explicit-layer B6 forward protocol in FEMM without touching the
  EIDORS core or the unsuccessful Elmer solver setup.
- `run_b6_femm.py` reads the saved B6 MAT, preserves its boundary polylines,
  region interface, and electrode IDs, then asks FEMM/Triangle to mesh the
  interiors at the saved B6 local target sizes. It supports a one-pair check and
  a scripted scan of all 120 unordered pairs, with CSV currents and numerical
  checks.
- FEMM current-flow inputs require the `.fec` extension. The first draft used
  `.fem` (the magnetics extension), which caused `csolv` to reject the input;
  the script now saves the correct `.fec` type.
- The first pyFEMM attempt used `.fem` (the magnetics extension), causing both
  the B6 case and a tiny Current Flow control to fail at solver input loading.
  FEMM Current Flow inputs use `.fec`; changing the saved model extension fixed
  the failure.
- Ran the B6 1-9 pair successfully: `|It|=4.0600e-4 A`, normalized current
  imbalance `2.90e-12`, unselected-current ratio `0`, and terminal-voltage
  deviation `8.88e-16 V`. Outputs are `B6_FEMM_current_flow.fec`, its `.anc`
  solution, and `B6_FEMM_pair_check.csv` under `femm_validation/results/`.
- FEMM uses ideal equipotential conductor contacts, while EIDORS B6 has
  `z_el=0.01 Ohm.m`; this difference remains a limitation for interpreting
  solver-to-solver differences. The 120-pair run has not been made.
- See `femm_validation/README.md` for dependencies and commands. Next step is
  to compare the 1-9 complex current with the EIDORS pair and then run `--all`.

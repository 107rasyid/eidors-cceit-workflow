% CHECK_ELECTRODE_ARCS Compare realized A3/B6 electrode boundary widths.
% Purpose: diagnose whether the A/B difference could be affected by realized
%          electrode arc length or electrode-node discretization.
% Inputs: active project parameters from cceit_params; no command arguments.
% Outputs: console table, CSV, and MAT in results/goal2_diagnostics/.
% This diagnostic builds meshes only; it does not solve the forward problem.
% Implements: Goal 2 interpretation check; does not modify the active workflow.
clear; close all; clc;
setup_paths();
P = cceit_params();
P.outdir = fullfile(P.project_root,'results','goal2_diagnostics');
if exist(P.outdir,'dir') ~= 7, mkdir(P.outdir); end

%% Build the A3 and B6 meshes at the current d=2 mm comparison setting
P.d = 2e-3;
eidors_cache clear
[fmdl_A, info_A] = cceit_mesh_A3(P);
eidors_cache clear
[fmdl_B, ring_B, info_B] = cceit_mesh_B6(P,P.h_ring_B6_coarse);

%% Measure the represented boundary arc and node count for each electrode
arc_A_m = cceit_electrode_boundary_lengths(fmdl_A);
arc_B_m = cceit_electrode_boundary_lengths(fmdl_B);
node_count_A = zeros(P.nElec,1);
node_count_B = zeros(P.nElec,1);
for e = 1:P.nElec
    node_count_A(e) = numel(unique(fmdl_A.electrode(e).nodes(:)));
    node_count_B(e) = numel(unique(fmdl_B.electrode(e).nodes(:)));
end

target_arc_A_m = 2*P.R*asin(P.w_el/(2*P.R));
radius_B_m = P.R + P.d;
target_arc_B_m = 2*radius_B_m*asin(P.w_el/(2*radius_B_m));
relative_arc_difference = (arc_B_m-arc_A_m)./arc_A_m;

fprintf('A3/B6 realized electrode arc check (mesh only; no forward solve)\n');
fprintf('A3: %d elems, target arc %.5f mm; B6: %d elems, target arc %.5f mm\n', ...
    info_A.nElems,target_arc_A_m*1e3,info_B.nElems,target_arc_B_m*1e3);
fprintf('B6 ring: %d elems at h_ring %.3f mm\n', ...
    sum(ring_B),P.h_ring_B6_coarse*1e3);
fprintf('electrode,nodes_A,nodes_B,arc_A_mm,arc_B_mm,arc_B_minus_A_pct\n');
for e = 1:P.nElec
    fprintf('%d,%d,%d,%.6f,%.6f,%+.4f\n',e,node_count_A(e),node_count_B(e), ...
        arc_A_m(e)*1e3,arc_B_m(e)*1e3,100*relative_arc_difference(e));
end

%% Save data separately from the paper's primary results
csv_path = fullfile(P.outdir,'electrode_arc_A3_B6.csv');
fid = fopen(csv_path,'w');
if fid < 0, error('check_electrode_arcs: cannot write %s',csv_path); end
fprintf(fid,['electrode,node_count_A3,node_count_B6,arc_A3_mm,arc_B6_mm,' ...
    'target_arc_A3_mm,target_arc_B6_mm,arc_B6_minus_A3_pct\n']);
for e = 1:P.nElec
    fprintf(fid,'%d,%d,%d,%.12g,%.12g,%.12g,%.12g,%.12g\n', ...
        e,node_count_A(e),node_count_B(e),arc_A_m(e)*1e3,arc_B_m(e)*1e3, ...
        target_arc_A_m*1e3,target_arc_B_m*1e3,100*relative_arc_difference(e));
end
fclose(fid);
meta = cceit_make_metadata(P);
mat_path = fullfile(P.outdir,'electrode_arc_A3_B6.mat');
save(mat_path,'P','info_A','info_B','arc_A_m','arc_B_m','node_count_A', ...
    'node_count_B','target_arc_A_m','target_arc_B_m', ...
    'relative_arc_difference','meta');
fprintf('Saved diagnostic CSV: %s\nSaved diagnostic MAT: %s\n',csv_path,mat_path);

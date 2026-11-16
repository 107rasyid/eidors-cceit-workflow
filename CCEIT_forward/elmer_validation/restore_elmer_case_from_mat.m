% RESTORE_ELMER_CASE_FROM_MAT Restore the exact exported B6 mesh from its MAT.
% Purpose: recover the saved Netgen/EIDORS mesh without rebuilding/remeshing it.
% Inputs: elmer_validation/B6_hmed2.00mm_hring0.35mm/B6_mesh_reference.mat.
% Outputs: elmer_validation/elmer_case/mesh/mesh.* and elmer_case/case.sif.
% Manuscript ref: Section IV.B, independent forward-solver validation.
%
% Run from CCEIT_forward in Octave after setup_paths:
%   run('elmer_validation/restore_elmer_case_from_mat.m')

P = cceit_params();
base_dir = fullfile(P.project_root, 'elmer_validation');
mat_file = fullfile(base_dir, 'B6_hmed2.00mm_hring0.35mm', ...
    'B6_mesh_reference.mat');
template_sif = fullfile(base_dir, 'case_basis01_template.sif');
project_dir = fullfile(base_dir, 'elmer_case');
mesh_dir = fullfile(project_dir, 'mesh');

if exist(mat_file, 'file') ~= 2
    error('restore_elmer_case_from_mat: saved B6 mesh MAT is missing: %s', mat_file);
end
if exist(template_sif, 'file') ~= 2
    error('restore_elmer_case_from_mat: SIF template is missing: %s', template_sif);
end

saved = load(mat_file, 'mesh_export');
if ~isfield(saved, 'mesh_export')
    error('restore_elmer_case_from_mat: MAT does not contain mesh_export');
end
M = saved.mesh_export;
required = {'nodes_m','elements','region_id','boundary_edges', ...
    'boundary_id','boundary_parent1','boundary_parent2'};
for k = 1:numel(required)
    if ~isfield(M, required{k})
        error('restore_elmer_case_from_mat: mesh_export lacks %s', required{k});
    end
end

if exist(mesh_dir, 'dir') ~= 7
    [ok, msg] = mkdir(mesh_dir);
    if ~ok
        error('restore_elmer_case_from_mat: cannot create mesh folder: %s', msg);
    end
end

nodes_m = M.nodes_m;
elements = M.elements;
region_id = M.region_id(:);
boundary_edges = M.boundary_edges;
boundary_id = M.boundary_id(:);
parent1 = M.boundary_parent1(:);
parent2 = M.boundary_parent2(:);
n_nodes = size(nodes_m,1);
n_elements = size(elements,1);
n_boundary = size(boundary_edges,1);
if numel(region_id) ~= n_elements || numel(boundary_id) ~= n_boundary || ...
        numel(parent1) ~= n_boundary || numel(parent2) ~= n_boundary
    error('restore_elmer_case_from_mat: saved mesh arrays have inconsistent sizes');
end

fid = fopen(fullfile(mesh_dir,'mesh.header'),'w');
if fid < 0, error('restore_elmer_case_from_mat: cannot write mesh.header'); end
fprintf(fid,'%d %d %d\n2\n303 %d\n202 %d\n', ...
    n_nodes,n_elements,n_boundary,n_elements,n_boundary);
fclose(fid);

fid = fopen(fullfile(mesh_dir,'mesh.nodes'),'w');
if fid < 0, error('restore_elmer_case_from_mat: cannot write mesh.nodes'); end
for k = 1:n_nodes
    fprintf(fid,'%d 1 %.16g %.16g 0\n',k,nodes_m(k,1),nodes_m(k,2));
end
fclose(fid);

fid = fopen(fullfile(mesh_dir,'mesh.elements'),'w');
if fid < 0, error('restore_elmer_case_from_mat: cannot write mesh.elements'); end
for k = 1:n_elements
    fprintf(fid,'%d %d 303 %d %d %d\n',k,region_id(k), ...
        elements(k,1),elements(k,2),elements(k,3));
end
fclose(fid);

fid = fopen(fullfile(mesh_dir,'mesh.boundary'),'w');
if fid < 0, error('restore_elmer_case_from_mat: cannot write mesh.boundary'); end
for k = 1:n_boundary
    fprintf(fid,'%d %d %d %d 202 %d %d\n',n_elements+k, ...
        boundary_id(k),parent1(k),parent2(k), ...
        boundary_edges(k,1),boundary_edges(k,2));
end
fclose(fid);

[ok, msg] = copyfile(template_sif, fullfile(project_dir,'case.sif'));
if ~ok
    error('restore_elmer_case_from_mat: cannot copy case.sif: %s', msg);
end

fprintf('Restored exact saved mesh (no remeshing):\n  %s\n', mesh_dir);
fprintf('Nodes: %d | triangles: %d | boundary segments: %d\n', ...
    n_nodes,n_elements,n_boundary);
fprintf('SIF template copied to: %s\n', fullfile(project_dir,'case.sif'));

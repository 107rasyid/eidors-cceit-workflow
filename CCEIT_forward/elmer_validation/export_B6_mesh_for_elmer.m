% EXPORT_B6_MESH_FOR_ELMER Generate the active B6 mesh and export it unchanged.
% Purpose: provide Elmer FEM with the same Netgen/EIDORS B6 nodes and triangles.
% Inputs: parameters from cceit_params; setup_paths must have been called.
% Outputs: Elmer mesh files, region/boundary maps, and the original EIDORS model.
% Manuscript ref: Section IV.B, independent forward-solver validation.
%
% Run from the project root in Octave:
%   setup_paths
%   run('elmer_validation/export_B6_mesh_for_elmer.m')
%
% This script creates mesh data only. It does not solve the Elmer model.

if exist('cceit_params', 'file') ~= 2 || exist('cceit_mesh_B6', 'file') ~= 2
    error(['export_B6_mesh_for_elmer: run setup_paths from CCEIT_forward ' ...
        'before running this exporter']);
end

P = cceit_params();
if ~isfield(P, 'h_ring_B6_coarse')
    error('export_B6_mesh_for_elmer: cceit_params is missing h_ring_B6_coarse');
end

% Use the current B6 coarse reference resolution from the shared parameters.
h_ring_export = P.h_ring_B6_coarse;
[fmdl_B6, ring_B6, mesh_info] = cceit_mesh_B6(P, h_ring_export);

nodes_m = fmdl_B6.nodes(:,1:2);
elements = fmdl_B6.elems;
n_nodes = size(nodes_m,1);
n_elements = size(elements,1);
if size(elements,2) ~= 3
    error('export_B6_mesh_for_elmer: B6 mesh must contain 3-node triangles');
end
if numel(ring_B6) ~= n_elements
    error('export_B6_mesh_for_elmer: ring mask length does not match elements');
end

% Elmer body 1 is the medium; body 2 is the explicit dielectric ring.
region_id = ones(n_elements,1);
region_id(ring_B6(:)) = 2;
parent_region = region_id;

% Collect the three edges of each triangle and retain adjacent element IDs.
all_edges = [elements(:,[1 2]); elements(:,[2 3]); elements(:,[3 1])];
edge_parent = [(1:n_elements)'; (1:n_elements)'; (1:n_elements)'];
all_edges = sort(all_edges,2);
[unique_edges,~,edge_group] = unique(all_edges,'rows');
n_unique_edges = size(unique_edges,1);
edge_count = accumarray(edge_group,1,[n_unique_edges 1]);
if any(edge_count > 2)
    error('export_B6_mesh_for_elmer: non-manifold mesh edge has more than two parents');
end

parent1 = zeros(n_unique_edges,1);
parent2 = zeros(n_unique_edges,1);
for k = 1:numel(edge_group)
    g = edge_group(k);
    if parent1(g) == 0
        parent1(g) = edge_parent(k);
    else
        parent2(g) = edge_parent(k);
    end
end

% Boundary IDs: 1 outer wall, 2 medium/ring interface, 11..26 electrodes 1..16.
boundary_id = zeros(n_unique_edges,1);
boundary_id(edge_count == 1) = 1;
interior_edges = find(edge_count == 2);
is_interface = parent_region(parent1(interior_edges)) ~= ...
    parent_region(parent2(interior_edges));
boundary_id(interior_edges(is_interface)) = 2;

electrode_segment_count = zeros(P.nElec,1);
external_edges = find(edge_count == 1);
for e = 1:P.nElec
    if ~isfield(fmdl_B6.electrode(e), 'nodes') || isempty(fmdl_B6.electrode(e).nodes)
        error('export_B6_mesh_for_elmer: electrode %d has no node list', e);
    end
    electrode_nodes = unique(fmdl_B6.electrode(e).nodes(:));
    edge_is_electrode = ismember(unique_edges(external_edges,1), electrode_nodes) & ...
        ismember(unique_edges(external_edges,2), electrode_nodes);
    selected_edges = external_edges(edge_is_electrode);
    if isempty(selected_edges)
        error(['export_B6_mesh_for_elmer: no external mesh edges found for ' ...
            'electrode %d; inspect EIDORS electrode node indexing'], e);
    end
    if any(boundary_id(selected_edges) ~= 1)
        error('export_B6_mesh_for_elmer: overlapping electrode boundary nodes at electrode %d', e);
    end
    boundary_id(selected_edges) = 10 + e;
    electrode_segment_count(e) = numel(selected_edges);
end

keep_boundary = boundary_id > 0;
boundary_edges = unique_edges(keep_boundary,:);
boundary_parent1 = parent1(keep_boundary);
boundary_parent2 = parent2(keep_boundary);
boundary_ids = boundary_id(keep_boundary);
n_boundary = size(boundary_edges,1);

% Orient each line so its parent-1 material lies to the left. The resulting
% right-hand normal points outward from that parent region on external arcs.
for k = 1:n_boundary
    if boundary_ids(k) == 2 && region_id(boundary_parent1(k)) ~= 1
        swap_parent = boundary_parent1(k);
        boundary_parent1(k) = boundary_parent2(k);
        boundary_parent2(k) = swap_parent;
    end
    parent_nodes = elements(boundary_parent1(k),:);
    parent_center = mean(nodes_m(parent_nodes,:),1);
    edge_xy = nodes_m(boundary_edges(k,:),:);
    edge_midpoint = mean(edge_xy,1);
    signed_side = (edge_xy(2,1)-edge_xy(1,1)) * ...
        (parent_center(2)-edge_midpoint(2)) - ...
        (edge_xy(2,2)-edge_xy(1,2)) * ...
        (parent_center(1)-edge_midpoint(1));
    if signed_side < 0
        boundary_edges(k,:) = boundary_edges(k,[2 1]);
    end
end

% Keep the Elmer mesh separate from paper plots and solver results.
export_name = sprintf('B6_hmed%.2fmm_hring%.2fmm', ...
    1e3*P.h_int_B6,1e3*h_ring_export);
export_dir = fullfile(P.project_root, 'elmer_validation', export_name);
if exist(export_dir, 'dir') ~= 7
    [mkdir_ok, mkdir_message] = mkdir(export_dir);
    if ~mkdir_ok
        error('export_B6_mesh_for_elmer: cannot create output folder: %s', mkdir_message);
    end
end

% Elmer header stores bulk count and boundary count in separate fields.
fid = fopen(fullfile(export_dir,'mesh.header'),'w');
if fid < 0, error('export_B6_mesh_for_elmer: cannot write mesh.header'); end
fprintf(fid,'%d %d %d\n', n_nodes, n_elements, n_boundary);
fprintf(fid,'2\n303 %d\n202 %d\n', n_elements, n_boundary);
fclose(fid);

fid = fopen(fullfile(export_dir,'mesh.nodes'),'w');
if fid < 0, error('export_B6_mesh_for_elmer: cannot write mesh.nodes'); end
for k = 1:n_nodes
    fprintf(fid,'%d 1 %.16g %.16g 0\n', k, nodes_m(k,1), nodes_m(k,2));
end
fclose(fid);

fid = fopen(fullfile(export_dir,'mesh.elements'),'w');
if fid < 0, error('export_B6_mesh_for_elmer: cannot write mesh.elements'); end
for k = 1:n_elements
    fprintf(fid,'%d %d 303 %d %d %d\n', k, region_id(k), ...
        elements(k,1), elements(k,2), elements(k,3));
end
fclose(fid);

fid = fopen(fullfile(export_dir,'mesh.boundary'),'w');
if fid < 0, error('export_B6_mesh_for_elmer: cannot write mesh.boundary'); end
for k = 1:n_boundary
    % Boundary element IDs continue after the bulk element IDs.
    fprintf(fid,'%d %d %d %d 202 %d %d\n', n_elements+k, ...
        boundary_ids(k), boundary_parent1(k), boundary_parent2(k), ...
        boundary_edges(k,1), boundary_edges(k,2));
end
fclose(fid);

% Export readable material properties for preparing the Elmer SIF.
omega = 2*pi*P.f;
gamma_medium = P.sigma + 1i*omega*P.eps0*P.epsr;
gamma_layer = P.sigma_d + 1i*omega*P.eps0*P.epsr_d;
fid = fopen(fullfile(export_dir,'region_materials.csv'),'w');
if fid < 0, error('export_B6_mesh_for_elmer: cannot write region_materials.csv'); end
fprintf(fid,'body_id,region,sigma_S_per_m,epsr,gamma_real_S_per_m,gamma_imag_S_per_m\n');
fprintf(fid,'1,medium,%.16g,%.16g,%.16g,%.16g\n', ...
    P.sigma,P.epsr,real(gamma_medium),imag(gamma_medium));
fprintf(fid,'2,dielectric_ring,%.16g,%.16g,%.16g,%.16g\n', ...
    P.sigma_d,P.epsr_d,real(gamma_layer),imag(gamma_layer));
fclose(fid);

fid = fopen(fullfile(export_dir,'simulation_parameters.csv'),'w');
if fid < 0, error('export_B6_mesh_for_elmer: cannot write simulation_parameters.csv'); end
fprintf(fid,'parameter,value,unit\n');
fprintf(fid,'frequency,%.16g,Hz\n',P.f);
fprintf(fid,'transmitter_voltage,%.16g,V\n',P.Vtx);
fprintf(fid,'domain_radius,%.16g,m\n',P.R);
fprintf(fid,'layer_thickness,%.16g,m\n',P.d);
fprintf(fid,'model_depth,%.16g,m\n',P.depth);
fprintf(fid,'electrode_contact_impedance,%.16g,Ohm.m\n',P.z_el);
fprintf(fid,'time_convention,e^(+j*omega*t),text\n');
fclose(fid);

fid = fopen(fullfile(export_dir,'boundary_ids.csv'),'w');
if fid < 0, error('export_B6_mesh_for_elmer: cannot write boundary_ids.csv'); end
fprintf(fid,'boundary_id,name,segment_count,z_contact_Ohm_m\n');
fprintf(fid,'1,outer_wall,%d,\n',sum(boundary_ids == 1));
fprintf(fid,'2,medium_ring_interface,%d,\n',sum(boundary_ids == 2));
for e = 1:P.nElec
    fprintf(fid,'%d,electrode_%02d,%d,%.16g\n',10+e,e, ...
        electrode_segment_count(e),P.z_el);
end
fclose(fid);

% Preserve the original EIDORS model and IDs as the reference for Elmer.
mesh_export = struct();
mesh_export.version = '1.0';
mesh_export.generated = datestr(now,31);
mesh_export.mesh_info = mesh_info;
mesh_export.h_ring_m = h_ring_export;
mesh_export.depth_m = P.depth;
mesh_export.nodes_m = nodes_m;
mesh_export.elements = elements;
mesh_export.region_id = region_id;
mesh_export.ring_mask = ring_B6(:);
mesh_export.boundary_edges = boundary_edges;
mesh_export.boundary_id = boundary_ids;
mesh_export.boundary_parent1 = boundary_parent1;
mesh_export.boundary_parent2 = boundary_parent2;
mesh_export.electrode_segment_count = electrode_segment_count;
mesh_export.gamma_medium_S_per_m = gamma_medium;
mesh_export.gamma_layer_S_per_m = gamma_layer;
mesh_export.elmer_boundary_map = ...
    '1 outer wall; 2 medium-ring interface; 11-26 electrodes 1-16';
mesh_export.elmer_body_map = '1 medium; 2 dielectric ring';
save(fullfile(export_dir,'B6_mesh_reference.mat'), ...
    'fmdl_B6','ring_B6','P','mesh_info','mesh_export','-v7');

fprintf('B6 Netgen mesh exported for Elmer FEM\n');
fprintf('Folder: %s\n', export_dir);
fprintf('Nodes: %d | triangles: %d (medium %d, ring %d) | boundary segments: %d\n', ...
    n_nodes,n_elements,mesh_info.nMedium,mesh_info.nRing,n_boundary);
fprintf('h_medium=%.2f mm | h_ring=%.2f mm | f=%.6g Hz\n', ...
    1e3*P.h_int_B6,1e3*h_ring_export,P.f);
fprintf(['Files: mesh.header, mesh.nodes, mesh.elements, mesh.boundary, ' ...
    'region_materials.csv, boundary_ids.csv, simulation_parameters.csv, ' ...
    'B6_mesh_reference.mat\n']);

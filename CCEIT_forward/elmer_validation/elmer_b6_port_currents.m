function I_port = elmer_b6_port_currents(phi, mesh_dir, freq_Hz, sigma_ring)
% ELMER_B6_PORT_CURRENTS Integrate complex current through B6 electrode edges.
% Purpose: recover electrode currents from harmonic potential on the shared mesh.
% Inputs: phi, nodal complex potential; mesh_dir, Elmer mesh folder;
%         freq_Hz, frequency; sigma_ring, tiny numerical ring regularization.
% Outputs: I_port, 16-by-1 complex currents into the domain (A/m depth).
% Manuscript ref: Section III, electrode current recovery for model B6.

node_data = dlmread(fullfile(mesh_dir, 'mesh.nodes'));
elem_data = dlmread(fullfile(mesh_dir, 'mesh.elements'));
bnd_data = dlmread(fullfile(mesh_dir, 'mesh.boundary'));
if size(node_data,1) ~= numel(phi)
    error('elmer_b6_port_currents: VTU points do not match mesh.nodes');
end
if size(elem_data,2) < 6 || size(bnd_data,2) < 7
    error('elmer_b6_port_currents: unexpected Elmer mesh column layout');
end

node_ids = node_data(:,1);
x = node_data(:,3);
y = node_data(:,4);
tri = elem_data(elem_data(:,3) == 303, :);
if size(tri,1) ~= 11872
    warning('elmer_b6_port_currents: expected 11872 triangles, found %d', size(tri,1));
end
if any(tri(:,1) ~= (1:size(tri,1))')
    error('elmer_b6_port_currents: triangle IDs are not contiguous as expected');
end

% Map Elmer node IDs to VTU point-array indexes; exported IDs are 1-based.
if any(node_ids ~= (1:numel(node_ids))')
    error('elmer_b6_port_currents: node IDs are not contiguous as expected');
end
tri_nodes = tri(:,4:6);
x1 = x(tri_nodes(:,1)); x2 = x(tri_nodes(:,2)); x3 = x(tri_nodes(:,3));
y1 = y(tri_nodes(:,1)); y2 = y(tri_nodes(:,2)); y3 = y(tri_nodes(:,3));
detJ = (x2-x1).*(y3-y1) - (x3-x1).*(y2-y1);
if any(abs(detJ) < 1e-16)
    error('elmer_b6_port_currents: degenerate triangle in mesh');
end
gx_shape = [(y2-y3), (y3-y1), (y1-y2)] ./ detJ;
gy_shape = [(x3-x2), (x1-x3), (x2-x1)] ./ detJ;
grad_x = sum(phi(tri_nodes).*gx_shape, 2);
grad_y = sum(phi(tri_nodes).*gy_shape, 2);

omega = 2*pi*freq_Hz;
eps0 = 8.8541878128e-12;
gamma_medium = 0.025 + 1i*omega*eps0*80;
gamma_ring = sigma_ring + 1i*omega*eps0*3;
gamma = gamma_medium*ones(size(tri,1),1);
gamma(tri(:,2) == 2) = gamma_ring;

I_port = zeros(16,1);
for elec = 1:16
    edges = bnd_data(bnd_data(:,2) == 10+elec, :);
    if isempty(edges)
        error('elmer_b6_port_currents: no boundary edges for electrode %d', elec);
    end
    for k = 1:size(edges,1)
        parent = edges(k,3);
        edge_nodes = edges(k,6:7);
        edge_xy = [x(edge_nodes(1)), y(edge_nodes(1)); ...
                   x(edge_nodes(2)), y(edge_nodes(2))];
        tangent = edge_xy(2,:) - edge_xy(1,:);
        edge_length = norm(tangent);
        normal = [tangent(2), -tangent(1)] / edge_length;
        parent_nodes = tri(parent,4:6);
        centroid = [mean(x(parent_nodes)), mean(y(parent_nodes))];
        midpoint = mean(edge_xy,1);
        if dot(normal, midpoint-centroid) < 0
            normal = -normal;
        end
        % Positive electrode current is defined into the computational domain.
        I_port(elec) = I_port(elec) + gamma(parent) * ...
            (grad_x(parent)*normal(1) + grad_y(parent)*normal(2)) * edge_length;
    end
end
end

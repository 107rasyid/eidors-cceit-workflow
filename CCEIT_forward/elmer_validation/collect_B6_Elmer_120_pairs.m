function result_file = collect_B6_Elmer_120_pairs()
% COLLECT_B6_ELMER_120_PAIRS Form voltage-driven pair data from Elmer basis runs.
% Purpose: combine 16 Elmer port-basis solutions into 120 CCEIT pair responses.
% Inputs: CCEIT_ELMER_RUN_ROOT environment variable set by the runner script.
% Outputs: CSV/MAT files with pair admittance, electrode currents, and checks.
% Manuscript ref: Section III, independent Elmer forward-solver validation.

run_root = getenv('CCEIT_ELMER_RUN_ROOT');
if isempty(run_root) || ~isfolder(run_root)
    error('collect_B6_Elmer_120_pairs: set CCEIT_ELMER_RUN_ROOT to the basis-run folder');
end
script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(script_dir);
result_dir = fullfile(script_dir, 'results');
if ~isfolder(result_dir), mkdir(result_dir); end

freq_Hz = 500e3;
sigma_ring = 1e-12; % numerical regularization needed by this Elmer build
Y_port = complex(zeros(16,16));
basis_max_bc_error = 0;
for basis = 1:16
    basis_dir = fullfile(run_root, sprintf('basis_%02d', basis));
    vtu_file = fullfile(basis_dir, 'mesh', sprintf('basis_%02d_t0001.vtu', basis));
    mesh_dir = fullfile(basis_dir, 'mesh');
    if ~isfile(vtu_file)
        error('collect_B6_Elmer_120_pairs: missing result %s', vtu_file);
    end
    phi = elmer_read_vtu_potential(vtu_file);
    if numel(phi) ~= 6433
        error('collect_B6_Elmer_120_pairs: basis %d has %d nodes; expected 6433', basis, numel(phi));
    end
    node_data = dlmread(fullfile(mesh_dir, 'mesh.nodes'));
    boundary = dlmread(fullfile(mesh_dir, 'mesh.boundary'));
    elec_nodes = unique(boundary(boundary(:,2) == 10+basis, 6:7));
    basis_max_bc_error = max(basis_max_bc_error, max(abs(real(phi(elec_nodes))-1)));
    other_nodes = [];
    for other = 1:16
        if other ~= basis
            other_edge_nodes = boundary(boundary(:,2) == 10+other, 6:7);
            other_nodes = [other_nodes; other_edge_nodes(:)];
        end
    end
    other_nodes = unique(other_nodes);
    basis_max_bc_error = max(basis_max_bc_error, max(abs(real(phi(other_nodes)))));
    basis_max_bc_error = max(basis_max_bc_error, max(abs(imag(phi([elec_nodes;other_nodes])))));
    Y_port(:,basis) = elmer_b6_port_currents(phi, mesh_dir, freq_Hz, sigma_ring);
    fprintf('Read Elmer basis %02d/16; max prescribed-potential error = %.3e V\n', ...
            basis, basis_max_bc_error);
end

pair_count = 16*15/2;
pairs = zeros(pair_count,2);
y_pair = complex(zeros(pair_count,1));
I_tx = complex(zeros(pair_count,1));
I_rx = complex(zeros(pair_count,1));
max_floating_ratio = 0;
max_current_sum_ratio = 0;
idx = 0;
for tx = 1:15
    for rx = tx+1:16
        idx = idx+1;
        fixed = [tx rx];
        floating = setdiff(1:16, fixed);
        V_fixed = [1;0];
        V_port = complex(zeros(16,1));
        V_port(fixed) = V_fixed;
        V_port(floating) = -(Y_port(floating,floating) \ ...
                                (Y_port(floating,fixed)*V_fixed));
        I = Y_port*V_port;
        pairs(idx,:) = [tx rx];
        y_pair(idx) = I(tx); % Vtx=1 V, so I/V equals pair admittance.
        I_tx(idx) = I(tx);
        I_rx(idx) = I(rx);
        scale = max(abs(I(tx)), realmin);
        max_floating_ratio = max(max_floating_ratio, max(abs(I(floating))/scale));
        max_current_sum_ratio = max(max_current_sum_ratio, abs(sum(I))/scale);
    end
end

csv_file = fullfile(result_dir, 'elmer_B6_120_pairs.csv');
fid = fopen(csv_file, 'w');
if fid < 0, error('collect_B6_Elmer_120_pairs: cannot write %s', csv_file); end
fprintf(fid, ['pair_index,tx,rx,Y_real_S_per_m,Y_imag_S_per_m,absY_S_per_m,' ...
              'phase_deg,I_tx_real_A_per_m,I_tx_imag_A_per_m,' ...
              'I_rx_real_A_per_m,I_rx_imag_A_per_m\n']);
for k = 1:pair_count
    fprintf(fid, '%d,%d,%d,%.12e,%.12e,%.12e,%.9f,%.12e,%.12e,%.12e,%.12e\n', ...
        k, pairs(k,1), pairs(k,2), real(y_pair(k)), imag(y_pair(k)), ...
        abs(y_pair(k)), angle(y_pair(k))*180/pi, real(I_tx(k)), imag(I_tx(k)), ...
        real(I_rx(k)), imag(I_rx(k)));
end
fclose(fid);

port_csv = fullfile(result_dir, 'elmer_B6_port_matrix.csv');
fid = fopen(port_csv, 'w');
fprintf(fid, 'electrode');
for k = 1:16, fprintf(fid, ',I_basis%d_real_A_per_m,I_basis%d_imag_A_per_m', k, k); end
fprintf(fid, '\n');
for e = 1:16
    fprintf(fid, '%d', e);
    for k = 1:16, fprintf(fid, ',%.12e,%.12e', real(Y_port(e,k)), imag(Y_port(e,k))); end
    fprintf(fid, '\n');
end
fclose(fid);

reciprocity_error = norm(Y_port-Y_port.', 'fro') / max(norm(Y_port,'fro'),realmin);
delta_vs_eidors = NaN;
median_ratio_vs_eidors = NaN;
reference_file = fullfile(project_root, 'results', 'AB_A3_B6_coarse_results.mat');
if isfile(reference_file)
    ref = load(reference_file, 'y_B', 'pairs', 'P', 'freq_Hz', 'h_ring');
    if isfield(ref,'y_B') && numel(ref.y_B) == pair_count && ...
       isfield(ref,'freq_Hz') && abs(ref.freq_Hz-freq_Hz) < 1e-9
        delta_vs_eidors = norm(y_pair-ref.y_B(:))/max(norm(ref.y_B(:)),realmin);
        median_ratio_vs_eidors = median(abs(y_pair)./max(abs(ref.y_B(:)),realmin));
    end
end

timestamp = datestr(now, 'yyyy-mm-dd HH:MM:SS');
result_file = fullfile(result_dir, 'elmer_B6_120_pairs.mat');
save(result_file, 'pairs', 'y_pair', 'I_tx', 'I_rx', 'Y_port', 'freq_Hz', ...
    'sigma_ring', 'basis_max_bc_error', 'max_floating_ratio', ...
    'max_current_sum_ratio', 'reciprocity_error', 'delta_vs_eidors', ...
    'median_ratio_vs_eidors', 'timestamp');

fprintf('\nElmer B6 port-basis results:\n');
fprintf('  max boundary voltage error = %.3e V\n', basis_max_bc_error);
fprintf('  max floating current ratio = %.3e\n', max_floating_ratio);
fprintf('  max current-sum ratio      = %.3e\n', max_current_sum_ratio);
fprintf('  port reciprocity error     = %.3e\n', reciprocity_error);
fprintf('  delta vs EIDORS B6         = %.6g\n', delta_vs_eidors);
fprintf('  median |Y_Elmer|/|Y_EIDORS|= %.6g\n', median_ratio_vs_eidors);
fprintf('CSV: %s\n', csv_file);
fprintf('MAT: %s\n', result_file);
end

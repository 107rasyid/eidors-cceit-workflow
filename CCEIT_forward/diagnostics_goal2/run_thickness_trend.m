% RUN_THICKNESS_TREND Diagnostic A3/B6 Delta_layer versus layer thickness.
% Purpose: check whether the A3/B6 difference changes systematically with d.
% Inputs: active material/frequency/electrode parameters from cceit_params.
% Outputs: per-thickness console rows, CSV, and checkpoint MAT in
%          results/goal2_diagnostics/.
% The ring mesh target is capped at the active 0.35 mm value and reduced to
% d/4 for thinner layers, keeping at least about four target elements across d.
% This is an interpretation study, not a replacement for the production runs.
% Implements: Goal 2 interpretation check; does not modify the active workflow.
clear; close all; clc;
setup_paths();
P0 = cceit_params();
outdir = fullfile(P0.project_root,'results','goal2_diagnostics');
if exist(outdir,'dir') ~= 7, mkdir(outdir); end
P0.outdir = outdir;

%% Build the A3 geometry once; thickness changes only its effective z_contact
d_values_mm = [1 2 3 5];
eidors_cache clear
[fmdl_A, info_A] = cceit_mesh_A3(P0);

results = struct('d_mm',{},'h_ring_mm',{},'n_elems_A3',{}, ...
    'n_elems_B6',{},'n_ring_B6',{},'n_medium_B6',{},'n_across_B6',{}, ...
    'delta_layer',{},'median_abs_yA_over_yB',{},'time_A_scan_s',{}, ...
    'time_B_mesh_and_scan_s',{},'status',{},'error_message',{});
meta = cceit_make_metadata(P0);
mat_path = fullfile(outdir,'thickness_trend_A3_B6.mat');

fprintf('A3/B6 thickness diagnostic at f=%.0f kHz; A3 elements=%d\n', ...
    P0.f/1e3,info_A.nElems);
fprintf(['d_mm,h_ring_mm,n_elems_A3,n_elems_B6,n_ring_B6,n_medium_B6,' ...
    'n_across_B6,Delta_layer,median_abs_yA_over_yB,time_A_scan_s,' ...
    'time_B_mesh_and_scan_s,status\n']);

%% Run one controlled thickness point at a time; retain failures and continue
for k = 1:numel(d_values_mm)
    d_m = d_values_mm(k)*1e-3;
    P = P0;
    P.d = d_m;
    h_ring = min(P.h_ring_B6_coarse,d_m/4);
    results(k).d_mm = d_values_mm(k);
    results(k).h_ring_mm = h_ring*1e3;
    results(k).n_elems_A3 = info_A.nElems;
    results(k).n_elems_B6 = NaN;
    results(k).n_ring_B6 = NaN;
    results(k).n_medium_B6 = NaN;
    results(k).n_across_B6 = NaN;
    results(k).delta_layer = NaN;
    results(k).median_abs_yA_over_yB = NaN;
    results(k).time_A_scan_s = NaN;
    results(k).time_B_mesh_and_scan_s = NaN;
    results(k).status = 'failed';
    results(k).error_message = '';

    try
        timer_A = tic;
        y_A = cceit_runA3_mesh(fmdl_A,P,P.f);
        results(k).time_A_scan_s = toc(timer_A);

        timer_B = tic;
        [y_B,info_B] = cceit_runB6(P,P.f,h_ring);
        results(k).time_B_mesh_and_scan_s = toc(timer_B);

        results(k).n_elems_B6 = info_B.nElems;
        results(k).n_ring_B6 = info_B.nRing;
        results(k).n_medium_B6 = info_B.nMedium;
        results(k).n_across_B6 = info_B.nAcross;
        results(k).delta_layer = norm(y_A-y_B)/norm(y_B);
        results(k).median_abs_yA_over_yB = median(abs(y_A)./abs(y_B));
        results(k).status = 'ok';
    catch err
        results(k).error_message = err.message;
        warning('run_thickness_trend: d=%.1f mm failed: %s', ...
            d_values_mm(k),err.message);
    end

    fprintf('%.3f,%.3f,%g,%g,%g,%g,%.4g,%.8g,%.8g,%.3f,%.3f,%s\n', ...
        results(k).d_mm,results(k).h_ring_mm,results(k).n_elems_A3, ...
        results(k).n_elems_B6,results(k).n_ring_B6,results(k).n_medium_B6, ...
        results(k).n_across_B6,results(k).delta_layer, ...
        results(k).median_abs_yA_over_yB,results(k).time_A_scan_s, ...
        results(k).time_B_mesh_and_scan_s,results(k).status);

    % Preserve completed points if a later NETGEN build or scan fails.
    save(mat_path,'P0','d_values_mm','info_A','results','meta');
end

%% Export the diagnostic table without touching primary result files
csv_path = fullfile(outdir,'thickness_trend_A3_B6.csv');
fid = fopen(csv_path,'w');
if fid < 0, error('run_thickness_trend: cannot write %s',csv_path); end
fprintf(fid,['d_mm,h_ring_mm,n_elems_A3,n_elems_B6,n_ring_B6,n_medium_B6,' ...
    'n_across_B6,Delta_layer,median_abs_yA_over_yB,time_A_scan_s,' ...
    'time_B_mesh_and_scan_s,status\n']);
for k = 1:numel(results)
    q = results(k);
    fprintf(fid,'%.6g,%.6g,%g,%g,%g,%g,%.8g,%.12g,%.12g,%.8g,%.8g,%s\n', ...
        q.d_mm,q.h_ring_mm,q.n_elems_A3,q.n_elems_B6,q.n_ring_B6, ...
        q.n_medium_B6,q.n_across_B6,q.delta_layer, ...
        q.median_abs_yA_over_yB,q.time_A_scan_s, ...
        q.time_B_mesh_and_scan_s,q.status);
end
fclose(fid);
fprintf('Diagnostic CSV: %s\nDiagnostic MAT: %s\n',csv_path,mat_path);

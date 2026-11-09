% DEMO_RECONSTRUCTION Run a separate six-case reconstruction demonstration.
% Purpose: check that voltage-driven forward data can be carried through an
% ideal TIA model and a simple complex-Jacobian reconstruction example.
% Cases: one circle, two circles left/right, and three circles in a triangle;
%        each case uses active Model A3 and coarse Model B6 meshes.
% Outputs: one MAT and TIA CSV per case, six conductivity/permittivity
%          reconstruction figures and six homogeneous/inclusion current
%          figures shown in the Octave GUI, plus a status MAT.
% Scope: educational verification only; this is not paper validation.
% Manuscript ref: Section III implementation demonstration; not validation.
clear; close all; clc;

%% Project setup and output folder
project_root = setup_paths();
addpath(fullfile(project_root,'demo_reconstruction'));
P = cceit_params();
outdir = fullfile(P.project_root,'results','reconstruction_demo');
if exist(outdir,'dir') ~= 7, mkdir(outdir); end
%% Run each phantom/model combination independently
% A case failure is recorded and does not prevent the remaining cases.
status_file = fullfile(outdir,'demo_run_status.mat');
if exist(status_file,'file'), delete(status_file); end
names = {'one_circle','two_circles_left_right','three_circles_triangle'};
report = cell(3,2);
for p = 1:3
    for m = 1:2
        try
            report{p,m} = cceit_demo_case(P,p,m,outdir);
            fprintf('DONE %s / %s\n',names{p},report{p,m}.model);
        catch err
            report{p,m} = struct('status','failed','message',err.message);
            fprintf(2,'FAIL %s / model %d: %s\n',names{p},m,err.message);
        end
    end
end

%% Plot conductivity and relative-permittivity ground truth and reconstructions
% The inverse solve estimates the two real physical property changes jointly.
model_names = {'A3','B6'};
for p = 1:3
    for m = 1:2
        data = report{p,m};
        if ~isstruct(data) || ~isfield(data,'dgamma_reconstruction')
            fprintf('Skip %s model %d: incomplete data\n',names{p},m);
            continue;
        end

        gt_sigma = data.delta_sigma_true;
        rec_sigma = data.delta_sigma_reconstruction;
        gt_epsr = data.delta_epsr_true;
        rec_epsr = data.delta_epsr_reconstruction;
        lim_sigma_gt = max(abs(gt_sigma(:)));
        lim_sigma_rec = max(abs(rec_sigma(:)));
        lim_epsr_gt = max(abs(gt_epsr(:)));
        lim_epsr_rec = max(abs(rec_epsr(:)));
        if lim_sigma_gt == 0, lim_sigma_gt = 1; end
        if lim_sigma_rec == 0, lim_sigma_rec = 1; end
        if lim_epsr_gt == 0, lim_epsr_gt = 1; end
        if lim_epsr_rec == 0, lim_epsr_rec = 1; end
        fprintf(['Peak |estimate| / peak |ground truth|: %s, ' ...
            'sigma=%.3g%%, epsilon_r=%.3g%%\n'],model_names{m}, ...
            100*max(abs(rec_sigma(:)))/max(max(abs(gt_sigma(:))),eps), ...
            100*max(abs(rec_epsr(:)))/max(max(abs(gt_epsr(:))),eps));

        fig = figure('visible','on','color','w','position',[100 100 1200 850], ...
            'Name',sprintf('Reconstruction: %s / %s',names{p},model_names{m}));

        subplot(2,2,1); cceit_demo_map(data.nodes,data.elements,gt_sigma, ...
            'Ground truth: \Delta\sigma (S/m)',[-lim_sigma_gt lim_sigma_gt]);
        subplot(2,2,2); cceit_demo_map(data.nodes,data.elements,rec_sigma, ...
            sprintf('%s: reconstructed \Delta\sigma (S/m)',model_names{m}), ...
            [-lim_sigma_rec lim_sigma_rec]);
        subplot(2,2,3); cceit_demo_map(data.nodes,data.elements,gt_epsr, ...
            'Ground truth: \Delta\epsilon_r',[-lim_epsr_gt lim_epsr_gt]);
        subplot(2,2,4); cceit_demo_map(data.nodes,data.elements,rec_epsr, ...
            sprintf('%s: reconstructed \Delta\epsilon_r',model_names{m}), ...
            [-lim_epsr_rec lim_epsr_rec]);

        base = sprintf('%s_%s',strrep(names{p},'_','_'),model_names{m});
        drawnow;
        fprintf('Displayed reconstruction figure: %s\n',base);
    end
end
%% Save the complete in-memory case status for optional follow-up plots
save(fullfile(outdir,'demo_run_status.mat'),'report','names');
fprintf('Demo results: %s\n',outdir);

%% Plot the 120-pair forward-current responses
% Compare homogeneous and inclusion transmitter currents for each phantom
% and model. The plotting helper reads the status MAT saved above.
run(fullfile(project_root,'demo_reconstruction','plot_current_diff.m'));

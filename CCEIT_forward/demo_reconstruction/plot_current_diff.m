% PLOT_CURRENT_DIFF Plot homogeneous and inclusion currents for saved cases.
% Purpose: inspect the 120-pair forward-current change before TIA processing.
% Inputs: results/reconstruction_demo/demo_run_status.mat from the demo script.
% Outputs: up to six figures shown in the Octave GUI, one per completed case.
% Note: the demo calls this after saving its case status; run it alone to
%       redraw the current figures without repeating forward solves.
% Manuscript ref: standalone educational reconstruction demonstration.
project_root = setup_paths();
status_path = fullfile(project_root,'results','reconstruction_demo','demo_run_status.mat');
if exist(status_path,'file') ~= 2
    error('plot_current_diff: run demo_reconstruction.m first to create %s',status_path);
end
saved = load(status_path);
report = saved.report;

phantom_names = {'one_circle','two_circles_left_right','three_circles_triangle'};
model_names = {'A3','B6'};

% ---- Layout options ----
% STANDARDIZE = 'none' : ylim per subplot (data mengisi kotak, tidak ada kosong)  <-- default
% STANDARDIZE = 'row'  : baris atas share ylim, baris bawah share ylim
% STANDARDIZE = 'all'  : keempat subplot share ylim (bisa bikin kosong atas-bawah)
STANDARDIZE = 'none';

% CLIP_FRAC: buang sekian fraksi ekstrem di tiap ujung sebelum hitung min/max.
% 0    = pakai min/max murni
% 0.01 = buang 1% outlier di tiap ujung (disarankan)
CLIP_FRAC = 0.01;

% Padding fraction for ylim (5% of each subplot's data range)
pad_frac = 0.05;

% Load all cases
cases = {};
case_labels = {};
case_files = {};
for p = 1:3
    for m = 1:2
        if isstruct(report{p,m}) && isfield(report{p,m},'I_h')
            cases{end+1} = report{p,m};
            case_labels{end+1} = sprintf('%s - %s', model_names{m}, strrep(phantom_names{p}, '_', ' '));
            case_files{end+1} = sprintf('%s_%s', model_names{m}, phantom_names{p});
        end
    end
end

nCases = length(cases);

% Colours
col_homog    = [0.000 0.447 0.741];   % biru
col_inhomog  = [0.850 0.325 0.098];   % oranye
col_diff     = [0.494 0.184 0.556];   % ungu

% Create separate figure for each case
for c = 1:nCases
    data = cases{c};
    order = 1:length(data.I_h);
    dI = data.I_i - data.I_h;

    % ===== Build 4 groups of data (one per subplot) =====
    groups = {
        [real(data.I_h); real(data.I_i)], ...   % subplot 1
        [imag(data.I_h); imag(data.I_i)], ...   % subplot 2
        real(dI),                        ...    % subplot 3
        imag(dI)                                 % subplot 4
    };

    % ===== Compute ylim per subplot, with outlier clipping =====
    ylims = zeros(4,2);
    for k = 1:4
        v = sort(groups{k}(:));
        n = length(v);
        k_lo = max(1, floor(CLIP_FRAC*n) + 1);
        k_hi = min(n, ceil((1-CLIP_FRAC)*n));
        raw_lo = v(k_lo);
        raw_hi = v(k_hi);
        if raw_hi == raw_lo
            s = max(abs(raw_hi), 1);
            ylims(k,1) = raw_lo - pad_frac*s;
            ylims(k,2) = raw_hi + pad_frac*s;
        else
            d = raw_hi - raw_lo;
            ylims(k,1) = raw_lo - pad_frac*d;
            ylims(k,2) = raw_hi + pad_frac*d;
        end
    end

    % ===== Apply sharing mode =====
    if strcmp(STANDARDIZE, 'all')
        all_lo = min(ylims(:,1));
        all_hi = max(ylims(:,2));
        ylims = repmat([all_lo all_hi], 4, 1);
    elseif strcmp(STANDARDIZE, 'row')
        top_lo = min(ylims(1:2,1));  top_hi = max(ylims(1:2,2));
        bot_lo = min(ylims(3:4,1));  bot_hi = max(ylims(3:4,2));
        ylims = [top_lo top_hi; top_lo top_hi; bot_lo bot_hi; bot_lo bot_hi];
    end

    fig = figure('visible','on','color','w','position',[100 100 1200 750], ...
        'Name',['Current response: ' case_labels{c}]);

    % ===== (1,1) Real part: I_h vs I_i =====
    subplot(2,2,1);
    plot(order, real(data.I_h), '-',  'color', col_homog,   'linewidth', 1.5); hold on;
    plot(order, real(data.I_i), '--', 'color', col_inhomog, 'linewidth', 1.5);
    grid on;
    ylim(ylims(1,:));
    xlabel('Pair index (acquisition order)', 'fontsize', 12);
    ylabel('Re(I) [A]', 'fontsize', 12);
    legend({'I_h (homogen)', 'I_i (inhomogen)'}, 'location', 'best');

    % ===== (1,2) Imaginary part: I_h vs I_i =====
    subplot(2,2,2);
    plot(order, imag(data.I_h), '-',  'color', col_homog,   'linewidth', 1.5); hold on;
    plot(order, imag(data.I_i), '--', 'color', col_inhomog, 'linewidth', 1.5);
    grid on;
    ylim(ylims(2,:));
    xlabel('Pair index (acquisition order)', 'fontsize', 12);
    ylabel('Im(I) [A]', 'fontsize', 12);
    legend({'I_h (homogen)', 'I_i (inhomogen)'}, 'location', 'best');

    % ===== (2,1) Real part of difference =====
    subplot(2,2,3);
    plot(order, real(dI), '-', 'color', col_diff, 'linewidth', 1.5);
    grid on;
    ylim(ylims(3,:));
    xlabel('Pair index (acquisition order)', 'fontsize', 12);
    ylabel('\DeltaRe(I) [A]', 'fontsize', 12);
    legend({'\DeltaI = I_i - I_h'}, 'location', 'best');

    % ===== (2,2) Imaginary part of difference =====
    subplot(2,2,4);
    plot(order, imag(dI), '-', 'color', col_diff, 'linewidth', 1.5);
    grid on;
    ylim(ylims(4,:));
    xlabel('Pair index (acquisition order)', 'fontsize', 12);
    ylabel('\DeltaIm(I) [A]', 'fontsize', 12);
    legend({'\DeltaI = I_i - I_h'}, 'location', 'best');

    base = case_files{c};
    drawnow;
    fprintf('Displayed current-response figure: %s\n',base);
end

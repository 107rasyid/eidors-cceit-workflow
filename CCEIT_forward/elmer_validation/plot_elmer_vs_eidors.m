function plot_elmer_vs_eidors()
% PLOT_ELMER_VS_EIDORS Plot comparison between Elmer and EIDORS B6 results.
% Purpose: visualize 120-pair admittance agreement for validation.
% Inputs: elmer_B6_120_pairs.mat and AB_A3_B6_coarse_results.mat.
% Outputs: PNG figure with magnitude, phase, and scatter comparison.

script_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(script_dir);

elmer_file = fullfile(script_dir, 'results', 'elmer_B6_120_pairs.mat');
eidors_file = fullfile(project_root, 'results', 'AB_A3_B6_coarse_results.mat');

if ~isfile(elmer_file)
    error('plot_elmer_vs_eidors: run collect_B6_Elmer_120_pairs first');
end
if ~isfile(eidors_file)
    error('plot_elmer_vs_eidors: run A3/B6 coarse comparison first');
end

E = load(elmer_file);
R = load(eidors_file);

y_elmer = E.y_pair;
y_eidors = R.y_B;
pairs = E.pairs;

if length(y_elmer) ~= length(y_eidors)
    error('plot_elmer_vs_eidors: pair count mismatch');
end

Y_mag_elmer = abs(y_elmer);
Y_mag_eidors = abs(y_eidors);
Y_phase_elmer = angle(y_elmer) * 180/pi;
Y_phase_eidors = angle(y_eidors) * 180/pi;

delta_mag = abs(Y_mag_elmer - Y_mag_eidors) ./ Y_mag_eidors;
delta_phase = abs(Y_phase_elmer - Y_phase_eidors);

fig = figure('Position', [100 100 1400 900]);

% Plot 1: Magnitude comparison
subplot(2,3,1);
semilogy(1:length(y_elmer), Y_mag_elmer, 'b-', 'LineWidth', 1.5);
hold on;
semilogy(1:length(y_eidors), Y_mag_eidors, 'r--', 'LineWidth', 1.5);
xlabel('Pair index');
ylabel('|Y| (S/m)');
title('Admittance Magnitude');
legend('Elmer', 'EIDORS B6', 'Location', 'best');
grid on;

% Plot 2: Phase comparison
subplot(2,3,2);
plot(1:length(y_elmer), Y_phase_elmer, 'b-', 'LineWidth', 1.5);
hold on;
plot(1:length(y_eidors), Y_phase_eidors, 'r--', 'LineWidth', 1.5);
xlabel('Pair index');
ylabel('Phase (degrees)');
title('Admittance Phase');
legend('Elmer', 'EIDORS B6', 'Location', 'best');
grid on;

% Plot 3: Magnitude error
subplot(2,3,3);
semilogy(1:length(y_elmer), delta_mag*100, 'k-', 'LineWidth', 1.5);
xlabel('Pair index');
ylabel('Relative error (%)');
title('Magnitude Relative Error');
grid on;

% Plot 4: Phase error
subplot(2,3,4);
plot(1:length(y_elmer), delta_phase, 'k-', 'LineWidth', 1.5);
xlabel('Pair index');
ylabel('Phase error (degrees)');
title('Phase Absolute Error');
grid on;

% Plot 5: Scatter magnitude
subplot(2,3,5);
loglog(Y_mag_eidors, Y_mag_elmer, 'bo', 'MarkerSize', 6);
hold on;
loglog([min(Y_mag_eidors) max(Y_mag_eidors)], [min(Y_mag_eidors) max(Y_mag_eidors)], 'k--', 'LineWidth', 1.5);
xlabel('EIDORS B6 |Y| (S/m)');
ylabel('Elmer |Y| (S/m)');
title('Magnitude Scatter');
grid on;
axis equal;

% Plot 6: Scatter phase
subplot(2,3,6);
plot(Y_phase_eidors, Y_phase_elmer, 'bo', 'MarkerSize', 6);
hold on;
plot([min(Y_phase_eidors) max(Y_phase_eidors)], [min(Y_phase_eidors) max(Y_phase_eidors)], 'k--', 'LineWidth', 1.5);
xlabel('EIDORS B6 Phase (degrees)');
ylabel('Elmer Phase (degrees)');
title('Phase Scatter');
grid on;
axis equal;

sgtitle('Elmer vs EIDORS B6 Validation (120 pairs)', 'FontSize', 14, 'FontWeight', 'bold');

output_dir = fullfile(script_dir, 'results');
if ~isfolder(output_dir), mkdir(output_dir); end
output_file = fullfile(output_dir, 'elmer_vs_eidors_comparison.png');
print(fig, output_file, '-dpng', '-r200');
fprintf('Plot saved: %s\n', output_file);
end

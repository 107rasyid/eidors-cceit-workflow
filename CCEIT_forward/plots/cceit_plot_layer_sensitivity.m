function output_paths = cceit_plot_layer_sensitivity(P0, res, outdir, dpi)
% CCEIT_PLOT_LAYER_SENSITIVITY Create three standalone layer-sweep figures.
% Purpose: show Delta_p separately against thickness, permittivity, and conductivity.
% Inputs: P0 baseline parameters, res A2 sweep struct, output folder, PNG dpi.
% Outputs: cell array of paths to the three PNG files; figures remain open.
% Manuscript ref: Section IV.D, Model A layer-parameter sensitivity.

idx_d = find(strcmp({res.name}, 'd'), 1);
idx_epsd = find(strcmp({res.name}, 'epsr_d'), 1);
idx_sigd = find(strcmp({res.name}, 'sigma_d'), 1);
if isempty(idx_d) || isempty(idx_epsd) || isempty(idx_sigd)
    error('cceit_plot_layer_sensitivity: required layer sweeps are missing');
end

d_values = res(idx_d).vals(:)*1e3;
d_delta = res(idx_d).delta(:);
epsd_values = res(idx_epsd).vals(:);
epsd_delta = res(idx_epsd).delta(:);
sigma_d_values = res(idx_sigd).vals(:);
sigma_d_delta = res(idx_sigd).delta(:);
sigma_labels = cell(size(sigma_d_values));
for k = 1:numel(sigma_d_values)
    if sigma_d_values(k) == 0
        sigma_labels{k} = '0';
    else
        sigma_labels{k} = sprintf('10^{%d}', round(log10(sigma_d_values(k))));
    end
end

base_color = [0.12 0.12 0.12];
sweep_color = [0.12 0.43 0.70];
output_paths = cell(1,3);

fig = figure('Name','Layer thickness sensitivity', 'Visible','on', ...
    'Units','pixels', 'Position',[100 100 900 300], ...
    'Color','w', 'PaperPositionMode','auto');
ax = axes('Parent',fig);
plot(ax,d_values,d_delta,'-o','Color',sweep_color, ...
    'MarkerFaceColor','w','MarkerSize',7,'LineWidth',1.7);
hold(ax,'on'); grid(ax,'on'); box(ax,'on');
base_idx = find(abs(d_values-P0.d*1e3) < 1e-9,1);
if ~isempty(base_idx)
    plot(ax,d_values(base_idx),d_delta(base_idx),'d', ...
        'Color',base_color,'MarkerFaceColor',base_color,'MarkerSize',8);
end
xlabel(ax,'Layer thickness d (mm)');
ylabel(ax,'\Delta_p');
title(ax,'Layer thickness sensitivity (500 kHz)');
set(ax,'XTick',d_values,'FontSize',11,'LineWidth',0.9);
output_paths{1} = fullfile(outdir,'fig4b_layer_thickness.png');
print(fig,'-dpng',sprintf('-r%d',dpi),output_paths{1});
fprintf('Saved: %s\n',output_paths{1});

fig = figure('Name','Layer permittivity sensitivity', 'Visible','on', ...
    'Units','pixels', 'Position',[120 120 900 300], ...
    'Color','w', 'PaperPositionMode','auto');
ax = axes('Parent',fig);
plot(ax,epsd_values,epsd_delta,'-o','Color',sweep_color, ...
    'MarkerFaceColor','w','MarkerSize',7,'LineWidth',1.7);
hold(ax,'on'); grid(ax,'on'); box(ax,'on');
base_idx = find(abs(epsd_values-P0.epsr_d) < 1e-12,1);
if ~isempty(base_idx)
    plot(ax,epsd_values(base_idx),epsd_delta(base_idx),'d', ...
        'Color',base_color,'MarkerFaceColor',base_color,'MarkerSize',8);
end
xlabel(ax,'Layer relative permittivity \epsilon_{r,d}');
ylabel(ax,'\Delta_p');
title(ax,'Layer permittivity sensitivity (500 kHz)');
set(ax,'XTick',epsd_values,'FontSize',11,'LineWidth',0.9);
output_paths{2} = fullfile(outdir,'fig4b_layer_permittivity.png');
print(fig,'-dpng',sprintf('-r%d',dpi),output_paths{2});
fprintf('Saved: %s\n',output_paths{2});

fig = figure('Name','Layer conductivity sensitivity', 'Visible','on', ...
    'Units','pixels', 'Position',[140 140 900 300], ...
    'Color','w', 'PaperPositionMode','auto');
ax = axes('Parent',fig);
x_sigma = 1:numel(sigma_d_values);
plot(ax,x_sigma,sigma_d_delta,'-o','Color',sweep_color, ...
    'MarkerFaceColor','w','MarkerSize',7,'LineWidth',1.7);
hold(ax,'on'); grid(ax,'on'); box(ax,'on');
base_idx = find(abs(sigma_d_values-P0.sigma_d) < 1e-15,1);
if ~isempty(base_idx)
    plot(ax,x_sigma(base_idx),sigma_d_delta(base_idx),'d', ...
        'Color',base_color,'MarkerFaceColor',base_color,'MarkerSize',8);
end
set(ax,'XTick',x_sigma,'XTickLabel',sigma_labels, ...
    'FontSize',10,'LineWidth',0.9);
xlabel(ax,'Layer conductivity \sigma_d (S/m)');
ylabel(ax,'\Delta_p');
title(ax,'Layer conductivity sensitivity (500 kHz)');
output_paths{3} = fullfile(outdir,'fig4b_layer_conductivity.png');
print(fig,'-dpng',sprintf('-r%d',dpi),output_paths{3});
fprintf('Saved: %s\n',output_paths{3});
end

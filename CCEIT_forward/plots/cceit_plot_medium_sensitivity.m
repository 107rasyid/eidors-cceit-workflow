function output_paths = cceit_plot_medium_sensitivity(P0, R, outdir, dpi)
% CCEIT_PLOT_MEDIUM_SENSITIVITY Plot medium sweeps in one figure per frequency.
% Purpose: show conductivity and permittivity sweeps without crowding panels.
% Inputs: P0 baseline parameters, R A3 results, output folder, PNG dpi.
% Outputs: cell array of frequency-specific PNG paths; figures remain open.
% Manuscript ref: Section IV.D, Model A medium-parameter sensitivity.

if isempty(R) || ~isfield(R, 'Delta_p_sig') || ~isfield(R, 'Delta_p_eps')
    error('cceit_plot_medium_sensitivity: incomplete A3 sweep results');
end
d_values = unique([R.d]);
f_values = unique([R.f]);
colors = lines(numel(d_values));
markers = {'o','s','^','d','v','>'};
lefts  = [0.08 0.56];
width  = 0.37;
height = 0.60;
bottom = 0.15;
pad    = 1.03;   % padding kiri/kanan (log scale => perkalian). 1.01 = lebih rapat, 1.05 = lebih longgar
output_paths = cell(1,numel(f_values));

for fi = 1:numel(f_values)
    frequency_kHz = round(f_values(fi)/1e3);
    fig = figure('Name',sprintf('Medium sensitivity, %d kHz',frequency_kHz), ...
        'Units','pixels','Position',[80+30*fi 80+20*fi 1450 360], ...
        'Color','w','Visible','on','PaperPositionMode','auto');
    legend_handles = cell(1,numel(d_values));
    legend_labels  = cell(1,numel(d_values));

    ax_sigma = axes('Parent',fig,'Position',[lefts(1) bottom width height]);
    hold(ax_sigma,'on'); grid(ax_sigma,'on'); box(ax_sigma,'on');
    ax_eps = axes('Parent',fig,'Position',[lefts(2) bottom width height]);
    hold(ax_eps,'on'); grid(ax_eps,'on'); box(ax_eps,'on');

    % --- track min/max data untuk xlim yang rapat ---
    sig_min = inf; sig_max = -inf;
    eps_min = inf; eps_max = -inf;

    for di = 1:numel(d_values)
        idx = find(abs([R.d]-d_values(di)) < 1e-12 & ...
            abs([R.f]-f_values(fi)) < 1e-6,1);
        if isempty(idx), continue; end

        sig_x = R(idx).sig_vals(:);
        sig_y = R(idx).Delta_p_sig(:);
        [sig_x,order] = sort(sig_x);
        sig_y = sig_y(order);
        marker = markers{1+mod(di-1,numel(markers))};
        legend_handles{di} = semilogx(ax_sigma,sig_x,sig_y,['-' marker], ...
            'Color',colors(di,:),'MarkerFaceColor','w', ...
            'MarkerSize',7,'LineWidth',1.7);
        legend_labels{di} = sprintf('d = %.1f mm',d_values(di)*1e3);
        sig_min = min(sig_min, min(sig_x));
        sig_max = max(sig_max, max(sig_x));

        eps_x = R(idx).eps_vals(:);
        eps_y = R(idx).Delta_p_eps(:);
        [eps_x,order] = sort(eps_x);
        eps_y = eps_y(order);
        semilogx(ax_eps,eps_x,eps_y,['-' marker], ...
            'Color',colors(di,:),'MarkerFaceColor','w', ...
            'MarkerSize',7,'LineWidth',1.7);
        eps_min = min(eps_min, min(eps_x));
        eps_max = max(eps_max, max(eps_x));
    end

    % --- xlim ketat: sisakan hanya 'pad' di kiri & kanan data terakhir ---
    if isfinite(sig_min) && sig_max > sig_min
        xlim(ax_sigma, [sig_min/pad, sig_max*pad]);
    end
    if isfinite(eps_min) && eps_max > eps_min
        xlim(ax_eps, [eps_min/pad, eps_max*pad]);
    end

    set([ax_sigma ax_eps],'FontSize',11,'LineWidth',0.9);
    xlabel(ax_sigma,'Tissue conductivity \sigma (S/m)');
    ylabel(ax_sigma,'\Delta_p');
    title(ax_sigma,sprintf('Conductivity sweep, f = %d kHz',frequency_kHz));
    xlabel(ax_eps,'Tissue relative permittivity \epsilon_r');
    ylabel(ax_eps,'\Delta_p');
    title(ax_eps,sprintf('Permittivity sweep, f = %d kHz',frequency_kHz));

    have_legend = ~cellfun(@isempty,legend_handles);
    if any(have_legend)
        % A lightweight axes-based key avoids Octave's inconsistent
        % annotation and legend-placement behavior.
        visible_items = find(have_legend);
        n_items = numel(visible_items);
        legend_ax = axes('Parent',fig,'Position',[0.10 0.86 0.80 0.06], ...
            'XLim',[0 1],'YLim',[0 1],'Visible','off');
        hold(legend_ax,'on');
        item_width = 0.96/n_items;
        first_x = 0.02;
        for li = 1:n_items
            di = visible_items(li);
            x0 = first_x+(li-1)*item_width;
            plot(legend_ax,[x0 x0+0.045],[0.5 0.5],'-', ...
                'Color',colors(di,:),'LineWidth',1.8);
            text(legend_ax,x0+0.055,0.5,legend_labels{di}, ...
                'FontSize',10,'VerticalAlignment','middle');
        end
        axis(legend_ax,'off');
    end

    output_paths{fi} = fullfile(outdir, ...
        sprintf('fig4c_tissue_%dkHz.png',frequency_kHz));
    drawnow;
    print(fig,'-dpng',sprintf('-r%d',dpi),output_paths{fi});
    fprintf('Saved medium sensitivity figure: %s\n',output_paths{fi});
end
end

function clock_gui()
    fig = uifigure('Name', '时钟', 'Position', [400 200 420 500], ...
        'Color', [0.08 0.08 0.12], 'Resize', 'off');

    % ── 数字时间显示 ──────────────────────────────────────
    digitalLabel = uilabel(fig, 'Text', '00:00:00', ...
        'Position', [0 420 420 55], ...
        'FontSize', 42, 'FontWeight', 'bold', ...
        'FontColor', [0.9 0.95 1.0], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor', [0.08 0.08 0.12]);

    dateLabel = uilabel(fig, 'Text', '', ...
        'Position', [0 395 420 28], ...
        'FontSize', 14, ...
        'FontColor', [0.55 0.7 0.9], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor', [0.08 0.08 0.12]);

    % ── 模拟表盘（axes） ─────────────────────────────────
    ax = uiaxes(fig, 'Position', [20 60 380 340]);
    ax.Color          = [0.08 0.08 0.12];
    ax.XColor         = [0.08 0.08 0.12];
    ax.YColor         = [0.08 0.08 0.12];
    ax.DataAspectRatio = [1 1 1];
    axis(ax, [-1.2 1.2 -1.2 1.2]);
    hold(ax, 'on');

    % 外圆表盘
    theta = linspace(0, 2*pi, 360);
    fill(ax, cos(theta), sin(theta), [0.13 0.13 0.2], ...
        'EdgeColor', [0.35 0.55 0.85], 'LineWidth', 3);

    % 刻度线
    for i = 1:60
        angle = pi/2 - (i-1)*2*pi/60;
        if mod(i,5) == 0
            r1 = 0.82; r2 = 0.95; lw = 2.5; col = [0.8 0.85 1.0];
        else
            r1 = 0.88; r2 = 0.95; lw = 1;   col = [0.4 0.45 0.6];
        end
        plot(ax, [r1*cos(angle) r2*cos(angle)], ...
                 [r1*sin(angle) r2*sin(angle)], ...
            'Color', col, 'LineWidth', lw);
    end

    % 数字刻度 1~12
    for i = 1:12
        angle = pi/2 - (i-1)*2*pi/12;
        r = 0.72;
        text(ax, r*cos(angle), r*sin(angle), num2str(i), ...
            'Color', [0.85 0.9 1.0], 'FontSize', 13, ...
            'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', ...
            'VerticalAlignment', 'middle');
    end

    % 中心点
    fill(ax, 0.035*cos(theta), 0.035*sin(theta), [0.9 0.9 1.0], ...
        'EdgeColor', 'none');

    % ── 指针（初始化） ───────────────────────────────────
    hHour   = plot(ax, [0 0], [0 0], 'Color', [0.9 0.9 1.0],  'LineWidth', 5,   'LineStyle', '-');
    hMin    = plot(ax, [0 0], [0 0], 'Color', [0.6 0.8 1.0],  'LineWidth', 3.5, 'LineStyle', '-');
    hSec    = plot(ax, [0 0], [0 0], 'Color', [1.0 0.4 0.35], 'LineWidth', 1.5, 'LineStyle', '-');

    % 指针中心圆（压在最上层）
    plot(ax, 0, 0, 'o', 'MarkerSize', 7, 'MarkerFaceColor', [1 0.4 0.35], ...
        'MarkerEdgeColor', 'none');

    % ── 定时器 ───────────────────────────────────────────
    t = timer('ExecutionMode', 'fixedRate', 'Period', 1, ...
        'TimerFcn', @updateClock);
    start(t);
    updateClock();   % 立即刷新一次

    fig.CloseRequestFcn = @(~,~) cleanUp();

    % ── 回调 ─────────────────────────────────────────────
    function updateClock(~, ~)
        if ~isvalid(fig), stop(t); return, end

        now    = clock;
        H = now(4); M = now(5); S = round(now(6));
        if S == 60, S = 59; end

        % 数字时间
        digitalLabel.Text = sprintf('%02d:%02d:%02d', H, M, S);

        % 日期
        weekNames = {'周日','周一','周二','周三','周四','周五','周六'};
        wd = weekday(datetime('today'));
        dateLabel.Text = sprintf('%d年%02d月%02d日  %s', ...
            now(1), now(2), now(3), weekNames{wd});

        % 指针角度（从12点顺时针）→ 转为极坐标角度
        secAngle  = pi/2 - S      * 2*pi/60;
        minAngle  = pi/2 - (M + S/60)  * 2*pi/60;
        hourAngle = pi/2 - (mod(H,12) + M/60) * 2*pi/12;

        set(hSec,  'XData', [0, 0.90*cos(secAngle)],  'YData', [0, 0.90*sin(secAngle)]);
        set(hMin,  'XData', [0, 0.78*cos(minAngle)],  'YData', [0, 0.78*sin(minAngle)]);
        set(hHour, 'XData', [0, 0.55*cos(hourAngle)], 'YData', [0, 0.55*sin(hourAngle)]);
    end

    function cleanUp()
        if isvalid(t), stop(t); delete(t); end
        delete(fig);
    end
end

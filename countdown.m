function countdown()
    fig = uifigure('Name', '倒计时', 'Position', [400 250 420 380], ...
        'Color', [0.08 0.08 0.12], 'Resize', 'off');

    % ── 标题 ──────────────────────────────────────────────
    uilabel(fig, 'Text', '⏱  倒计时器', ...
        'Position', [0 330 420 35], ...
        'FontSize', 18, 'FontWeight', 'bold', ...
        'FontColor', [0.6 0.8 1.0], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor', [0.08 0.08 0.12]);

    % ── 时间显示 ──────────────────────────────────────────
    timeLabel = uilabel(fig, 'Text', '00 : 00 : 00', ...
        'Position', [20 210 380 100], ...
        'FontSize', 58, 'FontWeight', 'bold', ...
        'FontColor', [1 1 1], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor', [0.08 0.08 0.12]);

    % ── 输入区 ────────────────────────────────────────────
    labelStyle = {'FontSize', 13, 'FontColor', [0.7 0.7 0.7], ...
        'BackgroundColor', [0.08 0.08 0.12], 'HorizontalAlignment', 'center'};

    uilabel(fig, 'Text', '时', 'Position', [50  170 60 22], labelStyle{:});
    uilabel(fig, 'Text', '分', 'Position', [180 170 60 22], labelStyle{:});
    uilabel(fig, 'Text', '秒', 'Position', [310 170 60 22], labelStyle{:});

    inputStyle = {'FontSize', 20, 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor', [0.18 0.18 0.25], ...
        'FontColor', [1 1 1]};

    hInput = uieditfield(fig, 'numeric', 'Value', 0, ...
        'Position', [35 140 90 38], 'Limits', [0 99], inputStyle{:});
    mInput = uieditfield(fig, 'numeric', 'Value', 5, ...
        'Position', [165 140 90 38], 'Limits', [0 59], inputStyle{:});
    sInput = uieditfield(fig, 'numeric', 'Value', 0, ...
        'Position', [295 140 90 38], 'Limits', [0 59], inputStyle{:});

    % ── 按钮 ──────────────────────────────────────────────
    btnStart  = uibutton(fig, 'Text', '开始', ...
        'Position', [30  75 105 45], ...
        'FontSize', 16, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.2 0.75 0.45], 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @startTimer);

    btnPause  = uibutton(fig, 'Text', '暂停', ...
        'Position', [157 75 105 45], ...
        'FontSize', 16, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.9 0.65 0.1], 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @pauseTimer);

    btnReset  = uibutton(fig, 'Text', '重置', ...
        'Position', [284 75 105 45], ...
        'FontSize', 16, 'FontWeight', 'bold', ...
        'BackgroundColor', [0.8 0.25 0.25], 'FontColor', [1 1 1], ...
        'ButtonPushedFcn', @resetTimer);

    % ── 状态栏 ────────────────────────────────────────────
    statusLabel = uilabel(fig, 'Text', '请设置时间后点击开始', ...
        'Position', [0 28 420 28], ...
        'FontSize', 13, 'FontColor', [0.55 0.55 0.55], ...
        'HorizontalAlignment', 'center', ...
        'BackgroundColor', [0.08 0.08 0.12]);

    % 进度条背景
    uilabel(fig, 'Text', '', 'Position', [20 18 380 8], ...
        'BackgroundColor', [0.2 0.2 0.28]);
    progressBar = uilabel(fig, 'Text', '', 'Position', [20 18 380 8], ...
        'BackgroundColor', [0.2 0.75 0.45]);

    % ── 状态变量 ──────────────────────────────────────────
    state.remaining = 0;
    state.total     = 0;
    state.running   = false;
    state.timer     = [];

    % ── 回调函数 ──────────────────────────────────────────
    function startTimer(~, ~)
        if state.running
            return
        end
        if state.remaining == 0
            h = floor(hInput.Value);
            m = floor(mInput.Value);
            s = floor(sInput.Value);
            total = h*3600 + m*60 + s;
            if total <= 0
                statusLabel.Text = '⚠  请设置大于 0 的时间';
                statusLabel.FontColor = [1 0.4 0.4];
                return
            end
            state.remaining = total;
            state.total     = total;
        end
        state.running = true;
        statusLabel.Text = '▶  计时中...';
        statusLabel.FontColor = [0.4 1 0.6];
        setInputEnable('off');

        state.timer = timer('ExecutionMode', 'fixedRate', 'Period', 1, ...
            'TimerFcn', @timerTick, ...
            'StopFcn',  @timerStopped);
        start(state.timer);
    end

    function pauseTimer(~, ~)
        if ~state.running
            return
        end
        state.running = false;
        if ~isempty(state.timer) && isvalid(state.timer)
            stop(state.timer);
            delete(state.timer);
            state.timer = [];
        end
        statusLabel.Text = '⏸  已暂停';
        statusLabel.FontColor = [1 0.8 0.3];
    end

    function resetTimer(~, ~)
        if ~isempty(state.timer) && isvalid(state.timer)
            stop(state.timer);
            delete(state.timer);
            state.timer = [];
        end
        state.remaining = 0;
        state.total     = 0;
        state.running   = false;
        timeLabel.Text      = '00 : 00 : 00';
        timeLabel.FontColor = [1 1 1];
        progressBar.Position(3) = 0;
        statusLabel.Text      = '已重置，请重新设置时间';
        statusLabel.FontColor = [0.55 0.55 0.55];
        setInputEnable('on');
    end

    function timerTick(~, ~)
        if ~isvalid(fig)
            stop(state.timer); return
        end
        state.remaining = state.remaining - 1;
        updateDisplay();

        if state.remaining <= 0
            stop(state.timer);
        end
    end

    function timerStopped(~, ~)
        if ~isvalid(fig), return, end
        state.running = false;
        if state.remaining <= 0
            timeLabel.Text      = '00 : 00 : 00';
            timeLabel.FontColor = [1 0.4 0.4];
            statusLabel.Text    = '✔  时间到！';
            statusLabel.FontColor = [1 0.4 0.4];
            progressBar.Position(3) = 0;
            progressBar.BackgroundColor = [1 0.4 0.4];
            setInputEnable('on');
            % 闪烁提示
            for k = 1:6
                pause(0.3);
                if ~isvalid(fig), return, end
                if mod(k,2)==0
                    timeLabel.FontColor = [1 0.4 0.4];
                else
                    timeLabel.FontColor = [1 1 1];
                end
            end
            if isvalid(fig)
                progressBar.BackgroundColor = [0.2 0.75 0.45];
            end
        end
    end

    function updateDisplay()
        h = floor(state.remaining / 3600);
        m = floor(mod(state.remaining, 3600) / 60);
        s = mod(state.remaining, 60);
        timeLabel.Text = sprintf('%02d : %02d : %02d', h, m, s);

        % 最后 10 秒变红
        if state.remaining <= 10
            timeLabel.FontColor = [1 0.35 0.35];
        elseif state.remaining <= 60
            timeLabel.FontColor = [1 0.75 0.2];
        else
            timeLabel.FontColor = [1 1 1];
        end

        % 进度条
        ratio = state.remaining / state.total;
        progressBar.Position(3) = max(0, round(380 * ratio));
    end

    function setInputEnable(onoff)
        hInput.Enable = onoff;
        mInput.Enable = onoff;
        sInput.Enable = onoff;
    end

    % 关闭窗口时清理 timer
    fig.CloseRequestFcn = @(~,~) cleanUp();
    function cleanUp()
        if ~isempty(state.timer) && isvalid(state.timer)
            stop(state.timer);
            delete(state.timer);
        end
        delete(fig);
    end
end

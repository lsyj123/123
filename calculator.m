function calculator()
    fig = uifigure('Name', '计算器', 'Position', [400 200 340 520], ...
        'Color', [0.15 0.15 0.15], 'Resize', 'off');

    % 显示屏
    display = uitextarea(fig, ...
        'Position', [15 430 310 75], ...
        'FontSize', 28, ...
        'FontWeight', 'bold', ...
        'HorizontalAlignment', 'right', ...
        'BackgroundColor', [0.1 0.1 0.1], ...
        'FontColor', [1 1 1], ...
        'Editable', 'off', ...
        'Value', {'0'});

    % 存储计算状态
    state.expr      = '';
    state.display   = '0';
    state.newNum    = true;
    state.lastResult = '';

    % 按钮定义: {标签, 列, 行, 宽度(格), 背景色, 字体色}
    btnDefs = {
        'AC',    1, 5, 1, [0.6 0.6 0.6],   [0 0 0];
        '+/-',   2, 5, 1, [0.6 0.6 0.6],   [0 0 0];
        '%',     3, 5, 1, [0.6 0.6 0.6],   [0 0 0];
        '÷',     4, 5, 1, [1.0 0.62 0.04], [1 1 1];
        '7',     1, 4, 1, [0.25 0.25 0.25],[1 1 1];
        '8',     2, 4, 1, [0.25 0.25 0.25],[1 1 1];
        '9',     3, 4, 1, [0.25 0.25 0.25],[1 1 1];
        '×',     4, 4, 1, [1.0 0.62 0.04], [1 1 1];
        '4',     1, 3, 1, [0.25 0.25 0.25],[1 1 1];
        '5',     2, 3, 1, [0.25 0.25 0.25],[1 1 1];
        '6',     3, 3, 1, [0.25 0.25 0.25],[1 1 1];
        '-',     4, 3, 1, [1.0 0.62 0.04], [1 1 1];
        '1',     1, 2, 1, [0.25 0.25 0.25],[1 1 1];
        '2',     2, 2, 1, [0.25 0.25 0.25],[1 1 1];
        '3',     3, 2, 1, [0.25 0.25 0.25],[1 1 1];
        '+',     4, 2, 1, [1.0 0.62 0.04], [1 1 1];
        '0',     1, 1, 2, [0.25 0.25 0.25],[1 1 1];
        '.',     3, 1, 1, [0.25 0.25 0.25],[1 1 1];
        '=',     4, 1, 1, [1.0 0.62 0.04], [1 1 1];
    };

    gap  = 5;
    btnW = 75;
    btnH = 65;
    startX = 15;
    startY = 15;

    for k = 1:size(btnDefs, 1)
        label   = btnDefs{k,1};
        col     = btnDefs{k,2};
        row     = btnDefs{k,3};
        span    = btnDefs{k,4};
        bgColor = btnDefs{k,5};
        fgColor = btnDefs{k,6};

        x = startX + (col-1)*(btnW+gap);
        y = startY + (row-1)*(btnH+gap);
        w = span*btnW + (span-1)*gap;

        uibutton(fig, ...
            'Text', label, ...
            'Position', [x y w btnH], ...
            'FontSize', 22, ...
            'FontWeight', 'bold', ...
            'BackgroundColor', bgColor, ...
            'FontColor', fgColor, ...
            'ButtonPushedFcn', @(btn,~) onButton(label));
    end

    % 科学计算栏（第二行扩展）
    sciDefs = {
        'sin',  1; 'cos',  2; 'tan',  3; 'log', 4;
        'sqrt', 1; 'x²',   2; '1/x',  3; 'π',   4;
    };
    sciRows = {6, 7};
    for r = 1:2
        row = sciRows{r};
        for c = 1:4
            idx = (r-1)*4 + c;
            lbl = sciDefs{idx, 1};
            x = startX + (c-1)*(btnW+gap);
            y = startY + (row-1)*(btnH+gap);
            uibutton(fig, ...
                'Text', lbl, ...
                'Position', [x y btnW btnH], ...
                'FontSize', 16, ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [0.18 0.35 0.55], ...
                'FontColor', [1 1 1], ...
                'ButtonPushedFcn', @(btn,~) onButton(lbl));
        end
    end

    % 调整窗口高度以容纳科学按钮
    fig.Position(4) = 690;
    display.Position(2) = 600;

    % ── 回调函数 ──────────────────────────────────────────
    function onButton(label)
        switch label
            case 'AC'
                state.expr      = '';
                state.display   = '0';
                state.newNum    = true;
                state.lastResult = '';

            case '+/-'
                if ~strcmp(state.display, '0') && ~isempty(state.display)
                    if state.display(1) == '-'
                        state.display = state.display(2:end);
                    else
                        state.display = ['-', state.display];
                    end
                    % 替换表达式末尾数字
                    state.expr = replaceLastNumber(state.expr, state.display);
                end

            case '%'
                val = str2double(state.display);
                if ~isnan(val)
                    val = val / 100;
                    state.display = formatNum(val);
                    state.expr = replaceLastNumber(state.expr, state.display);
                end

            case {'÷','×','+','-'}
                opMap = containers.Map({'÷','×','+','-'}, {'/',  '*', '+', '-'});
                if state.newNum && ~isempty(state.expr)
                    % 替换末尾运算符
                    state.expr(end) = opMap(label);
                else
                    state.expr  = [state.expr, state.display, opMap(label)];
                    state.newNum = true;
                end

            case '='
                if ~isempty(state.expr) && ~state.newNum
                    fullExpr = [state.expr, state.display];
                elseif ~isempty(state.expr)
                    fullExpr = state.expr(1:end-1);
                else
                    fullExpr = state.display;
                end
                try
                    result = eval(fullExpr);
                    state.display    = formatNum(result);
                    state.lastResult = state.display;
                    state.expr       = '';
                    state.newNum     = true;
                catch
                    state.display = '错误';
                    state.expr    = '';
                    state.newNum  = true;
                end

            case '.'
                if state.newNum
                    state.display = '0.';
                    state.newNum  = false;
                elseif ~contains(state.display, '.')
                    state.display = [state.display, '.'];
                end

            case 'sin'
                applyFunc(@(x) sin(deg2rad(x)));
            case 'cos'
                applyFunc(@(x) cos(deg2rad(x)));
            case 'tan'
                applyFunc(@(x) tan(deg2rad(x)));
            case 'log'
                applyFunc(@(x) log10(x));
            case 'sqrt'
                applyFunc(@sqrt);
            case 'x²'
                applyFunc(@(x) x^2);
            case '1/x'
                applyFunc(@(x) 1/x);
            case 'π'
                state.display = formatNum(pi);
                state.newNum  = false;

            otherwise  % 数字
                if state.newNum || strcmp(state.display, '0')
                    state.display = label;
                    state.newNum  = false;
                else
                    state.display = [state.display, label];
                end
        end

        % 刷新显示
        updateDisplay();
    end

    function applyFunc(fn)
        val = str2double(state.display);
        if ~isnan(val)
            try
                result = fn(val);
                state.display    = formatNum(result);
                state.lastResult = state.display;
                state.expr       = '';
                state.newNum     = true;
            catch
                state.display = '错误';
                state.newNum  = true;
            end
        end
    end

    function updateDisplay()
        if length(state.display) > 12
            val = str2double(state.display);
            if ~isnan(val)
                state.display = formatNum(val);
            end
        end
        display.Value = {state.display};
    end

    function s = formatNum(val)
        if val == floor(val) && abs(val) < 1e15
            s = num2str(val, '%g');
        else
            s = num2str(val, 10);
            if length(s) > 12
                s = num2str(val, '%e');
            end
        end
    end

    function expr = replaceLastNumber(expr, newVal)
        tokens = regexp(expr, '(.*[-+*/])([^-+*/]*)$', 'tokens');
        if ~isempty(tokens)
            expr = [tokens{1}{1}, newVal];
        else
            expr = newVal;
        end
    end
end

% 复材板件模型修正
% 分层区域赋予内聚力材料性质
% 根据CT分析的孔隙率分布赋予孔隙材料性质
% 用于2D材料

%%
%参数定义

%%注意是否clear
clear;
editmode=3;   %1.读取模式 2.内聚力单元赋予模式 3.CT分布孔隙
matsaveFilename='10010045.mat';
matloadFilename='10010045.mat';

% 读取INP文件
inpFilename = 'qwe471.inp'; % 复材板件
oriFilename = 'qwe471.ori';

% CT孔隙率分布文件（见下方格式说明）
% 格式1: 逐点云数据  ctPorosityFilename = 'ct_porosity.csv';
% 格式2: 分层统计数据 ctPorosityFilename = 'ct_porosity_layers.csv';
ctPorosityFilename = 'ct_porosity.csv';

% CT数据格式选择: 'pointcloud' 或 'layerstat'
ctDataFormat = 'pointcloud';

% CT坐标方向映射（CT坐标 -> FEM坐标）
% 例如CT的Z轴对应FEM的Z轴（厚度方向）
ctMappingAxis = 'Z';   % 'X','Y','Z' 以哪个轴做主分布方向

%%==============
%%读取模式
%%==============

if editmode==1

    % 复制第一个文件
    if exist(inpFilename, 'file')
        fileContent = fileread(inpFilename);
        [filepath, name, ext] = fileparts(inpFilename);
        newFilename = fullfile(filepath, [name ext '.txt']);
        fid = fopen(newFilename, 'w');
        fprintf(fid, '%s', fileContent);
        fclose(fid);
        disp(['文件已复制为: ' newFilename]);
    else
        error(['文件 ' inpFilename ' 不存在']);
    end

    % 复制第二个文件
    if exist(oriFilename, 'file')
        fileContent = fileread(oriFilename);
        [filepath, name, ext] = fileparts(oriFilename);
        newFilename = fullfile(filepath, [name ext '.txt']);
        fid = fopen(newFilename, 'w');
        fprintf(fid, '%s', fileContent);
        fclose(fid);
        disp(['文件已复制为: ' newFilename]);
    else
        error(['文件 ' oriFilename ' 不存在']);
    end

    % 初始化存储对象
    nodes    = table();
    elements = table();
    elsets   = containers.Map();
    materials = struct();

    fid = fopen(inpFilename, 'r');
    totalLines = 0;
    while ~feof(fid)
        fgetl(fid);
        totalLines = totalLines + 1;
    end
    fclose(fid);

    fid = fopen(inpFilename, 'r');
    currentSection = '';
    currentLine    = 0;
    while ~feof(fid)
        line = strtrim(fgetl(fid));
        currentLine = currentLine + 1;
        if mod(currentLine, 10000) == 0
            fprintf('%d/%d\n', currentLine, totalLines);
        end
        if startsWith(line, '**'), continue; end
        if startsWith(line, '*')
            currentSection = line;
            continue;
        end

        if strcmp(currentSection, '*Node') && ~isempty(line)
            data = sscanf(line, '%f,%f,%f,%f');
            nodes = [nodes; table(data(1), data(2), data(3), data(4), ...
                'VariableNames', {'NodeID','X','Y','Z'})];
        end

        if strcmp(currentSection, '*Element, Type=C3D8R') && ~isempty(line)
            data = sscanf(line, '%f,%f,%f,%f,%f,%f,%f,%f,%f');
            elements = [elements; table(data(1), data(2:end)', ...
                'VariableNames', {'ElementID','Nodes'})];
        end

        if startsWith(currentSection, '*ElSet, ElSet')
            [~, elsetName] = strtok(currentSection, '=');
            elsetName = strrep(elsetName, 'elset=', '');
            elsetName = strtrim(elsetName);
            if ~isKey(elsets, elsetName)
                elsets(elsetName) = [];
            end
            if ~isempty(line)
                data = str2double(strsplit(line, ','));
                data = data(~isnan(data));
                elsets(elsetName) = [elsets(elsetName); data(:)];
            end
        end
    end
    fclose(fid);

    oriFilename = strcat(oriFilename, '.txt');
    oriData = readtable(oriFilename, 'Delimiter', ',', 'ReadVariableNames', false);
    oriData.Properties.VariableNames = {'ElementID','Dir1_X','Dir1_Y','Dir1_Z', ...
                                        'Dir2_X','Dir2_Y','Dir2_Z'};

    elsetCell = cell(length(keys(elsets)), 2);
    allKeys = keys(elsets);
    for i = 1:length(allKeys)
        elsetCell{i,1} = allKeys{i};
        elsetCell{i,2} = elsets(allKeys{i});
    end

    save(matsaveFilename);
    save(strcat(matsaveFilename, '.bak.mat'));
    disp('=== 数据读取完成 ===');


elseif editmode==3
%% ==================== 基于CT分布的孔隙生成 ====================
%
% CT数据文件格式说明：
%
% [格式1: pointcloud - 逐点孔隙率云数据]
%   CSV文件，每行: X, Y, Z, porosity
%   X/Y/Z 为CT扫描坐标（与FEM坐标系一致或通过ctMappingAxis映射）
%   porosity 为该点局部孔隙率（0~1之间）
%   示例:
%     0.0, 0.0, 0.1, 0.05
%     0.0, 0.0, 0.3, 0.08
%     ...
%
% [格式2: layerstat - 分层统计孔隙率]
%   CSV文件，每行: 层坐标, 孔隙率
%   层坐标对应 ctMappingAxis 方向
%   示例:
%     0.1, 0.03
%     0.2, 0.07
%     0.5, 0.12
%     ...
%
%================================================================

    load(matloadFilename);

    % 总体目标孔隙率（用于校正，若CT数据覆盖完整可不使用）
    globalPorosity = 0.0725285;

    %% -------------------- 获取 Matrix 单元及形心坐标 --------------------
    matrixElementIDs = elsets('=Matrix');
    elementMask      = ismember(elements.ElementID, matrixElementIDs);
    matrixSubset     = elements(elementMask, :);
    elementIDs       = matrixSubset.ElementID;
    numElems         = height(matrixSubset);

    fprintf('正在计算 Matrix 单元形心坐标...\n');
    centroids = computeCentroids(matrixSubset, nodes);
    fprintf('形心计算完成，共 %d 个单元\n', numElems);

    %% -------------------- 读取CT孔隙率分布并插值到每个单元 --------------------
    fprintf('正在读取CT孔隙率分布数据: %s\n', ctPorosityFilename);

    if strcmp(ctDataFormat, 'pointcloud')
        localPorosity = mapCTPointCloud(ctPorosityFilename, centroids, ctMappingAxis);
    elseif strcmp(ctDataFormat, 'layerstat')
        localPorosity = mapCTLayerStat(ctPorosityFilename, centroids, ctMappingAxis);
    else
        error('未知ctDataFormat，请选择 pointcloud 或 layerstat');
    end

    % 归一化：保证加权平均等于全局孔隙率
    meanLocal = mean(localPorosity);
    if meanLocal > 0
        localPorosity = localPorosity * (globalPorosity / meanLocal);
    end
    localPorosity = min(max(localPorosity, 0), 1);  % 截断到[0,1]

    fprintf('CT分布映射完成，局部孔隙率范围: [%.4f, %.4f]，均值: %.4f\n', ...
        min(localPorosity), max(localPorosity), mean(localPorosity));

    %% -------------------- 基于局部孔隙率加权随机抽样 --------------------
    % 每个单元以其局部孔隙率作为被选为孔隙单元的概率
    rng('shuffle');  % 随机种子
    randVals    = rand(numElems, 1);
    poreLogical = randVals < localPorosity;
    poreElementIDs = elementIDs(poreLogical);

    % 若总孔隙数为0（孔隙率极低），至少保留一个
    if isempty(poreElementIDs) && globalPorosity > 0
        [~, maxIdx] = max(localPorosity);
        poreElementIDs = elementIDs(maxIdx);
    end

    %% -------------------- 更新 Elsets --------------------
    elsets('=Pore')   = poreElementIDs;
    elsets('=Matrix') = setdiff(matrixElementIDs, poreElementIDs);

    actualPorosity = length(poreElementIDs) / numElems;
    fprintf('总 Matrix 单元数: %d\n',    numElems);
    fprintf('目标全局孔隙率:   %.4f\n',  globalPorosity);
    fprintf('实际孔隙率:       %.4f\n',  actualPorosity);
    fprintf('Pore 单元数:      %d\n',    length(poreElementIDs));
    fprintf('保留 Matrix 单元: %d\n',    length(elsets('=Matrix')));

    % 可视化孔隙分布（沿映射轴）
    visualizePoreDistribution(centroids, poreLogical, ctMappingAxis);

    if outputinp(inpFilename, nodes, elements, elsets, oriData)
        fprintf('输出正常\n');
    else
        error('输出错误');
    end

    endFile = fopen(strcat(inpFilename, '.ends.txt'), 'w');
    fclose(endFile);
    save(strcat(matsaveFilename, '.pore.mat'));
end


%% ================================================================
%% 子函数
%% ================================================================

% ----------------------------------------------------------------
% 计算单元形心坐标
% ----------------------------------------------------------------
function centroids = computeCentroids(elems, nodes)
    n = height(elems);
    centroids = zeros(n, 3);
    nodeXYZ = [nodes.X, nodes.Y, nodes.Z];
    nodeIDs = nodes.NodeID;

    for i = 1:n
        nodeList = elems.Nodes(i, :);
        [~, idx]  = ismember(nodeList, nodeIDs);
        coords    = nodeXYZ(idx, :);
        centroids(i, :) = mean(coords, 1);
    end
end

% ----------------------------------------------------------------
% CT点云数据插值（格式: X,Y,Z,porosity）
% 使用三维散点插值（linear），超出范围用最近邻外推
% ----------------------------------------------------------------
function localPorosity = mapCTPointCloud(filename, centroids, mappingAxis)
    ctData = readmatrix(filename);
    ctX = ctData(:,1);
    ctY = ctData(:,2);
    ctZ = ctData(:,3);
    ctP = ctData(:,4);

    fprintf('  CT点云数据点数: %d\n', length(ctP));

    % 三维插值到单元形心
    try
        F = scatteredInterpolant(ctX, ctY, ctZ, ctP, 'linear', 'nearest');
        localPorosity = F(centroids(:,1), centroids(:,2), centroids(:,3));
    catch
        warning('三维插值失败，退化为沿 %s 轴的一维插值', mappingAxis);
        localPorosity = mapCTLayerStatFromData( ...
            getAxisCoord(ctData(:,1:3), mappingAxis), ctP, ...
            getAxisCoord(centroids, mappingAxis));
    end
end

% ----------------------------------------------------------------
% CT分层统计数据插值（格式: 层坐标, 孔隙率）
% ----------------------------------------------------------------
function localPorosity = mapCTLayerStat(filename, centroids, mappingAxis)
    ctData = readmatrix(filename);
    ctCoord  = ctData(:,1);
    ctPoros  = ctData(:,2);

    fprintf('  CT分层数据层数: %d\n', length(ctCoord));

    elemCoord = getAxisCoord(centroids, mappingAxis);
    localPorosity = mapCTLayerStatFromData(ctCoord, ctPoros, elemCoord);
end

% ----------------------------------------------------------------
% 一维插值核心（线性插值 + 端部最近邻外推）
% ----------------------------------------------------------------
function localPorosity = mapCTLayerStatFromData(ctCoord, ctPoros, elemCoord)
    [ctCoord_s, sortIdx] = sort(ctCoord);
    ctPoros_s = ctPoros(sortIdx);

    % 去重
    [ctCoord_s, uIdx] = unique(ctCoord_s);
    ctPoros_s = ctPoros_s(uIdx);

    localPorosity = interp1(ctCoord_s, ctPoros_s, elemCoord, 'linear', 'extrap');
    localPorosity = max(localPorosity, 0);
end

% ----------------------------------------------------------------
% 获取形心在指定轴方向的坐标列
% ----------------------------------------------------------------
function coord = getAxisCoord(centroids, axis)
    switch upper(axis)
        case 'X', coord = centroids(:,1);
        case 'Y', coord = centroids(:,2);
        case 'Z', coord = centroids(:,3);
        otherwise, error('轴向 %s 无效，请输入 X/Y/Z', axis);
    end
end

% ----------------------------------------------------------------
% 可视化：沿映射轴的孔隙率分布
% ----------------------------------------------------------------
function visualizePoreDistribution(centroids, poreLogical, mappingAxis)
    coord = getAxisCoord(centroids, mappingAxis);

    figure('Name', 'CT孔隙率分布对比', 'Color', 'w');

    % 分层统计实际孔隙率
    nBins = 30;
    edges = linspace(min(coord), max(coord), nBins+1);
    binCenter = (edges(1:end-1) + edges(2:end)) / 2;
    actualPore = zeros(1, nBins);
    for k = 1:nBins
        inBin = coord >= edges(k) & coord < edges(k+1);
        if sum(inBin) > 0
            actualPore(k) = sum(poreLogical(inBin)) / sum(inBin);
        end
    end

    bar(binCenter, actualPore * 100, 'FaceColor', [0.2 0.5 0.8], 'EdgeColor', 'none');
    xlabel(sprintf('%s 轴坐标', mappingAxis), 'FontSize', 12);
    ylabel('孔隙率 (%)', 'FontSize', 12);
    title('各层实际孔隙率分布（基于CT插值）', 'FontSize', 13);
    grid on;
end

% ----------------------------------------------------------------
% 输出INP文件
% ----------------------------------------------------------------
function flag = outputinp(inpFilename, nodes, elements, elsets, oriData)
    inpFilename = strcat(inpFilename, '.pore');
    flag = 0;
    fprintf('=== 开始写入 ===\n');

    nodesFile = fopen(strcat(inpFilename, '.nodesandelements.txt'), 'w');
    fprintf(nodesFile, '*Node\n');
    for i = 1:height(nodes)
        fprintf(nodesFile, '%d, %.6f, %.6f, %.6f\n', ...
            nodes.NodeID(i), nodes.X(i), nodes.Y(i), nodes.Z(i));
    end
    elemData = [elements.ElementID, elements.Nodes];
    fprintf(nodesFile, '*Element, Type=C3D8R\n');
    fprintf(nodesFile, '%d, %d, %d, %d, %d, %d, %d, %d, %d\n', elemData');
    fclose(nodesFile);

    elementsFile = fopen(strcat(inpFilename, '.elements.txt'), 'w');
    fprintf(elementsFile, '*Element, Type=C3D8R\n');
    for i = 1:height(elements)
        fprintf(elementsFile, '%d, %d, %d, %d, %d, %d, %d, %d, %d\n', ...
            elements.ElementID(i), elements.Nodes(i,:)');
    end
    fclose(elementsFile);

    elsetsFile = fopen(strcat(inpFilename, '.elsets.txt'), 'w');
    for elsetName = keys(elsets)
        name = elsetName{1};
        fprintf(elsetsFile, '*ElSet, ElSet%s\n', name);
        elsetElements = elsets(name);
        for i = 1:16:length(elsetElements)
            line = elsetElements(i:min(i+15, end));
            fprintf(elsetsFile, '%d', line(1));
            for j = 2:length(line)
                fprintf(elsetsFile, ', %d', line(j));
            end
            fprintf(elsetsFile, '\n');
        end
    end
    fclose(elsetsFile);

    oriFile = fopen(strcat(inpFilename, '.ori.txt'), 'w');
    for i = 1:height(oriData)
        fprintf(oriFile, '%d, %.6f, %.6f, %.6f, %.6f, %.6f, %.6f\n', ...
            oriData.ElementID(i), oriData.Dir1_X(i), oriData.Dir1_Y(i), oriData.Dir1_Z(i), ...
            oriData.Dir2_X(i), oriData.Dir2_Y(i), oriData.Dir2_Z(i));
    end
    fclose(oriFile);

    flag = 1;
end

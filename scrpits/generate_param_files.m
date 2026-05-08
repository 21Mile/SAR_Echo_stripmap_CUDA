% 生成 SAR 配置文件及目标散射系数
% 输出：radar_params.json / running_params.json / target_list.bin / platform_pos.bin / waveforms_f0.bin
clc;close all;clear;
%% 0) 全局配置
cfg.output_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'data');
if ~exist(cfg.output_dir, 'dir'); mkdir(cfg.output_dir); end
% addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'func_matlab')); % 使用 myfft/myifft（居中 FFT）

running_param_file = fullfile(cfg.output_dir, 'running_params.json');
run_cfg = struct( ...
    'enable_concurrency', false, ...
    'logger_level', "INFO", ...
    'batch_cols', 16, ...
    'enable_random_phase', true, ...
    'enable_mixed_precision', true, ...
    'device_id', 0 ...
);
if isfile(running_param_file)
    try
        existing_run_cfg = jsondecode(fileread(running_param_file));
        fn = fieldnames(run_cfg);
        for idx = 1:numel(fn)
            key = fn{idx};
            if isfield(existing_run_cfg, key)
                run_cfg.(key) = existing_run_cfg.(key);
            end
        end
    catch ME
        warning('Failed to load existing running_params.json: %s', ME.message);
    end
end
cfg.enable_random_phase = run_cfg.enable_random_phase;

cfg.schema_version = 1;
cfg.c = 3e8;           % 光速 (m/s)
cfg.lambda = 0.03;     % 波长 (m)
cfg.fc = cfg.c / cfg.lambda; % 载频 (Hz)
cfg.B = 100e6;          % 信号带宽 (Hz)
cfg.fs = 150e6;         % 采样率 (Hz)
cfg.PRF = 2000;        % 脉冲重复频率 (Hz)
cfg.Tp = 15e-6;        % 脉冲宽度 (s) - 与点目标模板对齐
cfg.va = 450;          % 平台速度 (m/s) - 与点目标模板对齐
cfg.H = 3e3;           % 平台高度 (m)
cfg.R0 = 1e4;         % 参考斜距 (m)
cfg.Ba = 800;          % 方位向处理带宽系数
cfg.Ta = cfg.Ba * cfg.lambda / (2 * cfg.va) * cfg.R0 / cfg.va; % 方位向窗口时长
cfg.N_az = 4000;       % 方位脉冲数 - 与点目标模板对齐
cfg.Drange = 4e3;      % 斜距向场景尺寸 (m)
cfg.N_trans = 1;       % 发射波形数量
cfg.layout = 'col_major';
cfg.scatter_phase_seed = 20241129;
cfg.normalize_image = true;      % 若为 true，则按最大值归一化到 [0,1]
cfg.scatter_gamma = 1.0;          % <1 提升暗部；>1 提升亮部
cfg.scatter_amp_scale = 1.0;      % 散射系数幅度缩放（2~5 可增强对比度）
% $$\rho_r = \frac{c}{2B}$$
cfg.dx_az =cfg.va/cfg.PRF ;          % 方位向像素间距 (m)，例如 5 m；<=0 时使用默认孔径长度
% cfg.dx_az= cfg.dx_az-cfg.dx_az*0.05;
% $$\rho_a = \frac{v_a}{B_a}$$
cfg.dr_rg =  cfg.c/(2*cfg.fs) ;                    % 距离向像素间距 (m)，<=0 时使用 cfg.Drange 逻辑
% cfg.dr_rg = cfg.dr_rg- 0.05 *cfg.dr_rg;
%% 1) 推导网格（雷达“真实分辨率”）
pixel_r = cfg.c / (2 * cfg.fs);   % 距离采样间隔 ≈ 距离分辨单元
cfg.N_rg = round(cfg.Drange / pixel_r);
if mod(cfg.N_rg, 2) ~= 0, cfg.N_rg = cfg.N_rg + 1; end
cfg.N_rg = max(cfg.N_rg, 16);

ta = (-cfg.N_az / 2:cfg.N_az / 2 - 1) / cfg.PRF; % 方位时间轴居中
tr = ((0:cfg.N_rg - 1) - cfg.N_rg / 2) / cfg.fs; % 与 fftshift 对应的快时间网格

%% 2) 读取灰度图并映射到散射系数

img_path = fullfile(fileparts(mfilename('fullpath')), 'Jam_scence.png');
if ~isfile(img_path)
    error('Demo image not found: %s', img_path);
end

img = imread(img_path);
if ndims(img) == 3
    img_gray = rgb2gray(img);
else
    img_gray = img;
end

% 转为 double，范围 [0,1]
img_gray = im2double(img_gray);

% 可选全局归一化（与原逻辑一致）
if cfg.normalize_image && max(img_gray(:)) > 0
    img_gray = img_gray ./ max(img_gray(:));
end

% γ 校正 + 幅度缩放
img_gray = img_gray .^ cfg.scatter_gamma;
img_gray = img_gray * cfg.scatter_amp_scale;

% ------- 关键逻辑：只在“超出雷达网格”时才降采样，不做升采样 -------
[img_h, img_w] = size(img_gray);

% 先假设完全保留原分辨率
target_Nr  = img_h;
target_Naz = img_w;

% 如果某个方向比雷达网格更密，则在该方向上降采样到雷达网格大小
if img_h > cfg.N_rg || img_w > cfg.N_az
    target_Nr  = min(img_h, cfg.N_rg);
    target_Naz = min(img_w, cfg.N_az);
    img_gray   = imresize(img_gray, [target_Nr, target_Naz]);
end

% 此时：
% - 如果 img_h <= N_rg 且 img_w <= N_az：img_gray 尺寸保持不变（不升采样）
% - 否则：只做向下采样到不超过 N_rg × N_az

% ================= 场景坐标映射 =================
% 距离向：像素间距由 cfg.dr_rg 控制（若未设置则退回 Drange 逻辑）
if isfield(cfg, 'dr_rg') && cfg.dr_rg > 0
    % 用户指定了距离向像素间距：scene_rg_length = dr_rg * (target_Nr - 1)
    range_offsets = ((0:target_Nr-1) - (target_Nr-1)/2) * cfg.dr_rg;
else
    % 否则默认仍然用 cfg.Drange 覆盖整个场景
    range_offsets = linspace(-cfg.Drange / 2, cfg.Drange / 2, target_Nr);
end

a_s = cfg.R0 + range_offsets;                  % 每行对应的斜距
y_scene = sqrt(max(a_s .^ 2 - cfg.H ^ 2, 0));  % 地面投影 y 坐标

% ========= 方位向：像素间距由 dx_az 控制 =========
aperture_length = cfg.va * (cfg.N_az - 1) / cfg.PRF;

if isfield(cfg, 'dx_az') && cfg.dx_az > 0
    % 用户指定了方位向像素间距：scene_az_length = dx_az * (target_Naz - 1)
    scene_az_length = cfg.dx_az * (target_Naz - 1);
else
    % 否则默认仍然用整条孔径长度
    scene_az_length = aperture_length;
end

x_scene = linspace(-scene_az_length / 2, scene_az_length / 2, target_Naz);
[x_grid, y_grid] = meshgrid(x_scene, y_scene);


% 生成散射点（非零像素即为散射单元）
rng(cfg.scatter_phase_seed);
nonzero_idx = img_gray > 0;
amp = img_gray(nonzero_idx);

if cfg.enable_random_phase
    phi = rand(size(amp)) * 2 * pi;
else
    phi = zeros(size(amp));
end
coeff = amp .* exp(1j * phi);

x_target = x_grid(nonzero_idx);
y_target = y_grid(nonzero_idx);
z_target = zeros(size(x_target));

target_buf = zeros(1, 5 * numel(x_target));
target_buf(1:5:end) = x_target(:);
target_buf(2:5:end) = y_target(:);
target_buf(3:5:end) = z_target(:);
target_buf(4:5:end) = real(coeff(:));
target_buf(5:5:end) = imag(coeff(:));

%% 3) 生成波形矩阵与默认编码表（交替发射）
Kr = cfg.B / cfg.Tp;
% st = (abs(tr) <= cfg.Tp/2).*exp(1j * pi * Kr .* (tr .^ 2));

load("wf_s4_N2250_.mat");
commSignal=[zeros(4,875)  commSignal zeros(4,875)];
sf =myfft(commSignal, 2) ; % 居中频域波形

% 默认：所有发射通道复制同一 LFM 波形；如需自定义，直接修改 waveforms_matrix
% waveforms_matrix = repmat(sf, cfg.N_trans, 1);
waveforms_matrix=sf;
cfg.N_trans = size(waveforms_matrix, 1); % 根据波形矩阵行数推断 N_trans
if size(waveforms_matrix, 2) ~= cfg.N_rg
    error('waveforms_matrix 的列数必须等于 cfg.N_rg');
end

% 默认编码表：0 基索引，按 1,2,3,4... 轮换（交替发射）
codebook = mod(0:cfg.N_az-1, cfg.N_trans);

%% 4) 写入 radar_params.json
radar_params = struct( ...
    'schema_version', cfg.schema_version, ...
    'c', cfg.c, ...
    'lambda', cfg.lambda, ...
    'fc', cfg.fc, ...
    'B', cfg.B, ...
    'fs', cfg.fs, ...
    'PRF', cfg.PRF, ...
    'Tp', cfg.Tp, ...
    'va', cfg.va, ...
    'H', cfg.H, ...
    'R0', cfg.R0, ...
    'Ba', cfg.Ba, ...
    'Ta', cfg.Ta, ...
    'N_az', cfg.N_az, ...
    'N_rg', cfg.N_rg, ...
    'monostatic', true, ...
    'layout', cfg.layout, ...
    'scatter_phase_seed', cfg.scatter_phase_seed, ...
    'N_trans', cfg.N_trans ...
);
write_json(fullfile(cfg.output_dir, 'radar_params.json'), radar_params);

%% 5) 写入 running_params.json（保留已有配置，新增 GPU 设备号）
run_cfg.enable_random_phase = cfg.enable_random_phase;
write_json(running_param_file, run_cfg);

%% 6) 写入 target_list.bin
write_binary(fullfile(cfg.output_dir, 'target_list.bin'), target_buf);

%% 7) 写入 platform_pos.bin（单站）
platform_buf = zeros(1, 6 * cfg.N_az);
for ii = 1:cfg.N_az
    t = ta(ii);
    x = cfg.va * t; % 居中方位时间直接映射到航迹
    y = 0;
    z = cfg.H;
    idx = 6 * (ii - 1) + 1;
    platform_buf(idx:idx + 5) = [x, y, z, x, y, z];
end
write_binary(fullfile(cfg.output_dir, 'platform_pos.bin'), platform_buf);

%% 8) 写入 waveforms_f0.bin（行块 + R/I 交错）与编码表
write_waveform(fullfile(cfg.output_dir, 'waveforms_f0.bin'), waveforms_matrix);
write_codebook(fullfile(cfg.output_dir, 'waveform_codebook.bin'), codebook);

fprintf('Files written to: %s\n', cfg.output_dir);

%% ===== 辅助函数 =====
function write_json(fname, data)
    fid = fopen(fname, 'w');
    if fid < 0, error('Cannot open file: %s', fname); end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    txt = jsonencode(data);
    fwrite(fid, txt, 'char');
end

function write_binary(fname, buf)
    fid = fopen(fname, 'w');
    if fid < 0, error('Cannot open file: %s', fname); end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fwrite(fid, buf, 'double');
end

function write_waveform(fname, W)
    fid = fopen(fname, 'w');
    if fid < 0, error('Cannot open file: %s', fname); end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    Wr = real(W).'; % N_rg x N_trans
    Wi = imag(W).';
    buf = zeros(1, 2 * numel(Wr));
    buf(1:2:end) = Wr(:);
    buf(2:2:end) = Wi(:);
    fwrite(fid, buf, 'double');
end

function write_codebook(fname, codebook_zero_based)
    % 交替发射编码表：0 基索引，长度 N_az
    fid = fopen(fname, 'w');
    if fid < 0, error('Cannot open file: %s', fname); end
    cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fwrite(fid, int32(codebook_zero_based), 'int32');
end

% 生成单点目标的 SAR 配置和输入数据（无需图像）
% 输出：radar_params.json / running_params.json / target_list.bin / platform_pos.bin / waveforms_f0.bin

%% 0) 全局配置
cfg.output_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'data');
if ~exist(cfg.output_dir, 'dir'); mkdir(cfg.output_dir); end

addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'func_matlab')); % 使用 myfft/myifft（居中 FFT）

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
cfg.fs =150e6;         % 采样率 (Hz)
cfg.PRF = 2000;        % 脉冲重复频率 (Hz)
cfg.Tp = 25e-6;         % 脉冲宽度 (s)
cfg.va = 450;          % 平台速度 (m/s)
cfg.Ba=800;
cfg.H = 3e3;           % 平台高度 (m)
cfg.R0 = 1e4;          % 参考斜距 (m)
cfg.Ta=cfg.Ba*cfg.lambda/(2*cfg.va)*cfg.R0/cfg.va;
cfg.N_az = 4000;       % 方位脉冲数
cfg.Drange = 4e3;      % 斜距向场景尺寸 (m)
cfg.N_trans = 1;       % 发射波形数量
cfg.layout = 'col_major';
cfg.scatter_phase_seed = 20241129;
cfg.scatter_amp = 1.0; % 单点散射幅度

fprintf("na至少为%d \n",ceil(cfg.Ta*cfg.PRF))

%% 0.5) 默认波形数量（可由下方波形矩阵自动推断）
cfg.N_trans = 1;

%% 1) 推导网格
pixel_r = cfg.c / (2 * cfg.fs);   % 距离分辨单元
cfg.N_rg = round(cfg.Drange / pixel_r);
if mod(cfg.N_rg, 2) ~= 0, cfg.N_rg = cfg.N_rg + 1; end
cfg.N_rg = max(cfg.N_rg, 16);

% 方位时间轴居中，几何中心与频率轴 0 对齐
ta = (-cfg.N_az / 2:cfg.N_az / 2 - 1) / cfg.PRF;

tr = ((0:cfg.N_rg - 1) - cfg.N_rg / 2) / cfg.fs; % 与 fftshift 对应的快时间网格

%% 2) 定义单点目标
rng(cfg.scatter_phase_seed);
phi = 0;
if cfg.enable_random_phase
    phi = rand() * 2 * pi;
end
amp = cfg.scatter_amp * exp(1j * phi);
% 放在场景中心：x=0，y 为 R0 对应地面投影，z=0
x_target = 0;
y_target = sqrt(max(cfg.R0 ^ 2 - cfg.H ^ 2, 0));
z_target = 0;

target_buf = [x_target, y_target, z_target, real(amp), imag(amp)];

%% 2.5) 生成波形矩阵与默认编码表（交替发射）
Kr = cfg.B / cfg.Tp;
% st = (abs(tr) <= cfg.Tp/2) .* exp(1j * pi * Kr .* (tr .^ 2));
% st_down=exp(-1j * pi * Kr .* (tr .^ 2));
% sf = myfft(st, 2); % 频域波形居中
% sf_down=myfft(st_down,2);
load("wf_s4_N3750_.mat");

commSignal=[zeros(4,125)  commSignal zeros(4,125)];
sf =myfft(commSignal, 2) ; % 居中频域波形

% 默认：所有发射通道复制同一 LFM 波形；如需自定义，直接修改 waveforms_matrix
% waveforms_matrix = repmat(sf, cfg.N_trans, 1);
waveforms_matrix=sf;
% 默认：所有发射通道复制同一 LFM 波形；如需自定义，直接修改 waveforms_matrix
% waveforms_matrix = repmat(sf, cfg.N_trans, 1);
% waveforms_matrix = [sf;sf_down];
cfg.N_trans = size(waveforms_matrix, 1); % 根据波形矩阵行数推断 N_trans
if size(waveforms_matrix, 2) ~= cfg.N_rg
    error('waveforms_matrix 的列数必须等于 cfg.N_rg');
end

% 默认编码表：0 基索引，按 1,2,3... 轮换（交替发射）
codebook = mod(0:cfg.N_az-1, cfg.N_trans);

%% 3) 写入 radar_params.json
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

%% 4) 写入 running_params.json
run_cfg.enable_random_phase = cfg.enable_random_phase;
write_json(running_param_file, run_cfg);

%% 5) 写入 target_list.bin
write_binary(fullfile(cfg.output_dir, 'target_list.bin'), target_buf);

%% 6) 写入 platform_pos.bin（单站）
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

%% 7) 写入 waveforms_f0.bin（行块 + R/I 交错）
write_waveform(fullfile(cfg.output_dir, 'waveforms_f0.bin'), waveforms_matrix);
write_codebook(fullfile(cfg.output_dir, 'waveform_codebook.bin'), codebook);

fprintf('Single-point files written to: %s\n', cfg.output_dir);

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



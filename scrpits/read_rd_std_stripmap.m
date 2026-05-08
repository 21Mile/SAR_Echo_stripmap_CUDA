% RD 成像脚本：读取 CUDA 回波并进行距离/方位压缩
% 输入：./data/radar_params.json, waveforms_f0.bin, raw_echo_data.bin
% 输出：图像显示 + rd_image.mat
close all;clc;clear;
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'func_matlab')); % 使用 myfft/myifft（居中 FFT）
%% 0) 路径配置
data_dir = fullfile(fileparts(mfilename('fullpath')), '..', 'data');
radar_param_file = fullfile(data_dir, 'radar_params.json');
waveform_file    = fullfile(data_dir, 'waveforms_f0.bin');
echo_file        = fullfile(data_dir, 'raw_echo_data.bin');
codebook_file    = fullfile(data_dir, 'waveform_codebook.bin');

%% 1) 读取雷达参数
rp = jsondecode(fileread(radar_param_file));
N_rg = rp.N_rg;
N_az = rp.N_az;
c    = rp.c;
lambda = rp.lambda;
fc   = rp.fc;
fs   = rp.fs;
PRF  = rp.PRF;
R0   = rp.R0;
va   = rp.va;
H    = rp.H;

%% 2) 读取频域回波（未 shift）
fid = fopen(echo_file, 'r');
if fid < 0
    error('Cannot open echo file: %s', echo_file);
end
raw_buf = fread(fid, 2 * N_rg * N_az, 'double');
fclose(fid);
if numel(raw_buf) ~= 2 * N_rg * N_az
    error('Echo file length mismatch with N_rg/N_az');
end
raw_complex = complex(raw_buf(1:2:end), raw_buf(2:2:end));
S_f_unshift = reshape(raw_complex, N_rg, N_az); % 列为方位脉冲
S_f = S_f_unshift; % 不再 shift：CUDA 已对齐

%% 3) 读取参考波形（行块、R/I 交错）
fid = fopen(waveform_file, 'r');
if fid < 0
    error('Cannot open waveform file: %s', waveform_file);
end
wf_raw = fread(fid, 'double');
fclose(fid);
bytes_per_row = 2 * N_rg;
n_trans = numel(wf_raw) / bytes_per_row;
if abs(n_trans - round(n_trans)) > eps
    error('waveforms_f0.bin size not consistent with N_rg');
end
n_trans = round(n_trans);
W = zeros(n_trans, N_rg);
for k = 1:n_trans
    row_buf = wf_raw((k - 1) * bytes_per_row + (1:bytes_per_row));
    W(k, :) = complex(row_buf(1:2:end), row_buf(2:2:end));
end

% 读取编码表（0 基索引）；若缺省则按 0,1,2... 轮换
if isfile(codebook_file)
    fid = fopen(codebook_file, 'r');
    if fid < 0, error('Cannot open codebook file: %s', codebook_file); end
    cb_raw = fread(fid, N_az, 'int32');
    fclose(fid);
    if numel(cb_raw) ~= N_az
        error('waveform_codebook.bin length mismatch with N_az');
    end
    codebook = cb_raw(:).';
else
    codebook = mod(0:N_az-1, n_trans);
end

if any(codebook < 0) || any(codebook >= n_trans)
    error('codebook entries must be in [0, n_trans-1]');
end
codebook_1b = codebook + 1; % 转为 MATLAB 索引

% 为每个方位脉冲选择对应的参考波形
ref_f_mat = zeros(N_rg, N_az);
for kk = 1:N_az
    ref_f_mat(:, kk) = W(codebook_1b(kk), :).'; % 列向量，频域已 fftshift
end

%% 4) 频率/距离/方位网格
fr = ((0:N_rg - 1) - N_rg / 2) * fs / N_rg; % 居中频率
fa = ((0:N_az - 1) - N_az / 2) * PRF / N_az;
ta = (-N_az / 2:N_az / 2 - 1) / PRF;
pixel_r = c / (2 * fs);
distance_r = R0 + ((1:N_rg) - N_rg / 2) * pixel_r;

%% 5) 距离压缩（频域匹配滤波）
S_f=(fftshift(S_f,1));
S_f_rc = S_f .* conj(ref_f_mat);               % 频域匹配滤波（居中，按编码表轮换）
S_rc = myifft(S_f_rc, 1);                      % 回到快时间（居中）
figure;imagesc(abs(S_f));title("距离频域回波")
figure;imagesc(abs(S_rc));title("时域回波")

data_RD=RDA_imaging(S_rc, lambda, R0, fa, fr, va, distance_r,ta);



%% 单一发射波形点目标响应分析
is_point_eg=false; % 点目标剖面分析

if is_point_eg
    target_r_located=N_rg/2+1; target_a_located=N_az/2+1;
    r_scope=16;a_scope=16;
    N_zeros=2048;
    data_tmp=data_RD((-r_scope:r_scope)+target_r_located,(-a_scope:a_scope)+target_a_located);
    figure;imagesc(abs(data_tmp));
    data_tmp_fft2=circshift(fftshift(fft2(data_tmp),1),[0,16]);
    figure;imagesc(abs(data_tmp_fft2));
    target_resp=zeros(N_zeros,N_zeros);
    target_resp((-r_scope:r_scope)+N_zeros/2,(-a_scope:a_scope)+N_zeros/2)=data_tmp_fft2;
    target_resp=fft2(target_resp);
    figure;imagesc(abs(target_resp));title("空时滤波重构");
end




%% 9) 可选：保存结果

% 假设前面的计算步骤不变
data_RD_max = max(max(abs(data_RD)));
data_RD_db = db(abs(data_RD) / data_RD_max);

% --- 这里开始是保存图片的代码 ---

% 1. 模拟 caxis 的截断效果 ([-35 0])
% 这一步是为了保证保存出来的颜色和你屏幕上看到的一致
c_min = -35;
c_max = 0;

img_to_save = data_RD_db; 
img_to_save(img_to_save < c_min) = c_min; % 低于-35的值设为-35
img_to_save(img_to_save > c_max) = c_max; % 高于0的值设为0

% 2. 归一化到 [0, 1] 范围
% imwrite 保存 double 类型数据时需要数据在 0-1 之间 (0是黑, 1是白)
img_norm = (img_to_save - c_min) / (c_max - c_min);

% 3. 处理 axis xy 的方向问题
% imagesc 加了 axis xy 后原点在左下角，而 imwrite 保存图片默认原点在左上角
% 所以需要上下翻转矩阵，否则保存出来的图是倒着的
img_final = flipud(img_norm);

% 4. 直接保存为图片
% 这样保存的 output.png 分辨率严格等于 size(data_RD)
imwrite(img_final, 'output.png');



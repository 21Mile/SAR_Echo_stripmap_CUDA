clear;clc;close all;
addpath(fullfile(fileparts(mfilename('fullpath')), '..', 'func_matlab')); % 使用 myfft/myifft（居中 FFT）
% 参量设置
va = 450; % 雷达速度
H = 3e3; % 雷达高度
c = 3.e8; % 光速
lamda = 0.03; % 波长
antenna_d = lamda / (2 * sind(4)); % 天线间距（未使用）
fc = c / lamda; % 载频
B = 100e6; % 发射信号带宽
fs = 240e6; % 采样频率
PRF = 2000;
Ba=200;

na = 4000;
ta = (-na / 2:na / 2 - 1) / PRF;

pixel_r = c / 2 / fs; % 距离门长度
Drange = 5e3; % 场景大小
nr = round(Drange / pixel_r); % 距离向采样点数
Tp = 30e-6; % 发射信号宽度
kr = B / Tp; % 信号调频斜率
tr = (-nr / 2:nr / 2 - 1) / fs; % 快时间索引
fr = ((0:nr - 1) - nr / 2) * fs / nr; % 距离频率索引
fa = (-na / 2:na / 2 - 1) * PRF / na;
R0 = 10e4; % 场景中心
Ta=Ba*lamda/(2*va)*R0/va;
distance_r = R0 + ((1:nr) - nr / 2) * pixel_r; % 距离索引
Ntrans = 2; % 正交发射波形数量
Nreceiver = 1;

refer_signal_t0 = (abs(tr ) <=Tp/2).*exp(1j * pi * kr .* (tr .^ 2)); % LFM
refer_signal_f0 = myfft(refer_signal_t0, 2);

% 定义点坐标位置
% x_target=[50,0,-50,50,0,-50,50,0,-50];  z_target=[0,0,0,0,0,0,0,0,0];
% y_target=[sqrt(R0^2-H^2),sqrt(R0^2-H^2),sqrt(R0^2-H^2),sqrt((R0-100)^2-H^2)...
%     ,sqrt((R0-100)^2-H^2),sqrt((R0-100)^2-H^2),sqrt((R0+100)^2-H^2),sqrt((R0+100)^2-H^2),...
%     sqrt((R0+100)^2-H^2)];%
x_target = [0]; z_target = [0];
y_target = [sqrt(R0 ^ 2 - H ^ 2)]; %

dot_n_target = length(x_target);
dot_n_phase = exp(1i * rand(1, dot_n_target));

% 定义多发多收天线坐标
beam_center_ver = 17.45; % deg，阵列下俯角（未使用）
x_trans = va * ta;
y_trans = zeros(1, na);
z_trans = H + zeros(1, na);

x_receiver = va * ta;
y_receiver = zeros(1, na);
z_receiver = H + zeros(1, na);

% 回波信号产生
return_s_f = zeros(nr, na); % 发射/回波信号存储

for ii = 1:na
    disp(ii)
    record1 = zeros(1, nr);

    for nn = 1:dot_n_target
        % 计算发射机/接收机与目标的双程相位历程
        tmp_r_trans = sqrt((x_trans(1, ii) - x_target(1, nn)) ^ 2 + (y_trans(1, ii) - y_target(nn)) ^ 2 + (z_trans(1, ii) - z_target(nn)) ^ 2);
        tmp_r_receiver = sqrt((x_receiver(1, ii) - x_target(nn)) ^ 2 + (y_receiver(1, ii) - y_target(nn)) ^ 2 + (z_receiver(1, ii) - z_target(nn)) ^ 2);
        delay = (tmp_r_trans + tmp_r_receiver) / c;
        delay_relative = (delay - R0 * 2 / c);
        record1 = record1 + ((abs(x_trans(1,ii)-x_target(nn))/va)<Ta/2).*refer_signal_f0(1, :) .* exp(-1i * 2 * pi * fr * delay_relative) * exp(-1i * 2 * pi * fc * delay);
    end

    return_s_f(:, ii) = record1.';
end

return_s_t = myifft(return_s_f, 1);
figure; imagesc(abs(return_s_f))
mrefer_MF1 = conj(refer_signal_f0(1, :));
pulse_s = zeros(nr, na);

for ii = 1:na
    disp(ii)
    % 发射信号回波分离
    pulse_s(:, ii) = myifft(myfft(return_s_t(:, ii), 1) .* mrefer_MF1.', 1);
end

figure; imagesc(1:na, distance_r / 1e3, abs(pulse_s));
xlabel('Azimuth index', 'FontSize', 13);
ylabel('Range, km', 'FontSize', 13);
set(gca, 'FontSize', 13);
%% RD成像(DBF)

% --- 1. 方位向FFT ---
Doppler_azi = myfft(pulse_s, 2); 

figure("Name","LS二维频谱");
imagesc(abs(Doppler_azi)); % 此时已经是距离-时间，方位-频率
colormap(jet);
title('Range-Time / Azimuth-Frequency Domain');

% --- 2. 距离徙动校正 (RCMC) ---
% 将数据变换到 距离-频率 / 方位-频率 域
Range_Freq_Domain = myfft(Doppler_azi, 1);

% 定义严格对应FFT顺序的距离频率向量
fr_fft = fr; 
% 计算RCM量 (你的公式是正确的，抛物线近似)
delta_R = lamda^2 * R0 * fa.^2 / 8 / va^2;
% 相位补偿因子
% RCM是往后弯(距离变大)，我们要把它往前拉(时间减少)，对应正相位 exp(j*w*delta_t)
correct_part = exp(1i * 4 * pi * fr_fft.' * delta_R / c); 

% 补偿并变回 距离-时间 / 方位-频率
pulse_correct_range = myifft(Range_Freq_Domain .* correct_part, 1);
figure;imagesc(abs(pulse_correct_range))
% --- 3. 方位向压缩 ---
% Ka 计算 (使用 distance_r 是对的，实现了随距离变化的方位匹配滤波)
Ka = repmat((2*va^2/lamda ./ (distance_r)).', 1, na);
% Ha = exp(-1i * pi * repmat(fa, nr, 1).^2 ./ Ka); 
Ha=myfft(exp(1j*pi*Ka.*repmat(ta,nr,1).^2),2);

% 方位匹配滤波
data_RD_match = myifft(pulse_correct_range .* Ha, 2);

% --- 4. 结果显示 ---
data_peak = max(max(abs(data_RD_match)));
data_RD_match_db=db(abs(data_RD_match)/data_peak);
figure("Name","LS成像结果db图");
% 调整坐标轴以便观察
x_axis = va * ta; % 方位向坐标
r_axis = distance_r; % 距离向坐标
imagesc(x_axis, r_axis/1e3, data_RD_match_db);
xlabel('Azimuth (m)');
ylabel('Range (km)');
caxis([-40 0]); % 限制动态范围，让点更清晰
colorbar;

figure;
imagesc(x_axis, r_axis/1e3, abs(data_RD_match));
xlabel('Azimuth (m)');
ylabel('Range (km)');
title('3D Mesh Result');

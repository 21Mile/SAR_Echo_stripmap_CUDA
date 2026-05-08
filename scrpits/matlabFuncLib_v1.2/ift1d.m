%{
%    Function: ift1d
%    Author: CYAN
%    Description: 根据瞬时频率序列（ft1d 的输出）重建一维时域信号
%    Input: ft 为一维时频曲线；B 为带宽；st_initial 为原始信号的第一个采样点
%    Output: st 为恢复的时域信号（长度为 numel(ft)+1）
%    Date: 2024/10/31
%}
function [st] = ift1d(ft, B, st_initial)

    if nargin < 3 || isempty(st_initial)
        st_initial = 1;
    end

    if B <= 0
        error('ift1d:InvalidBandwidth', '带宽 B 必须为正数');
    end

    wasRowVector = isrow(ft);
    ft = ft(:);  % 统一转为列向量

    % ft1d 中：ft = diff(angle(st)) * B / pi，因此 diff(angle(st)) = ft * pi / B
    phase_increment = (pi / B) * ft;
    initial_phase = angle(st_initial);
    amplitude = abs(st_initial);

    phase = initial_phase + cumsum([0; phase_increment]);
    st = amplitude * exp(1j * phase);

    if wasRowVector
        st = st.';
    end
end

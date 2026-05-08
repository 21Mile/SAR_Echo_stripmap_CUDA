%{
    Function: ift1d_us
    Author: CYAN
    Description: 求一维时域信号，先进行插值，再恢复信号
    Input: ft为一维时频曲线;B为带宽; st_initial为原始信号的第一个点，用于确定初始相位和幅度
    Output: st维一维时域信号
    Date: 2024/10/31
%}
function [st] = ift1d_us(ft, B,N)
    interp_mode=['nearest','linear','next','previous','cubic','spline','makima'];

    ft_us=interp1(1:length(ft), ft, linspace(1,length(ft),N-1),interp_mode(6));
    % 逆尺度变换
    phase_diff = ft_us .* (pi/(B));

    % 累积求和得到解缠后的相位
    phase = cumsum([0, phase_diff]); % 注意：cumsum需要补一个初始值0

    % 构建复数信号
    st =  exp(1j *pi* phase); 

end
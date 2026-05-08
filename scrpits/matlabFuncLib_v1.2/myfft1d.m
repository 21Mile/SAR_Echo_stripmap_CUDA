%{
    Function: myfft1d
    Author: CYAN
    Description: 一维fft的简化函数
    Input: st为一维时域信号
    Output: sf为一维频域信号
    Date: 2024/6/5
%}
function sf = myfft1d(st)
    sf = fftshift(fft(fftshift(st)));
end

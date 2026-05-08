%{
    Function: myfft
    Author: CYAN
    Description: 二维fft的简化函数
    Input: st为二维时域信号，dim为维数(dim=1为按列，dim=2为按行)
    Output: sf为二维频域信号
    Date: 2024/6/5
%}
function sf = myfft(st, dim)
    sf = fftshift(fft(fftshift(st, dim), [], dim), dim);
end

%{
    Function: myfft
    Author: CYAN
    Description: 一维ifft的简化函数
    Input: sf为二维时域信号
    Output: st为二维频域信号
    Date: 2024/6/5
%}

function st = myifft1d(sf)
    st = fftshift(ifft(fftshift(sf)));
end

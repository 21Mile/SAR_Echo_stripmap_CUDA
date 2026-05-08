%{
    Function: myifft
    Author: CYAN
    Description: 二维ifft的简化函数
    Input: sf为二维时域信号，dim为维数(dim=1为按列，dim=2为按行)
    Output: st为二维频域信号
    Date: 2024/6/5
%}
function st = myifft(sf, dim)
    st = fftshift(ifft(fftshift(sf, dim), [], dim), dim);
end

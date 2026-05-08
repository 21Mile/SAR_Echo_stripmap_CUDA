%{
    Function: myupsample1d
    Author: CYAN
    Description: 基于频域补零的升采样简化函数
    Input: st_input为一维信号，upsample_rate为升采样倍率
    Output: st为升采样后的信号
    Date: 2024/6/5
%}

function [st] = myupsample1d(st_input, upsample_rate)
    st = interpft(st_input, length(st_input) * upsample_rate);

end

% function [st] = myupsample0(st_input,upsample_rate)
% % 通过频域补零的方式实现升采样
% if mod(upsample_rate, 2) == 0 % 如果n是偶数
%         size0m = [upsample_rate/2, upsample_rate/2];
%     else % 如果n是奇数
%         size0m = [(upsample_rate-1)/2, (upsample_rate+1)/2];
% end
% size_input=size(st_input);%输入矩阵尺寸
% sf_input=fftshift(fft(fftshift(st_input)));
% sf_ouput=[zeros(1,size0m(1)*size_input(1,2) ) ,sf_input ,zeros(1,size0m(2)*size_input(1,2))];
% st=fftshift(ifft(fftshift(sf_ouput)));
%
% end

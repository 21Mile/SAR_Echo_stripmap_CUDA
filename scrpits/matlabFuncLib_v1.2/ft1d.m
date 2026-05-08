%{
    Function: ft1d
    Author: CYAN
    Description: 求一维时频曲线，原理为对相位求导
    Input: st为一维时域信号;B为带宽
    Output: ft维一维时域信号，表示一维时频曲线
    Date: 2024/10/31
%}
function [ft] = ft1d(st,B)
    ft = diff(unwrap(angle(st)));
    ft=(ft./pi).*(B);
end

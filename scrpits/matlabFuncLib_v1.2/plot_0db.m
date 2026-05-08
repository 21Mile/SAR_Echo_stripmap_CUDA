%{
    Function: plot_0db
    Author: CYAN
    Description: 绘制0db为峰值的简化函数
    Input: st为输入信号，fig_name为绘图名称(可选)
    Output: 无返回值
    Date: 2024/6/5
%}

function [void] = plot_0db(st, fig_name) %1d

    if nargin == 1 %设置默认参数
        fig_name = "默认图片";
    end

    figure('name', fig_name);
    plot(db(abs(st) / max(abs(st))));
    void = 0;

end

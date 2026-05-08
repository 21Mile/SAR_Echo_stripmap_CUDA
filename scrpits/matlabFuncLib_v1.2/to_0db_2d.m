%{
    Function: to_0db
    Author: CYAN
    Description: 计算两个信号 x1 和 x2 的幅度比值，并将结果转换为分贝
    Input:  x1, x2 为时域信号
    Output: y为输出信号
    Date: 2024/6/5
%}

function y = to_0db_2d(x1, x2)
    y = db(abs(x1) / max(max(abs(x2))));
end

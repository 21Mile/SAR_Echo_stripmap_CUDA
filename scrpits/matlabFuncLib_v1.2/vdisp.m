%{
    Function: vdisp
    Author: CYAN
    Description: 同时输出变量名和变量值的函数
    Input: x为变量，unit为单位(可缺省)
    Output: 无返回值
    Date: 2024/11/4
%}
function vdisp(x, unit)

    if nargin < 2
        unit = '';
    end

    if isempty(unit)
        fprintf('[vdisp]%s=%.6f\n', inputname(1), x) %无单位
    else
        fprintf('[vdisp]%s=%.6f %s\n', inputname(1), x, unit) %有单位
    end

end

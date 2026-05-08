%{
%    Function: cc_ls
%    Author: CYAN
%    Description: 基于最小二乘矩阵展开的互相关计算，返回两个等长信号的完整互相关序列
%    Input: st1/st2 为一维时域信号（列或行向量，长度需一致）
%    Output: cc_ls 为包含正、负时移的互相关结果（长度 2*N-1）
%    Date: 2024/10/31
%}
function [cc_ls] = cc_ls(st1, st2)

    if nargin < 2
        error('cc_ls:NotEnoughInputs', '需要提供两个输入信号');
    end

    if numel(st1) ~= numel(st2)
        error('cc_ls:SignalLengthMismatch', 'st1 与 st2 的长度必须一致');
    end

    % 保持输入形状一致（内部统一转为列向量）
    if isrow(st1), st1 = st1.'; end
    if isrow(st2), st2 = st2.'; end

    N = length(st1);
    S1 = zeros(2 * N - 1, N, 'like', st1);

    % 构造 Toeplitz 形式的时移矩阵
    for ii = 1:N
        S1(ii:ii + N - 1, ii) = st1;
    end

    % 构建补零后的第二个信号
    data_tmp = [st2; zeros(N - 1, 1, 'like', st2)];

    % 非负时移部分
    cc_pos = S1' * data_tmp;

    % 通过共轭对称补齐负时移
    cc_neg = conj(cc_pos(end:-1:2));
    cc_ls = [cc_neg; cc_pos];
end

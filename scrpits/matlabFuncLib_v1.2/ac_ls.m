%{
%    Function: ac_ls
%    Author: CYAN
%    Description: ͨ����С����ʱ�ƾ�����ȡһά�źŵ����������
%    Input: st Ϊһάʱ���źţ��л���������
%    Output: ac_ls Ϊ���� 2*N-1 �����������
%    Date: 2024/10/31
%}

function [ac_ls] = ac_ls(st)
    N = length(st);
    
    % 确保输入是列向量
    if isrow(st)
        st = st.';
    end
    
    % 构建时移矩阵
    S1 = zeros(2*N-1, N);
    for ii = 1:N
        S1(ii:ii+N-1, ii) = st;
    end
    
    % 构建补零后的信号
    data_tmp = [st; zeros(N-1, 1)];  % 修正：移除未定义的na
    
    % 计算自相关（直接内积�?
    ac_ls = S1' * data_tmp;  % 非负时移部分
    
    % 计算完整自相关（负时�?非负时移�?
    ac_neg = conj(ac_ls(end:-1:2));  % 负时移部分（共轭对称�?
    ac_ls = [ac_neg; ac_ls];  % 组合完整自相�?
    
    % 不需要circshift（自相关天然中心对齐�?
end



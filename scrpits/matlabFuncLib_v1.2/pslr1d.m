%{
    Function: pslr1d
    Author: CYAN
    Description: 求PSLR，不使用循环，较为快速
    Input: amp为归一化幅度谱，单位为db;建议进行升采样
    Output: pslr为峰值旁瓣比
    Date: 2024/11/6
%}

function [pslr] = pslr1d(amp)
    minuscule_val=-100;%设置一个极度小的值，用来取代最大值，以便找到第二大的值;也可以是min(amp)
    % 使用findpeaks查找极大值点
    [peak_values, peak_locations] = findpeaks(amp);
    % 检查是否有至少两个极大值点
    if length(peak_values) >= 2
        [maxValue, maxIndex] = max(peak_values);
        peak_values(maxIndex)=minuscule_val;
        % 选择第二大的极大值点
        [pslr,pslr_loc] = max(peak_values);
    else
        % 如果没有足够的极大值点，则输出提示
        pslr = NaN;
        disp('[pslr1d]错误：没有足够的极大值点\n');
    end

    % 输出结果
    % fprintf('PSLR的值为：%f，位置为：%d\n', pslr, pslr_loc);

end



% 排序版：性能开销大，已弃用
% function [pslr] = pslr1d(amp)
%     % 使用findpeaks查找极大值点
%     [peak_values, peak_locations] = findpeaks(amp);
% 
%     % 根据极大值点的值进行降序排序
%     [sorted_peak_values, sort_index] = sort(peak_values, 'descend');
%     sorted_peak_locations = peak_locations(sort_index);
% 
%     % 检查是否有至少两个极大值点
%     if length(peak_values) >= 2
%         % 选择第二大的极大值点
%         pslr = sorted_peak_values(2);
%         pslr_loc = sorted_peak_locations(2);
%     else
%         % 如果没有足够的极大值点，则输出提示
%         pslr = NaN;
%         pslr_loc = NaN;
%         disp('[pslr1d]错误：没有足够的极大值点');
%     end
% 
%     % 输出结果
%     % fprintf('PSLR的值为：%f，位置为：%d\n', pslr, pslr_loc);
% 
% end

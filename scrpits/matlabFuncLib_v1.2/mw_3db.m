%{
    Function: mw_3db
    Author: CYAN
    Description: ??3db??????????????????????
    Input: amp????0dB???????
    Output: mw_3db?3dB??????????
    Date: 2024/6/5
%}
function [mw_3db] = mw_3db(amp)
    [max_data, peak_pos] = max(amp);
    N = numel(amp);
    peak_pos = peak_pos(ceil(length(peak_pos) / 2));

    threshold = max_data - 3;

    right_rel = find(amp(peak_pos:end) < threshold, 1, 'first');
    if isempty(right_rel)
        error('mw_3db:NoRightCross', '未在右侧找到 3 dB 交点');
    end
    j = peak_pos + right_rel - 1;

    left_rel = find(amp(1:peak_pos) < threshold, 1, 'last');
    if isempty(left_rel)
        error('mw_3db:NoLeftCross', '未在左侧找到 3 dB 交点');
    end
    k = left_rel;

    mw_3db = j - k;
    fprintf('3 dB 主瓣宽度: j=%d, k=%d, 宽度=%.2f\n', j, k, mw_3db);
end

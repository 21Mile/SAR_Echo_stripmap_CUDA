
%{
    Function: islr_pslr_mw
    Author: CYAN
    Description: 求解 islr，pslr，以及主瓣宽度
    Input:
        amp       - 峰值对齐到 0 dB 的自相关幅度谱（单位 dB）
        up_sample - 升采样倍率（amp 已经提前插值后的倍率）
    Output:
        islr - 积分旁瓣电平 (dB)
        pslr - 最大旁瓣电平 (dB)
        mw   - 主瓣宽度（折算回原始采样点数）
    Date: 2024/6/5 (robust version)
%}

function [islr, pslr, mw] = islr_pslr_mw(amp, up_sample)
    % 统一为列向量处理（不改变数值）
    amp = amp(:);
    N   = length(amp);

    if N < 3
        % 太短无法定义主瓣，直接给出退化结果
        islr = 0;
        pslr = 0;
        mw   = 0;
        return;
    end

    % ---------- 1. 找主峰位置（仍然采用“所有峰中取中间那个”策略） ----------
    [max_data, peak_pos_all] = max(amp); %#ok<ASGLU>
    % peak_pos_all 可能是标量，也可能是多个位置
    peak_pos_all = find(amp == max_data);
    peak_pos     = peak_pos_all(ceil(numel(peak_pos_all) / 2));

    % ---------- 2. 搜索主瓣左右边界（零主瓣模式） ----------
    % 搜索范围：最多向两侧扩展 N/2，但必须保证索引在 [1, N]
    right_max = min(N - 1, peak_pos + floor(N / 2));  % 右边最大 i，使 i+1 <= N
    left_min  = max(2,     peak_pos - floor(N / 2));  % 左边最小 i，使 i-1 >= 1

    % 右侧：从峰值往右走，找到“第一次开始上升”的位置
    j = right_max;  % 默认兜底：如果没找到，就用搜索区间的最右端
    for i = peak_pos:right_max
        if amp(i + 1) > amp(i)
            j = i;
            break;
        end
    end

    % 左侧：从峰值往左走，找到“第一次开始上升”的位置
    k = left_min;   % 默认兜底：如果没找到，就用搜索区间的最左端
    for i = peak_pos:-1:left_min
        if amp(i - 1) > amp(i)
            k = i;
            break;
        end
    end

    % 确保 k <= peak_pos <= j，且索引合法
    k = max(1, min(k, N));
    j = max(1, min(j, N));
    if k > j
        % 极端异常情况（比如数据几乎平坦），强行按峰值左右各至少一个点
        k = max(1, peak_pos - 1);
        j = min(N, peak_pos + 1);
    end

    % 主瓣宽度（“零主瓣模式”），折算回原始采样点数
    mw_samples = j - k;          % 在当前插值网格上的点数
    mw         = mw_samples / max(up_sample, 1);  % 防止 up_sample<=0

    % ---------- 3. 计算 PSLR ----------
    amp_sidelobe = amp;
    amp_sidelobe(k:j) = [];      % 去掉主瓣区间

    if isempty(amp_sidelobe)
        % 没有旁瓣，直接设为 -Inf
        pslr = -Inf;
    else
        pslr = max(amp_sidelobe);
    end

    % ---------- 4. 计算 ISLR ----------
    % amp 为 dB，先转成线性幅度，再平方得到功率
    main_amp_lin   = 10 .^ (amp(k:j) / 20);         % 主瓣幅度
    side_amp_lin   = 10 .^ (amp_sidelobe    / 20);  % 旁瓣幅度

    power_mainlobe = sum(main_amp_lin .^ 2);
    power_sidelobe = sum(side_amp_lin .^ 2);

    % 防止出现 0 或极小值导致 log 爆掉
    eps_power      = 1e-20;
    power_mainlobe = max(power_mainlobe, eps_power);
    power_sidelobe = max(power_sidelobe, eps_power);

    islr = 10 * log10(power_sidelobe / power_mainlobe);
end

%  Jin Version
% function [islr, pslr, mw] = islr_pslr_mw(amp, up_sample)
%     % 计算pslr,MW
%     % amp is the input auto-correlation function with representation by dB
%     % choice==0, reture 3-dB MW, else reture main lobe
%     % up_sample is the up sampling rate
%     % code by jinguodong 2016/12/3
% 
%     [max_data, peak_pos] = max(amp);
%     N = length(amp);
%     peak_pos = peak_pos(ceil(length(peak_pos) / 2));
%     %% MW: zero main lob (零主瓣模式)
%     for i = peak_pos:peak_pos + fix(N / 2)
% 
%         if amp(i + 1) > amp(i)
%             j = i;
%             break;
%         else
%             continue;
%         end
% 
%     end
% 
%     for i = peak_pos:-1:peak_pos - fix(N / 2)
% 
%         if amp(i - 1) > amp(i)
%             k = i;
%             break;
%         else
%             continue;
%         end
% 
%     end
% 
%     mw = j - k;
%     % fprintf("零点:j:%d,k:%d\t\t ，升采样后的mw点数：%.2f\n",j,k,mw);
%     mw = mw / up_sample;
% 
%     amp_sidlobe = amp;
%     amp_sidlobe(k:j) = [];
%     pslr = max(amp_sidlobe);
% 
%     power_sidelobe = sum((10 .^ (amp_sidlobe / 20)) .^ 2); %主瓣功率积分
%     power_mainlobe = sum((10 .^ (amp(k:j) / 20)) .^ 2); %信号总功率
%     islr = 10 * log10(power_sidelobe / power_mainlobe);
% 
%     % %% MW: 3dB_MW (3dB主瓣模式)
%     % if choice == 0
%     %
%     %     for i = peak_pos:peak_pos+fix(N/2)
%     %         if amp(i+1)<(max_data-3)
%     %             j=i;
%     %             break;
%     %         else
%     %             continue;
%     %         end
%     %     end
%     %     for i = peak_pos:-1:peak_pos-fix(N/2)
%     %         if amp(i-1)<(max_data-3)
%     %             k=i;
%     %             break;
%     %         else
%     %             continue;
%     %         end
%     %     end
%     %     mw = (j-k); %MW返回的是点数
%     %     mw = mw/up_sample;
%     % end
% end

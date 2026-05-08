function [st, f_FM] = multi_order_FM(Tp, Fs, x, order, parameters)
    % % % Tp: 脉冲宽度
    % % % Fs: 采样频率
    % % % x: FM编码
    % % % order: FM阶数
    % % % parameters: only for mixed multi_order
    t = ((0:ceil(Fs * Tp) - 1)) / Fs;
    Ts = Tp / (length(x) - 1);
    x1_tmp1 = x(2:end);
    x1_tmp2 = x(1:end - 1);
    f_FM = zeros(1, length(t));
    %% 零阶
    if (order == 0)
        x_code = x(2:end); ori = 1;

        for i = 1:length(x_code)
            tmp_value = x_code(i);

            if (tmp_value == 0)
                tmp_value = 1e-26;
            end

            a = ['((t>' num2str((i - 1)) '*Ts )&(t<=' num2str(i) '*Ts)).* ' num2str(tmp_value)];
            fx = eval(a);
            position = find(fx == 0);
            fx(position((i == 1) + 1:end)) = [];
            f_FM((ori ~= 1) * ori + (ori == 1) * 2:ori + length(fx) - 1) = fx((ori ~= 1) * 1 + (ori == 1) * 2:end);
            ori = ori + length(fx);
        end

        f_FM(1) = x(1);
        %% 一阶
    elseif (order == 1)
        x_code = (x1_tmp1 - x1_tmp2) / Ts; ori = 1;

        for i = 1:length(x_code)
            tmp_value = x_code(i);

            if (tmp_value == 0)
                tmp_value = 1e-26;
            end

            a = ['((t>' num2str((i - 1)) '*Ts )&(t<=' num2str(i) '*Ts)).* ' num2str(tmp_value)];
            fx = eval(a);
            position1 = find(fx ~= 0);
            fx(position1(1):position1(end)) = (tmp_value * Ts / (t(position1(end)) - t(position1(1)) + 1 / Fs));
            position = find(fx == 0);
            fx(position((i == 1) + 1:end)) = [];
            f_FM(ori:ori + length(fx) - 1) = filter(1 / Fs, [1, -1], fx) + x(i);
            ori = ori + length(fx);
        end

        %% 二阶
    elseif (order == 2)
        x_code = 2 * (x1_tmp1 - x1_tmp2) / Ts / Ts; ori = 1;

        for i = 1:length(x_code)
            tmp_value = x_code(i);

            if (tmp_value == 0)
                tmp_value = 1e-26;
            end

            a = ['((t>' num2str((i - 1)) '*(Ts) )&(t<=' num2str(i) '*Ts)).* ' num2str(tmp_value)];
            fx_part_i = eval(a);
            position1 = find(fx_part_i ~= 0);
            fx_part_i(position1(1):position1(end)) = tmp_value * Ts .^ 2 / (t(position1(end)) - t(position1(1)) + 1 / Fs) .^ 2;
            position = find(fx_part_i == 0);
            fx_part_i(position((i == 1) * 1 + 1:end)) = [];
            f_FM_tmp1 = filter(1 / Fs, [1, -1], fx_part_i);
            f_FM(ori:ori + length(fx_part_i) - 1) = cumtrapz(1:length(f_FM_tmp1), f_FM_tmp1) / Fs + x(i) + ((i - 1) > 0) * (tmp_value * Ts .^ 2 / (t(position1(end)) - t(position1(1)) + 1 / Fs) .^ 2) * (1 / Fs) .^ 2/2;
            ori = ori + length(fx_part_i);
        end

        %% 混合阶
    elseif (order == 3)
        %% 常数项
        alpha = parameters(:, 3).'; ori = 1;

        for i = 1:length(alpha)
            tmp_value = alpha(i);

            if (tmp_value == 0)
                tmp_value = 1e-26;
            end

            a = ['((t>' num2str((i - 1)) '*Ts )&(t<=' num2str(i) '*Ts)).* ' num2str(tmp_value)];
            fx = eval(a);
            position = find(fx == 0);
            fx(position((i == 1) + 1:end)) = [];
            f_FM_alpha((ori ~= 1) * ori + (ori == 1) * 2:ori + length(fx) - 1) = fx((ori ~= 1) * 1 + (ori == 1) * 2:end);
            ori = ori + length(fx);
        end

        f_FM_alpha(1) = f_FM_alpha(2);
        %% 一次项
        beta = parameters(:, 2).'; ori = 1;

        for i = 1:length(beta)
            tmp_value = beta(i);

            if (tmp_value == 0)
                tmp_value = 1e-36;
            end

            a = ['((t>' num2str((i - 1)) '*Ts )&(t<=' num2str(i) '*Ts)).* ' num2str(tmp_value)];
            find_t = find(t > (i - 1) * Ts & t < (i - 1) * Ts + 1 / Fs);
            fx = eval(a);
            position1 = find(fx ~= 0);
            fx(position1(1):position1(end)) = (tmp_value * Ts / (t(position1(end)) - t(position1(1)) + 1 / Fs));
            position = find(fx == 0);
            fx(position((i == 1) + 1:end)) = [];
            f_FM_beta(ori:ori + length(fx) - 1) = filter(1 / Fs, [1, -1], fx);
            ori = ori + length(fx);
        end

        %% 二次项
        gamma = parameters(:, 1).'; ori = 1;

        for i = 1:length(gamma)
            tmp_value = gamma(i);

            if (tmp_value == 0)
                tmp_value = 1e-36;
            end

            a = ['((t>' num2str((i - 1)) '*(Ts) )&(t<=' num2str(i) '*Ts)).* ' num2str(tmp_value)];
            fx_part_i = eval(a);
            position1 = find(fx_part_i ~= 0);
            fx_part_i(position1(1):position1(end)) = tmp_value * Ts .^ 2 / (t(position1(end)) - t(position1(1)) + 1 / Fs) .^ 2;
            position = find(fx_part_i == 0);
            fx_part_i(position((i == 1) * 1 + 1:end)) = [];
            f_FM_tmp1 = filter(1 / Fs, [1, -1], fx_part_i);
            f_FM_gamma(ori:ori + length(fx_part_i) - 1) = cumtrapz(1:length(f_FM_tmp1), f_FM_tmp1) / Fs + ((i - 1) > 0) * (tmp_value * Ts .^ 2 / (t(position1(end)) - t(position1(1)) + 1 / Fs) .^ 2) * (1 / Fs) .^ 2/2;
            ori = ori + length(fx_part_i);
        end

        %%%%混合
        f_FM = f_FM_alpha + f_FM_beta + f_FM_gamma;
        %%%%%%% 输入错误
    else
        disp('order:error')
    end

    theta = cumtrapz(1:length(f_FM), f_FM) / Fs;
    st = exp(1j * 2 * pi * theta);
end

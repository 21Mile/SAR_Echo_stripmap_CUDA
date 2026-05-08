function [islr_2d] = islr_2d_sum(img_2d, rowIndex, colIndex, point_num, draw_img)
%ISLR_2D_SUM 计算二维幅度图像的积分旁瓣比（ISLR）。
%   islr_2d = ISLR_2D_SUM(img, rowIndex, colIndex, point_num) 会以
%   (rowIndex, colIndex) 为中心截取 point_num×point_num 的聚焦区域
%   （超出边界时自动截断），并将剩余区域视作背景能量，再输出
%   ISLR = 10*log10(E_background / E_focus)。
%   第五个参数 draw_img 非零时会绘制聚焦区域与背景区域。

    narginchk(4, 5);

    if nargin < 5 || isempty(draw_img)
        draw_img = 0;
    end

    if point_num <= 0
        error('islr_2d_sum:InvalidWindow', 'point_num 必须为正数');
    end

    [numRows, numCols] = size(img_2d);

    if rowIndex < 1 || rowIndex > numRows || colIndex < 1 || colIndex > numCols
        error('islr_2d_sum:IndexOutOfRange', '给定的行/列索引超出图像大小');
    end

    half_win = floor(point_num / 2);

    r_start = max(1, rowIndex - half_win);
    r_end   = min(numRows, rowIndex + half_win);
    c_start = max(1, colIndex - half_win);
    c_end   = min(numCols, colIndex + half_win);

    Focus_img_2d = img_2d(r_start:r_end, c_start:c_end);
    Background_img_2d = img_2d;
    Background_img_2d(r_start:r_end, c_start:c_end) = 0;

    if draw_img ~= 0
        figure('Name', '聚焦区域与背景区域');
        subplot(2, 1, 1);
        imagesc(abs(Focus_img_2d)); title('聚焦区域');
        subplot(2, 1, 2);
        imagesc(abs(Background_img_2d)); title('背景区域');
    end

    focus_energy = sum(abs(Focus_img_2d), 'all');
    background_energy = sum(abs(Background_img_2d), 'all');

    if focus_energy == 0
        error('islr_2d_sum:ZeroFocusEnergy', '聚焦区域能量为 0，无法计算 ISLR');
    end

    islr_2d = db(background_energy / focus_energy);
end

function print_img(fig, filename, resolution)
% PRINT_IMG 保存高分辨率图片
%   PRINT_IMG(FIG, FILENAME) 将指定图形保存为PNG格式图片
%   PRINT_IMG(FIG, FILENAME, RESOLUTION) 指定分辨率保存图片
%
%   输入参数:
%     fig         - 图形句柄
%     filename    - 文件名（不包含扩展名）
%     resolution  - 分辨率（可选，默认为888）
%
%   示例:
%     print_img(gcf, 'myfigure');
%     print_img(gcf, 'myfigure', 300);

    % 设置默认分辨率
    if nargin < 3
        resolution = 888;
    end
    
    
    % 构造完整的文件路径
    output_filename = [ filename];
    
    % 保存图片
    print(fig, output_filename, '-dpng', ['-r' num2str(resolution)]);
    
    % 显示保存信息
    disp(['高分辨率图片已保存为: ' output_filename ' (分辨率: ' num2str(resolution) ')']);
end
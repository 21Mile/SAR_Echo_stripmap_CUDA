function [] = printMap( map)


% 获取所有键
keys = map.keys;

% 遍历所有键
for i = 1:length(keys)
    key = keys{i};
    value = map(key);
    % 同样，根据值的类型进行转换
    if isnumeric(value)
        % 如果是向量或矩阵，可能需要更复杂的转换，这里简单处理
        valueStr = mat2str(value);
    else
        valueStr = value;
    end
    fprintf('%s: %s\n', key, valueStr);
end


end
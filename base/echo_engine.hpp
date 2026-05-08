#pragma once

#include <string>
#include <vector>

#include "config.hpp"
#include "logger.hpp"
#include "readers.hpp"
#include "types.hpp"

// 回波生成核心（见文档 §5/§8 路径）
class EchoEngine
{
public:
    EchoEngine(const RadarParams& radar,
               const RunningParams& run,
               Logger& logger);

    // 生成完整回波并写文件（频域 R/I 交错输出）
    void generate(const WaveformData& wf,
                  const std::vector<DeviceTarget>& targets,
                  const PlatformData& platform,
                  const std::vector<int>& codebook,
                  const std::string& output_path);

private:
    RadarParams radar_;
    RunningParams run_;
    Logger& logger_;
};


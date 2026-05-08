#pragma once

#include <cstddef>
#include <string>

#include "logger.hpp"

// 标量参数（对应 radar_params.json）
struct RadarParams
{
    int schema_version = 0;
    double c = 0.0;
    double lambda = 0.0;
    double fc = 0.0;
    double B = 0.0;
    double fs = 0.0;
    double PRF = 0.0;
    double Tp = 0.0;
    double va = 0.0;
    double H = 0.0;
    double R0 = 0.0;
    double Ba = 0.0;
    double Ta = 0.0;
    std::size_t N_az = 0;
    std::size_t N_rg = 0;
    std::size_t N_trans_declared = 0; // 0 表示 JSON 未声明
    bool monostatic = true;
    std::string layout;
};

// 运行参数（对应 running_params.json）
struct RunningParams
{
    bool enable_concurrency = false;
    LogLevel logger_level = LogLevel::INFO;
    int batch_cols = 16;
    bool enable_random_phase = true;
    bool enable_mixed_precision = true; // true: 关键步骤 double，非关键用 float；false: 全链路 double
    int device_id = 0; // CUDA 设备编号（从 0 开始）
};

RadarParams loadRadarParams(const std::string& path);
RunningParams loadRunningParams(const std::string& path, Logger& logger);


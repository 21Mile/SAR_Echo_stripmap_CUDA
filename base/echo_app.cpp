#include "echo_app.hpp"

#include <fstream>
#include <iostream>
#include <string>

#include "config.hpp"
#include "echo_engine.hpp"
#include "logger.hpp"
#include "readers.hpp"

namespace
{
// 路径拼接（Windows 使用 '\\'，其他平台 '/'）
std::string joinPath(const std::string& dir, const std::string& file)
{
    if (dir.empty()) return file;
    const char sep =
#if defined(_WIN32)
        '\\';
#else
        '/';
#endif
    if (dir.back() == sep) {
        return dir + file;
    }
    return dir + sep + file;
}

// 最小存在性检查
bool fileExists(const std::string& path)
{
    std::ifstream ifs(path, std::ios::binary);
    return static_cast<bool>(ifs);
}
} // namespace

int EchoApp::run(int argc, char** argv)
{
    std::string data_dir = "data";
    std::string output_path;

    // 命令行：默认读 ./data，也可传 data_dir 与输出路径
    for (int i = 1; i < argc; ++i) {
        std::string arg = argv[i];
        if (arg == "--data-dir" && i + 1 < argc) {
            data_dir = argv[++i];
        }
        else if (arg == "--output" && i + 1 < argc) {
            output_path = argv[++i];
        }
        else if (arg == "-h" || arg == "--help") {
            std::cout << "用法: base.exe [--data-dir <目录>] [--output <文件名>]" << std::endl;
            return 0;
        }
        else if (i == 1 && arg[0] != '-') {
            data_dir = arg;
        }
    }

    // 未显式指定时，尝试向上查找 data 目录（兼容 exe 位于 base/x64/Debug）
    if (data_dir == "data") {
        const std::string candidates[] = { "data", "..\\data", "..\\..\\data", "../data", "../../data" };
        bool found = false;
        for (const auto& cand : candidates) {
            if (fileExists(joinPath(cand, "radar_params.json"))) {
                data_dir = cand;
                found = true;
                break;
            }
        }
        if (!found) {
            std::cout << "[ERROR] 未找到 radar_params.json，请用 --data-dir 指定数据目录" << std::endl;
            return 1;
        }
    }

    if (output_path.empty()) {
        output_path = joinPath(data_dir, "raw_echo_data.bin");
    }

    Logger bootstrap(LogLevel::INFO);
    try {
        const std::string radar_path = joinPath(data_dir, "radar_params.json");
        const std::string running_path = joinPath(data_dir, "running_params.json");
        const std::string target_path = joinPath(data_dir, "target_list.bin");
        const std::string platform_path = joinPath(data_dir, "platform_pos.bin");
        const std::string waveform_path = joinPath(data_dir, "waveforms_f0.bin");
        const std::string codebook_path = joinPath(data_dir, "waveform_codebook.bin");

        RadarParams radar = loadRadarParams(radar_path);
        RunningParams run_cfg = loadRunningParams(running_path, bootstrap);
        bootstrap.setLevel(run_cfg.logger_level);

        bootstrap.log(LogLevel::INFO, "读取参数成功: N_rg=" + std::to_string(radar.N_rg) + ", N_az=" + std::to_string(radar.N_az));

        const WaveformData wf = readWaveforms(waveform_path, radar.N_rg, radar);
        bootstrap.log(LogLevel::INFO, "波形行数 N_trans=" + std::to_string(wf.n_trans));

        std::vector<int> codebook;
        try {
            codebook = readCodebook(codebook_path, radar.N_az, wf.n_trans);
            bootstrap.log(LogLevel::INFO, "编码表已加载，使用 waveform_codebook.bin");
        }
        catch (const std::exception& ex) {
            bootstrap.log(LogLevel::WARN, std::string("编码表缺失或无效，使用默认轮换: ") + ex.what());
            codebook.resize(radar.N_az);
            for (std::size_t i = 0; i < radar.N_az; ++i) {
                codebook[i] = static_cast<int>(i % wf.n_trans);
            }
        }

        const auto targets = readTargets(target_path);
        bootstrap.log(LogLevel::INFO, "目标数量: " + std::to_string(targets.size()));

        const auto platform = readPlatform(platform_path, radar.N_az);
        bootstrap.log(LogLevel::INFO, "平台轨迹读取完成");

        if (run_cfg.enable_concurrency) {
            bootstrap.log(LogLevel::WARN, "当前实现为最小版本，暂不启用写出并发，按顺序写入");
        }

        EchoEngine engine(radar, run_cfg, bootstrap);
        engine.generate(wf, targets, platform, codebook, output_path);

        bootstrap.log(LogLevel::INFO, "处理完成，输出文件: " + output_path);
        return 0;
    }
    catch (const std::exception& ex) {
        bootstrap.log(LogLevel::ERROR, ex.what());
        return 1;
    }
}


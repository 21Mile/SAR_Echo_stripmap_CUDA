#include "readers.hpp"

#include <cstdint>
#include <fstream>
#include <stdexcept>

WaveformData readWaveforms(const std::string& path, std::size_t N_rg, const RadarParams& radar)
{
    std::ifstream ifs(path, std::ios::binary);
    if (!ifs) {
        throw std::runtime_error("无法打开 waveforms_f0.bin: " + path);
    }

    ifs.seekg(0, std::ios::end);
    const std::size_t bytes = static_cast<std::size_t>(ifs.tellg());
    ifs.seekg(0, std::ios::beg);

    const std::size_t bytes_per_row = sizeof(double) * 2 * N_rg;
    if (bytes_per_row == 0 || bytes % bytes_per_row != 0) {
        throw std::runtime_error("waveforms_f0.bin 尺寸与 N_rg 不匹配");
    }

    const std::size_t n_trans = bytes / bytes_per_row;
    if (n_trans == 0) {
        throw std::runtime_error("waveforms_f0.bin 中未找到波形行");
    }

    if (radar.N_trans_declared > 0 && radar.N_trans_declared != n_trans) {
        throw std::runtime_error("waveforms_f0.bin 推断的 N_trans 与 radar_params.json 不一致");
    }

    std::vector<double> raw(bytes / sizeof(double));
    ifs.read(reinterpret_cast<char*>(raw.data()), static_cast<std::streamsize>(bytes));
    if (!ifs) {
        throw std::runtime_error("读取 waveforms_f0.bin 失败");
    }

    WaveformData wf;
    wf.n_trans = n_trans;
    wf.n_rg = N_rg;
    wf.data.resize(n_trans * N_rg);

    // Row-Block + R/I 交织，转为行块复数（保持 double 精度）
    for (std::size_t idx = 0; idx < n_trans * N_rg; ++idx) {
        wf.data[idx].x = raw[2 * idx];
        wf.data[idx].y = raw[2 * idx + 1];
    }

    return wf;
}

std::vector<DeviceTarget> readTargets(const std::string& path)
{
    std::ifstream ifs(path, std::ios::binary);
    if (!ifs) {
        throw std::runtime_error("无法打开 target_list.bin: " + path);
    }

    ifs.seekg(0, std::ios::end);
    const std::size_t bytes = static_cast<std::size_t>(ifs.tellg());
    ifs.seekg(0, std::ios::beg);

    const std::size_t record_bytes = sizeof(double) * 5;
    if (bytes % record_bytes != 0) {
        throw std::runtime_error("target_list.bin 大小不是 5 * double 的整数倍");
    }
    const std::size_t n_targets = bytes / record_bytes;

    std::vector<double> raw(bytes / sizeof(double));
    ifs.read(reinterpret_cast<char*>(raw.data()), static_cast<std::streamsize>(bytes));
    if (!ifs) {
        throw std::runtime_error("读取 target_list.bin 失败");
    }

    std::vector<DeviceTarget> targets(n_targets);
    for (std::size_t i = 0; i < n_targets; ++i) {
        const std::size_t base = i * 5;
        targets[i].x = raw[base];
        targets[i].y = raw[base + 1];
        targets[i].z = raw[base + 2];
        targets[i].cr = raw[base + 3];
        targets[i].ci = raw[base + 4];
    }
    return targets;
}

PlatformData readPlatform(const std::string& path, std::size_t N_az)
{
    std::ifstream ifs(path, std::ios::binary);
    if (!ifs) {
        throw std::runtime_error("无法打开 platform_pos.bin: " + path);
    }

    ifs.seekg(0, std::ios::end);
    const std::size_t bytes = static_cast<std::size_t>(ifs.tellg());
    ifs.seekg(0, std::ios::beg);

    const std::size_t expected = sizeof(double) * 6 * N_az;
    if (bytes != expected) {
        throw std::runtime_error("platform_pos.bin 大小与 N_az 不匹配");
    }

    std::vector<double> raw(bytes / sizeof(double));
    ifs.read(reinterpret_cast<char*>(raw.data()), static_cast<std::streamsize>(bytes));
    if (!ifs) {
        throw std::runtime_error("读取 platform_pos.bin 失败");
    }

    PlatformData pd;
    pd.tx_x.resize(N_az);
    pd.tx_y.resize(N_az);
    pd.tx_z.resize(N_az);
    pd.rx_x.resize(N_az);
    pd.rx_y.resize(N_az);
    pd.rx_z.resize(N_az);

    for (std::size_t i = 0; i < N_az; ++i) {
        const std::size_t base = i * 6;
        pd.tx_x[i] = raw[base];
        pd.tx_y[i] = raw[base + 1];
        pd.tx_z[i] = raw[base + 2];
        pd.rx_x[i] = raw[base + 3];
        pd.rx_y[i] = raw[base + 4];
        pd.rx_z[i] = raw[base + 5];
    }

    return pd;
}

std::vector<int> readCodebook(const std::string& path, std::size_t N_az, std::size_t n_trans)
{
    std::ifstream ifs(path, std::ios::binary);
    if (!ifs) {
        throw std::runtime_error("无法打开 waveform_codebook.bin: " + path);
    }

    ifs.seekg(0, std::ios::end);
    const std::size_t bytes = static_cast<std::size_t>(ifs.tellg());
    ifs.seekg(0, std::ios::beg);

    const std::size_t expected = sizeof(std::int32_t) * N_az;
    if (bytes != expected) {
        throw std::runtime_error("waveform_codebook.bin 大小与 N_az 不匹配");
    }

    std::vector<std::int32_t> raw(N_az);
    ifs.read(reinterpret_cast<char*>(raw.data()), static_cast<std::streamsize>(bytes));
    if (!ifs) {
        throw std::runtime_error("读取 waveform_codebook.bin 失败");
    }

    std::vector<int> codebook(N_az);
    for (std::size_t i = 0; i < N_az; ++i) {
        if (raw[i] < 0 || raw[i] >= static_cast<std::int32_t>(n_trans)) {
            throw std::runtime_error("codebook 条目超出 [0, N_trans-1] 范围");
        }
        codebook[i] = static_cast<int>(raw[i]);
    }

    return codebook;
}


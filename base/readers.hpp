#pragma once

#include <string>
#include <vector>

#include "config.hpp"
#include "types.hpp"

struct PlatformData
{
    std::vector<double> tx_x;
    std::vector<double> tx_y;
    std::vector<double> tx_z;
    std::vector<double> rx_x;
    std::vector<double> rx_y;
    std::vector<double> rx_z;
};

struct WaveformData
{
    std::size_t n_trans = 0;
    std::size_t n_rg = 0;
    std::vector<DeviceComplex> data; // 琛屽潡瀛樺偍
};

WaveformData readWaveforms(const std::string& path, std::size_t N_rg, const RadarParams& radar);
std::vector<DeviceTarget> readTargets(const std::string& path);
PlatformData readPlatform(const std::string& path, std::size_t N_az);
std::vector<int> readCodebook(const std::string& path, std::size_t N_az, std::size_t n_trans);



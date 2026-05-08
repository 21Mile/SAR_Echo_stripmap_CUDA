#include "config.hpp"
#include "json.hpp"

#include <fstream>
#include <stdexcept>

RadarParams loadRadarParams(const std::string& path)
{
    std::ifstream ifs(path);
    if (!ifs) {
        throw std::runtime_error("cannot open radar_params.json: " + path);
    }

    nlohmann::json j;
    ifs >> j;

    RadarParams p;
    p.schema_version = j.value("schema_version", 0);
    p.c = j.at("c").get<double>();
    p.lambda = j.at("lambda").get<double>();
    p.fc = j.at("fc").get<double>();
    p.B = j.at("B").get<double>();
    p.fs = j.at("fs").get<double>();
    p.PRF = j.at("PRF").get<double>();
    p.Tp = j.at("Tp").get<double>();
    p.va = j.at("va").get<double>();
    p.H = j.at("H").get<double>();
    p.R0 = j.at("R0").get<double>();
    p.Ba = j.value("Ba", 0.0);
    if (j.contains("Ta")) {
        p.Ta = j.at("Ta").get<double>();
    }
    if (p.Ta <= 0.0 && p.Ba > 0.0) {
        if (p.va == 0.0) {
            throw std::runtime_error("radar_params.json: va must be non-zero to derive Ta");
        }
        p.Ta = p.Ba * p.lambda / (2.0 * p.va) * p.R0 / p.va;
    }
    if (p.Ta <= 0.0) {
        throw std::runtime_error("radar_params.json: Ta missing or non-positive");
    }
    p.N_az = static_cast<std::size_t>(j.at("N_az").get<double>());
    p.N_rg = static_cast<std::size_t>(j.at("N_rg").get<double>());
    p.monostatic = j.value("monostatic", true);
    p.layout = j.value("layout", std::string("col_major"));
    if (j.contains("N_trans")) {
        p.N_trans_declared = static_cast<std::size_t>(j.at("N_trans").get<double>());
    }

    return p;
}

RunningParams loadRunningParams(const std::string& path, Logger& logger)
{
    RunningParams p;

    std::ifstream ifs(path);
    if (!ifs) {
        logger.log(LogLevel::WARN, "running_params.json not found, using defaults");
        return p;
    }

    nlohmann::json j;
    ifs >> j;

    p.enable_concurrency = j.value("enable_concurrency", false);
    p.batch_cols = j.value("batch_cols", 16);
    p.enable_random_phase = j.value("enable_random_phase", true);
    p.enable_mixed_precision = j.value("enable_mixed_precision", true);
    p.device_id = j.value("device_id", 0);
    p.logger_level = parseLogLevel(j.value("logger_level", std::string("INFO")));

    if (p.batch_cols <= 0) {
        logger.log(LogLevel::WARN, "batch_cols <= 0, reset to 16");
        p.batch_cols = 16;
    }
    if (p.device_id < 0) {
        logger.log(LogLevel::WARN, "device_id < 0, reset to 0");
        p.device_id = 0;
    }

    return p;
}


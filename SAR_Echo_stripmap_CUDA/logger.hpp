#pragma once

#include <chrono>
#include <cctype>
#include <cstdio>
#include <iostream>
#include <mutex>
#include <sstream>
#include <string>
#include <thread>

// 线程安全的简易控制台日志（毫秒时间戳）
enum class LogLevel
{
    DEBUG = 0,
    INFO,
    WARN,
    ERROR
};

class Logger
{
public:
    explicit Logger(LogLevel lvl) : level_(lvl) {}

    void setLevel(LogLevel lvl) { level_ = lvl; }
    LogLevel level() const { return level_; }

    void log(LogLevel lvl, const std::string& msg)
    {
        if (static_cast<int>(lvl) < static_cast<int>(level_)) {
            return;
        }

        const auto now = std::chrono::system_clock::now();
        const auto tt = std::chrono::system_clock::to_time_t(now);
        const auto ms = std::chrono::duration_cast<std::chrono::milliseconds>(now.time_since_epoch()) % 1000;

        std::tm tm_buf{};
#if defined(_WIN32)
        localtime_s(&tm_buf, &tt);
#else
        localtime_r(&tt, &tm_buf);
#endif

        char time_buf[32];
        std::snprintf(time_buf,
                      sizeof(time_buf),
                      "%04d-%02d-%02d %02d:%02d:%02d.%03lld",
                      tm_buf.tm_year + 1900,
                      tm_buf.tm_mon + 1,
                      tm_buf.tm_mday,
                      tm_buf.tm_hour,
                      tm_buf.tm_min,
                      tm_buf.tm_sec,
                      static_cast<long long>(ms.count()));

        std::ostringstream oss;
        oss << "[" << time_buf << "]";
        oss << "[" << levelToString(lvl) << "]";
        oss << "[" << std::this_thread::get_id() << "] " << msg;

        std::lock_guard<std::mutex> lock(mu_);
        std::cout << oss.str() << std::endl;
    }

private:
    static std::string levelToString(LogLevel lvl)
    {
        switch (lvl) {
        case LogLevel::DEBUG: return "DEBUG";
        case LogLevel::INFO: return "INFO";
        case LogLevel::WARN: return "WARN";
        case LogLevel::ERROR: return "ERROR";
        }
        return "INFO";
    }

    LogLevel level_;
    std::mutex mu_;
};

inline LogLevel parseLogLevel(const std::string& txt)
{
    std::string up = txt;
    for (char& c : up) {
        c = static_cast<char>(std::toupper(static_cast<unsigned char>(c)));
    }
    if (up == "DEBUG") return LogLevel::DEBUG;
    if (up == "INFO") return LogLevel::INFO;
    if (up == "WARN" || up == "WARNING") return LogLevel::WARN;
    if (up == "ERROR") return LogLevel::ERROR;
    return LogLevel::INFO;
}


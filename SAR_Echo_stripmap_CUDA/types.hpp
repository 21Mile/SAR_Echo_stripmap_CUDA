#pragma once

#include <cstddef>

// 基础复数类型（与文件存储 R/I 顺序一致）
struct Complex
{
    double r;
    double i;
};

// GPU 侧复数类型（字段名与 cuFFT 对齐，计算用 double）
struct DeviceComplex
{
    double x;
    double y;
};

// GPU 侧复数类型（float 版本，供混合精度使用）
struct DeviceComplexF
{
    float x;
    float y;
};

// 目标参数（位置 + 复散射系数）
struct DeviceTarget
{
    double x;
    double y;
    double z;
    double cr;
    double ci;
};


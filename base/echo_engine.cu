#include "echo_engine.hpp"

#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <algorithm>
#include <cmath>
#include <fstream>
#include <sstream>
#include <stdexcept>
#include <string>
#include <vector>

#include "types.hpp"

namespace
{
constexpr double kPi = 3.14159265358979323846;

// 频域累加：几何/距离/波形全部用 double 累加，降低相位精度损失
__global__ void accumulateFrequency(const double* tx_x,
                                    const double* tx_y,
                                    const double* tx_z,
                                    const double* rx_x,
                                    const double* rx_y,
                                    const double* rx_z,
                                    const DeviceTarget* targets,
                                    int n_targets,
                                    const DeviceComplex* waveforms,
                                    int n_rg,
                                    int n_trans,
                                    const double* fr,
                                    double fc,
                                    double inv_c,
                                    double R0,
                                    double az_gate_half,
                                    int az_offset,
                                    int batch_size,
                                    const int* codebook,
                                    DeviceComplex* out)
{
    const int rg = blockIdx.x * blockDim.x + threadIdx.x;
    const int az_local = blockIdx.y;
    if (rg >= n_rg || az_local >= batch_size) {
        return;
    }

    const int az = az_offset + az_local;
    const int wf_idx = codebook[az];

    const double txX = tx_x[az];
    const double txY = tx_y[az];
    const double txZ = tx_z[az];
    const double rxX = rx_x[az];
    const double rxY = rx_y[az];
    const double rxZ = rx_z[az];

    const DeviceComplex wf = waveforms[wf_idx * n_rg + rg];
    const double freq = fr[rg];

    // 使用 double 累加，降低远距离相位带来的精度损失
    double acc_r = 0.0;
    double acc_i = 0.0;
    const double two_over_c = 2.0 * inv_c;

    for (int t = 0; t < n_targets; ++t) {
        const DeviceTarget tgt = targets[t];

        const double dx_tx = txX - tgt.x;
        const double dy_tx = txY - tgt.y;
        const double dz_tx = txZ - tgt.z;
        const double dx_rx = rxX - tgt.x;
        const double dy_rx = rxY - tgt.y;
        const double dz_rx = rxZ - tgt.z;

        if (fabs(dx_tx) >= az_gate_half) {
            continue;
        }

        const double r_tx = sqrt(dx_tx * dx_tx + dy_tx * dy_tx + dz_tx * dz_tx);
        const double r_rx = sqrt(dx_rx * dx_rx + dy_rx * dy_rx + dz_rx * dz_rx);

        const double delay = (r_tx + r_rx) * static_cast<double>(inv_c);
        const double delay_relative = delay - static_cast<double>(two_over_c) * static_cast<double>(R0);

        const double phase = -2.0 * kPi * (static_cast<double>(freq) * delay_relative + static_cast<double>(fc) * delay);
        double s_val, c_val;
        sincos(phase, &s_val, &c_val);

        const double coeff_r = tgt.cr * c_val - tgt.ci * s_val;
        const double coeff_i = tgt.cr * s_val + tgt.ci * c_val;

        acc_r += static_cast<double>(wf.x) * coeff_r - static_cast<double>(wf.y) * coeff_i;
        acc_i += static_cast<double>(wf.x) * coeff_i + static_cast<double>(wf.y) * coeff_r;
    }

    // 对齐频谱中心的 fftshift，直接输出频域回波
    const int shifted = (rg + n_rg / 2) % n_rg;
    const int idx = az_local * n_rg + shifted;
    // 写出 double 精度（与文件接口一致），避免精度损失
    out[idx].x = static_cast<double>(acc_r);
    out[idx].y = static_cast<double>(acc_i);
}

// 混合精度版本：波形用 float，频率/几何/累加用 double
__global__ void accumulateFrequencyMixed(const double* tx_x,
                                         const double* tx_y,
                                         const double* tx_z,
                                         const double* rx_x,
                                         const double* rx_y,
                                         const double* rx_z,
                                         const DeviceTarget* targets,
                                         int n_targets,
                                         const DeviceComplexF* waveforms,
                                         int n_rg,
                                         int n_trans,
                                         const double* fr,
                                         double fc,
                                         double inv_c,
                                         double R0,
                                         double az_gate_half,
                                         int az_offset,
                                         int batch_size,
                                         const int* codebook,
                                         DeviceComplex* out)
{
    const int rg = blockIdx.x * blockDim.x + threadIdx.x;
    const int az_local = blockIdx.y;
    if (rg >= n_rg || az_local >= batch_size) {
        return;
    }

    const int az = az_offset + az_local;
    const int wf_idx = codebook[az];

    const double txX = tx_x[az];
    const double txY = tx_y[az];
    const double txZ = tx_z[az];
    const double rxX = rx_x[az];
    const double rxY = rx_y[az];
    const double rxZ = rx_z[az];

    const DeviceComplexF wf = waveforms[wf_idx * n_rg + rg];
    const double freq = fr[rg];

    double acc_r = 0.0;
    double acc_i = 0.0;
    const double two_over_c = 2.0 * inv_c;

    for (int t = 0; t < n_targets; ++t) {
        const DeviceTarget tgt = targets[t];

        const double dx_tx = txX - tgt.x;
        const double dy_tx = txY - tgt.y;
        const double dz_tx = txZ - tgt.z;
        const double dx_rx = rxX - tgt.x;
        const double dy_rx = rxY - tgt.y;
        const double dz_rx = rxZ - tgt.z;

        if (fabs(dx_tx) >= az_gate_half) {
            continue;
        }

        const double r_tx = sqrt(dx_tx * dx_tx + dy_tx * dy_tx + dz_tx * dz_tx);
        const double r_rx = sqrt(dx_rx * dx_rx + dy_rx * dy_rx + dz_rx * dz_rx);

        const double delay = (r_tx + r_rx) * static_cast<double>(inv_c);
        const double delay_relative = delay - static_cast<double>(two_over_c) * static_cast<double>(R0);

        const double phase = -2.0 * kPi * (freq * delay_relative + fc * delay);
        double s_val, c_val;
        sincos(phase, &s_val, &c_val);

        const double coeff_r = tgt.cr * c_val - tgt.ci * s_val;
        const double coeff_i = tgt.cr * s_val + tgt.ci * c_val;

        acc_r += static_cast<double>(wf.x) * coeff_r - static_cast<double>(wf.y) * coeff_i;
        acc_i += static_cast<double>(wf.x) * coeff_i + static_cast<double>(wf.y) * coeff_r;
    }

    const int shifted = (rg + n_rg / 2) % n_rg;
    const int idx = az_local * n_rg + shifted;
    out[idx].x = acc_r;
    out[idx].y = acc_i;
}

inline void checkCuda(cudaError_t err, const char* msg)
{
    if (err != cudaSuccess) {
        std::ostringstream oss;
        oss << msg << " (code " << static_cast<int>(err) << "): " << cudaGetErrorString(err);
        throw std::runtime_error(oss.str());
    }
}

template <typename T>
class DeviceBuffer
{
public:
    DeviceBuffer() = default;
    ~DeviceBuffer() { reset(); }

    DeviceBuffer(const DeviceBuffer&) = delete;
    DeviceBuffer& operator=(const DeviceBuffer&) = delete;

    void allocate(std::size_t count, const char* name)
    {
        reset();
        if (count == 0) return;
        checkCuda(cudaMalloc(&ptr_, sizeof(T) * count), name);
        size_ = count;
    }

    void reset()
    {
        if (ptr_) {
            cudaFree(ptr_);
            ptr_ = nullptr;
            size_ = 0;
        }
    }

    T* get() { return ptr_; }
    const T* get() const { return ptr_; }
    std::size_t size() const { return size_; }

private:
    T* ptr_{ nullptr };
    std::size_t size_{ 0 };
};

} // namespace

EchoEngine::EchoEngine(const RadarParams& radar,
                       const RunningParams& run,
                       Logger& logger)
    : radar_(radar), run_(run), logger_(logger)
{
}

void EchoEngine::generate(const WaveformData& wf,
                          const std::vector<DeviceTarget>& targets,
                          const PlatformData& platform,
                          const std::vector<int>& codebook,
                          const std::string& output_path)
{
    if (wf.n_rg != radar_.N_rg) {
        throw std::runtime_error("waveform N_rg mismatch radar_params.json");
    }
    if (wf.n_trans == 0) {
        throw std::runtime_error("waveforms_f0.bin contains zero rows");
    }
    if (radar_.N_az == 0 || radar_.N_rg == 0) {
        throw std::runtime_error("N_az or N_rg invalid");
    }
    if (platform.tx_x.size() != radar_.N_az) {
        throw std::runtime_error("platform_pos.bin size mismatch N_az");
    }
    if (codebook.size() != radar_.N_az) {
        throw std::runtime_error("codebook size mismatch N_az");
    }
    for (std::size_t i = 0; i < codebook.size(); ++i) {
        if (codebook[i] < 0 || codebook[i] >= static_cast<int>(wf.n_trans)) {
            throw std::runtime_error("codebook entry out of [0, N_trans-1] range");
        }
    }

    logger_.log(LogLevel::INFO, "Set CUDA device " + std::to_string(run_.device_id));
    checkCuda(cudaSetDevice(run_.device_id), "cudaSetDevice");

    std::vector<double> fr(radar_.N_rg);
    const double df = radar_.fs / static_cast<double>(radar_.N_rg);
    for (std::size_t i = 0; i < radar_.N_rg; ++i) {
        fr[i] = (static_cast<double>(i) - static_cast<double>(radar_.N_rg) / 2.0) * df;
    }

    DeviceBuffer<DeviceTarget> d_targets;
    if (!targets.empty()) {
        d_targets.allocate(targets.size(), "cudaMalloc targets");
        checkCuda(cudaMemcpy(d_targets.get(),
                             targets.data(),
                             targets.size() * sizeof(DeviceTarget),
                             cudaMemcpyHostToDevice),
                  "cudaMemcpy targets");
    }

    DeviceBuffer<DeviceComplex> d_waveforms;
    DeviceBuffer<DeviceComplexF> d_waveforms_f;
    bool use_mixed = run_.enable_mixed_precision;
    if (use_mixed) {
        std::vector<DeviceComplexF> wf_f(wf.data.size());
        for (std::size_t i = 0; i < wf.data.size(); ++i) {
            wf_f[i].x = static_cast<float>(wf.data[i].x);
            wf_f[i].y = static_cast<float>(wf.data[i].y);
        }
        d_waveforms_f.allocate(wf_f.size(), "cudaMalloc waveforms_f");
        checkCuda(cudaMemcpy(d_waveforms_f.get(),
                             wf_f.data(),
                             wf_f.size() * sizeof(DeviceComplexF),
                             cudaMemcpyHostToDevice),
                  "cudaMemcpy waveforms_f");
    }
    else {
        d_waveforms.allocate(wf.data.size(), "cudaMalloc waveforms");
        checkCuda(cudaMemcpy(d_waveforms.get(),
                             wf.data.data(),
                             wf.data.size() * sizeof(DeviceComplex),
                             cudaMemcpyHostToDevice),
                  "cudaMemcpy waveforms");
    }

    DeviceBuffer<double> d_fr;
    d_fr.allocate(radar_.N_rg, "cudaMalloc fr");
    checkCuda(cudaMemcpy(d_fr.get(),
                         fr.data(),
                         radar_.N_rg * sizeof(double),
                         cudaMemcpyHostToDevice),
              "cudaMemcpy fr");

    DeviceBuffer<double> d_tx_x;
    DeviceBuffer<double> d_tx_y;
    DeviceBuffer<double> d_tx_z;
    DeviceBuffer<double> d_rx_x;
    DeviceBuffer<double> d_rx_y;
    DeviceBuffer<double> d_rx_z;
    DeviceBuffer<int> d_codebook;

    d_tx_x.allocate(radar_.N_az, "cudaMalloc tx_x");
    d_tx_y.allocate(radar_.N_az, "cudaMalloc tx_y");
    d_tx_z.allocate(radar_.N_az, "cudaMalloc tx_z");
    d_rx_x.allocate(radar_.N_az, "cudaMalloc rx_x");
    d_rx_y.allocate(radar_.N_az, "cudaMalloc rx_y");
    d_rx_z.allocate(radar_.N_az, "cudaMalloc rx_z");
    d_codebook.allocate(radar_.N_az, "cudaMalloc codebook");

    checkCuda(cudaMemcpy(d_tx_x.get(), platform.tx_x.data(), radar_.N_az * sizeof(double), cudaMemcpyHostToDevice), "cudaMemcpy tx_x");
    checkCuda(cudaMemcpy(d_tx_y.get(), platform.tx_y.data(), radar_.N_az * sizeof(double), cudaMemcpyHostToDevice), "cudaMemcpy tx_y");
    checkCuda(cudaMemcpy(d_tx_z.get(), platform.tx_z.data(), radar_.N_az * sizeof(double), cudaMemcpyHostToDevice), "cudaMemcpy tx_z");
    checkCuda(cudaMemcpy(d_rx_x.get(), platform.rx_x.data(), radar_.N_az * sizeof(double), cudaMemcpyHostToDevice), "cudaMemcpy rx_x");
    checkCuda(cudaMemcpy(d_rx_y.get(), platform.rx_y.data(), radar_.N_az * sizeof(double), cudaMemcpyHostToDevice), "cudaMemcpy rx_y");
    checkCuda(cudaMemcpy(d_rx_z.get(), platform.rx_z.data(), radar_.N_az * sizeof(double), cudaMemcpyHostToDevice), "cudaMemcpy rx_z");
    checkCuda(cudaMemcpy(d_codebook.get(), codebook.data(), radar_.N_az * sizeof(int), cudaMemcpyHostToDevice), "cudaMemcpy codebook");

    const int batch_cols = std::max(1, run_.batch_cols);
    DeviceBuffer<DeviceComplex> d_workspace;
    d_workspace.allocate(static_cast<std::size_t>(batch_cols) * radar_.N_rg, "cudaMalloc workspace");
    // 复用主机缓冲，减少每批分配；直接写结构体（double x/y），避免额外复制转换
    std::vector<DeviceComplex> host_batch(static_cast<std::size_t>(batch_cols) * radar_.N_rg);

    std::ofstream ofs(output_path, std::ios::binary | std::ios::trunc);
    if (!ofs) {
        throw std::runtime_error("cannot create output file");
    }

    const dim3 block(256, 1);
    const int grid_x = static_cast<int>((radar_.N_rg + block.x - 1) / block.x);

    const double inv_c = 1.0 / radar_.c;
    const double az_gate_half_range = 0.5 * radar_.va * radar_.Ta;

    for (std::size_t az0 = 0; az0 < radar_.N_az; az0 += static_cast<std::size_t>(batch_cols)) {
        const int batch = static_cast<int>(std::min<std::size_t>(batch_cols, radar_.N_az - az0));
        const dim3 grid(grid_x, static_cast<unsigned int>(batch));

        if (use_mixed) {
            accumulateFrequencyMixed<<<grid, block>>>(d_tx_x.get(),
                                                      d_tx_y.get(),
                                                      d_tx_z.get(),
                                                      d_rx_x.get(),
                                                      d_rx_y.get(),
                                                      d_rx_z.get(),
                                                      d_targets.get(),
                                                      static_cast<int>(targets.size()),
                                                      d_waveforms_f.get(),
                                                      static_cast<int>(radar_.N_rg),
                                                      static_cast<int>(wf.n_trans),
                                                      d_fr.get(),
                                                      radar_.fc,
                                                      inv_c,
                                                      radar_.R0,
                                                      az_gate_half_range,
                                                      static_cast<int>(az0),
                                                      batch,
                                                      d_codebook.get(),
                                                      d_workspace.get());
        }
        else {
            accumulateFrequency<<<grid, block>>>(d_tx_x.get(),
                                                 d_tx_y.get(),
                                                 d_tx_z.get(),
                                                 d_rx_x.get(),
                                                 d_rx_y.get(),
                                                 d_rx_z.get(),
                                                 d_targets.get(),
                                                 static_cast<int>(targets.size()),
                                                 d_waveforms.get(),
                                                 static_cast<int>(radar_.N_rg),
                                                 static_cast<int>(wf.n_trans),
                                                 d_fr.get(),
                                                 radar_.fc,
                                                 inv_c,
                                                 radar_.R0,
                                                 az_gate_half_range,
                                                 static_cast<int>(az0),
                                                 batch,
                                                 d_codebook.get(),
                                                 d_workspace.get());
        }
        checkCuda(cudaGetLastError(), "accumulateFrequency launch");

        const std::size_t elems = static_cast<std::size_t>(batch) * radar_.N_rg;
        checkCuda(cudaMemcpy(host_batch.data(),
                             d_workspace.get(),
                             elems * sizeof(DeviceComplex),
                             cudaMemcpyDeviceToHost),
                  "cudaMemcpy output");

        ofs.write(reinterpret_cast<const char*>(host_batch.data()),
                  static_cast<std::streamsize>(elems * sizeof(DeviceComplex)));
        if (!ofs) {
            throw std::runtime_error("write raw_echo_data.bin failed");
        }

        std::size_t done = az0 + static_cast<std::size_t>(batch);
        int percent = static_cast<int>(100.0 * done / radar_.N_az + 0.5);
        logger_.log(LogLevel::INFO, "progress: " + std::to_string(done) + "/" + std::to_string(radar_.N_az) + " (" + std::to_string(percent) + "%)");
    }

    checkCuda(cudaDeviceSynchronize(), "cudaDeviceSynchronize");
    ofs.close();
}


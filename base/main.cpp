#include "echo_app.hpp"

#if defined(_WIN32)
#include <windows.h>
#endif

int main(int argc, char** argv)
{
#if defined(_WIN32)
    // 设置控制台为 UTF-8，避免中文日志乱码
    SetConsoleOutputCP(CP_UTF8);
    SetConsoleCP(CP_UTF8);
#endif
    EchoApp app;
    return app.run(argc, argv);
}


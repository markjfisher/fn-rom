// g++ -std=c++17 -O2 -Wall client.cpp -o client
#include <fcntl.h>
#include <unistd.h>
#include <termios.h>
#include <sys/select.h>
#include <cstdio>
#include <cstring>
#include <iostream>
#include <string>

static bool set_raw(int fd) {
    termios tio{};
    if (tcgetattr(fd, &tio) < 0) return false;
    cfmakeraw(&tio);
    tio.c_cflag |= (CLOCAL | CREAD);
    tio.c_cc[VMIN]  = 1;
    tio.c_cc[VTIME] = 1;
    return tcsetattr(fd, TCSANOW, &tio) == 0;
}

int main(int argc, char** argv) {
    if (argc < 2) {
        std::cerr << "usage: " << argv[0] << " /dev/pts/N\n";
        return 1;
    }
    const char* pty_path = argv[1];

    int fd = open(pty_path, O_RDWR | O_NOCTTY);
    if (fd < 0) { std::perror("open"); return 1; }
    if (!set_raw(fd)) { std::perror("termios"); return 1; }

    // Example: send a line
    const char* msg = "Hello over PTY -> /dev/ttyS0\r\n";
    if (write(fd, msg, std::strlen(msg)) < 0) { std::perror("write"); }

    std::cout << "Waiting to receive...\n";

    // Read and print anything that comes back for ~5 seconds
    for (int i = 0; i < 50; ++i) {
        fd_set rd; FD_ZERO(&rd); FD_SET(fd, &rd);
        timeval tv{.tv_sec = 0, .tv_usec = 100000};
        int rv = select(fd+1, &rd, nullptr, nullptr, &tv);
        if (rv > 0 && FD_ISSET(fd, &rd)) {
            char buf[1024];
            ssize_t n = read(fd, buf, sizeof(buf));
            if (n > 0) write(STDOUT_FILENO, buf, n);
        }
    }
    close(fd);
    return 0;
}

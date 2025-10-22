// g++ -std=c++17 -O2 -Wall bridge.cpp -o bridge
#include <fcntl.h>
#include <unistd.h>
#include <termios.h>
#include <sys/ioctl.h>
#include <sys/select.h>
#include <sys/stat.h>
#include <cstring>
#include <cerrno>
#include <cstdio>
#include <string>
#include <iostream>

static bool set_serial_raw(int fd, speed_t baud) {
    termios tio{};
    if (tcgetattr(fd, &tio) < 0) return false;
    cfmakeraw(&tio);
    tio.c_cflag |= (CLOCAL | CREAD);
    cfsetispeed(&tio, baud);
    cfsetospeed(&tio, baud);
    // Optional: block until at least 1 byte or 100ms
    tio.c_cc[VMIN]  = 1;
    tio.c_cc[VTIME] = 1; // 0.1s
    return tcsetattr(fd, TCSANOW, &tio) == 0;
}

static bool set_pty_raw(int fd) {
    termios tio{};
    if (tcgetattr(fd, &tio) < 0) return false;
    cfmakeraw(&tio);
    tio.c_cflag |= (CLOCAL | CREAD);
    tio.c_cc[VMIN]  = 1;
    tio.c_cc[VTIME] = 1;
    return tcsetattr(fd, TCSANOW, &tio) == 0;
}

int main(int argc, char** argv) {
    const char* serial_path = (argc > 1) ? argv[1] : "/dev/ttyS0";
    speed_t baud = B115200; // change if you need a different baud

    // 1) Open the real serial port
    int sfd = open(serial_path, O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (sfd < 0) {
        std::perror("open serial");
        return 1;
    }
    if (!set_serial_raw(sfd, baud)) {
        std::perror("serial termios");
        return 1;
    }

    // 2) Create PTY master and get slave name
    int mfd = posix_openpt(O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (mfd < 0) {
        std::perror("posix_openpt");
        return 1;
    }
    if (grantpt(mfd) < 0 || unlockpt(mfd) < 0) {
        std::perror("grantpt/unlockpt");
        return 1;
    }
    char* slave_name_c = ptsname(mfd);
    if (!slave_name_c) {
        std::perror("ptsname");
        return 1;
    }
    std::string slave_path = slave_name_c;

    // Open the slave once to set raw on it (and keep it open to prevent I/O errors)
    int sld = open(slave_path.c_str(), O_RDWR | O_NOCTTY | O_NONBLOCK);
    if (sld < 0) {
        std::perror("open pty slave");
        return 1;
    }
    if (!set_pty_raw(sld)) {
        std::perror("pty termios");
        return 1;
    }
    // Keep slave open - closing it causes I/O errors when reading from master

    std::cout << "PTY ready. Connect your other program to: " << slave_path << "\n"
              << "Bridging " << serial_path << " <-> " << slave_path << "\n";

    // 3) Pump bytes both ways using select()
    constexpr size_t BUFSZ = 4096;
    char buf[BUFSZ];

    while (true) {
        fd_set rd;
        FD_ZERO(&rd);
        FD_SET(sfd, &rd);
        FD_SET(mfd, &rd);
        int maxfd = (sfd > mfd ? sfd : mfd) + 1;

        timeval tv{.tv_sec = 5, .tv_usec = 0}; // wake up periodically
        int rv = select(maxfd, &rd, nullptr, nullptr, &tv);
        if (rv < 0) {
            if (errno == EINTR) continue;
            std::perror("select");
            break;
        }
        // PTY -> Serial
        if (FD_ISSET(mfd, &rd)) {
            ssize_t n = read(mfd, buf, BUFSZ);
            if (n > 0) {
                ssize_t off = 0;
                while (off < n) {
                    ssize_t w = write(sfd, buf + off, n - off);
                    if (w > 0) off += w;
                    else if (w < 0 && errno != EAGAIN && errno != EWOULDBLOCK) {
                        std::perror("write serial");
                        goto done;
                    }
                }
            } else if (n == 0) {
                std::cerr << "PTY closed\n";
                break;
            } else if (errno != EAGAIN && errno != EWOULDBLOCK) {
                std::perror("read pty");
                break;
            }
        }
        // Serial -> PTY
        if (FD_ISSET(sfd, &rd)) {
            ssize_t n = read(sfd, buf, BUFSZ);
            if (n > 0) {
                ssize_t off = 0;
                while (off < n) {
                    ssize_t w = write(mfd, buf + off, n - off);
                    if (w > 0) off += w;
                    else if (w < 0 && errno != EAGAIN && errno != EWOULDBLOCK) {
                        std::perror("write pty");
                        goto done;
                    }
                }
            } else if (n == 0) {
                std::cerr << "Serial port closed\n";
                break;
            } else if (errno != EAGAIN && errno != EWOULDBLOCK) {
                std::perror("read serial");
                break;
            }
        }
    }

done:
    close(sld);
    close(mfd);
    close(sfd);
    return 0;
}

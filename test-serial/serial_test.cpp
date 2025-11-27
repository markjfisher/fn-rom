#include <iostream>
#include <string>
#include <vector>
#include <sstream>
#include <iomanip>
#include <cstdint>
#include <cerrno>
#include <cstring>

#include <termios.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/select.h>

// Helper: map integer baud rate to termios speed_t
speed_t baudToSpeedT(int baud) {
    switch (baud) {
        case 50: return B50;
        case 75: return B75;
        case 110: return B110;
        case 134: return B134;
        case 150: return B150;
        case 200: return B200;
        case 300: return B300;
        case 600: return B600;
        case 1200: return B1200;
        case 1800: return B1800;
        case 2400: return B2400;
        case 4800: return B4800;
        case 9600: return B9600;
        case 19200: return B19200;
        case 38400: return B38400;
        case 57600: return B57600;
        case 115200: return B115200;
#ifdef B230400
        case 230400: return B230400;
#endif
        default:
            return 0; // unsupported
    }
}

// Configure serial/PTY for 8N1, raw mode
bool configurePort(int fd, int baud) {
    speed_t speed = baudToSpeedT(baud);
    if (!speed) {
        std::cerr << "Unsupported baud rate: " << baud << "\n";
        return false;
    }

    struct termios tty;
    if (tcgetattr(fd, &tty) != 0) {
        std::cerr << "tcgetattr error: " << std::strerror(errno) << "\n";
        return false;
    }

    cfmakeraw(&tty);

    // 8N1, local connection, enable receiver
    tty.c_cflag &= ~PARENB; // no parity
    tty.c_cflag &= ~CSTOPB; // 1 stop bit
    tty.c_cflag &= ~CSIZE;
    tty.c_cflag |= CS8;     // 8 data bits
    tty.c_cflag |= CLOCAL | CREAD;

    // No flow control
#ifdef CRTSCTS
    tty.c_cflag &= ~CRTSCTS;
#endif
    tty.c_iflag &= ~(IXON | IXOFF | IXANY);

    // Set baud
    cfsetospeed(&tty, speed);
    cfsetispeed(&tty, speed);

    // Non-blocking reads with a short timeout at the driver level
    tty.c_cc[VMIN]  = 0;
    tty.c_cc[VTIME] = 0; // timeout handled by select()

    if (tcsetattr(fd, TCSANOW, &tty) != 0) {
        std::cerr << "tcsetattr error: " << std::strerror(errno) << "\n";
        return false;
    }

    return true;
}

// Open the PTY/serial device
int openPort(const std::string &path, int baud) {
    int fd = ::open(path.c_str(), O_RDWR | O_NOCTTY | O_SYNC);
    if (fd < 0) {
        std::cerr << "Error opening " << path << ": " << std::strerror(errno) << "\n";
        return -1;
    }

    if (!configurePort(fd, baud)) {
        ::close(fd);
        return -1;
    }

    std::cout << "Opened " << path << " at " << baud << " baud (8N1)\n";
    return fd;
}

// Rolling-carry checksum over first 6 bytes
uint8_t computeChecksum(const uint8_t *data, size_t len) {
    uint16_t sum = 0;
    for (size_t i = 0; i < len; ++i) {
        sum += data[i];
        if (sum > 0xFF) {
            sum = (sum & 0xFF) + 1; // add carry back in
        }
    }
    return static_cast<uint8_t>(sum & 0xFF);
}

// Send a 7-byte packet: 6 data bytes + checksum
bool sendPacket(int fd, const uint8_t bytes6[6]) {
    if (fd < 0) {
        std::cerr << "Port not open.\n";
        return false;
    }

    uint8_t packet[7];
    for (int i = 0; i < 6; ++i) {
        packet[i] = bytes6[i];
    }
    packet[6] = computeChecksum(packet, 6);

    ssize_t written = ::write(fd, packet, sizeof(packet));
    if (written < 0) {
        std::cerr << "write error: " << std::strerror(errno) << "\n";
        return false;
    } else if (written != static_cast<ssize_t>(sizeof(packet))) {
        std::cerr << "Partial write: " << written << " bytes\n";
        return false;
    }

    std::cout << "Sent packet: ";
    for (int i = 0; i < 7; ++i) {
        std::cout << std::hex << std::uppercase << std::setw(2)
                  << std::setfill('0') << (int)packet[i] << " ";
    }
    std::cout << std::dec << "\n";

    return true;
}

// Hex-dump bytes read from the port (non-blocking, with timeout)
void readAndDump(int fd, int timeoutMs, size_t maxBytes) {
    if (fd < 0) {
        std::cerr << "Port not open.\n";
        return;
    }

    fd_set readfds;
    FD_ZERO(&readfds);
    FD_SET(fd, &readfds);

    struct timeval tv;
    tv.tv_sec = timeoutMs / 1000;
    tv.tv_usec = (timeoutMs % 1000) * 1000;

    int ret = select(fd + 1, &readfds, nullptr, nullptr, &tv);
    if (ret < 0) {
        std::cerr << "select error: " << std::strerror(errno) << "\n";
        return;
    } else if (ret == 0) {
        std::cout << "No data within timeout (" << timeoutMs << " ms).\n";
        return;
    }

    std::vector<uint8_t> buffer(maxBytes);
    ssize_t n = ::read(fd, buffer.data(), buffer.size());
    if (n < 0) {
        std::cerr << "read error: " << std::strerror(errno) << "\n";
        return;
    }
    if (n == 0) {
        std::cout << "No data available.\n";
        return;
    }

    std::cout << "Read " << n << " bytes:\n";
    for (ssize_t i = 0; i < n; ++i) {
        std::cout << std::hex << std::uppercase << std::setw(2)
                  << std::setfill('0') << (int)buffer[i] << " ";
        if ((i + 1) % 16 == 0) std::cout << "\n";
    }
    std::cout << std::dec << "\n";
}

// Parse 6 hex bytes from a line, e.g. "70 FF 01 02 03 04"
bool parseSixHexBytes(const std::string &line, uint8_t out[6]) {
    std::istringstream iss(line);
    int value;
    for (int i = 0; i < 6; ++i) {
        if (!(iss >> std::hex >> value)) {
            return false;
        }
        if (value < 0x00 || value > 0xFF) {
            return false;
        }
        out[i] = static_cast<uint8_t>(value);
    }
    return true;
}

void printMenu() {
    std::cout << "\n=== Serial Test Menu ===\n";
    std::cout << "1) Send RESET command (70 FF 00 00 00 00 + checksum)\n";
    std::cout << "2) Send custom 6-byte payload (checksum auto-calculated)\n";
    std::cout << "3) Read and dump incoming bytes\n";
    std::cout << "4) Change device/baud and reopen\n";
    std::cout << "5) Quit\n";
    std::cout << "Select: ";
}

int main() {
    std::string devicePath;
    int baudRate = 115200;

    std::cout << "Enter PTY/serial device path (e.g. /dev/pts/5 or /dev/ttyUSB0): ";
    std::getline(std::cin, devicePath);
    if (devicePath.empty()) {
        std::cerr << "Device path cannot be empty.\n";
        return 1;
    }

    std::cout << "Enter baud rate (e.g. 9600, 19200, 115200): ";
    {
        std::string baudStr;
        std::getline(std::cin, baudStr);
        if (!baudStr.empty()) {
            baudRate = std::stoi(baudStr);
        }
    }

    int fd = openPort(devicePath, baudRate);
    if (fd < 0) {
        return 1;
    }

    bool running = true;
    while (running) {
        printMenu();
        std::string choiceLine;
        if (!std::getline(std::cin, choiceLine)) {
            break;
        }
        if (choiceLine.empty()) continue;

        int choice = std::stoi(choiceLine);
        switch (choice) {
            case 1: {
                // RESET: device ID 0x70, command 0xFF, 4 x 0x00
                uint8_t bytes6[6] = {0x70, 0xFF, 0x00, 0x00, 0x00, 0x00};
                sendPacket(fd, bytes6);
                break;
            }
            case 2: {
                std::cout << "Enter 6 hex bytes (e.g. '70 FF 01 02 03 04'): ";
                std::string line;
                std::getline(std::cin, line);
                uint8_t bytes6[6];
                if (!parseSixHexBytes(line, bytes6)) {
                    std::cerr << "Failed to parse 6 hex bytes.\n";
                } else {
                    sendPacket(fd, bytes6);
                }
                break;
            }
            case 3: {
                std::cout << "Enter timeout in ms (default 500): ";
                std::string tline;
                std::getline(std::cin, tline);
                int timeout = 500;
                if (!tline.empty()) {
                    timeout = std::stoi(tline);
                }
                readAndDump(fd, timeout, 256);
                break;
            }
            case 4: {
                ::close(fd);
                std::cout << "Enter new PTY/serial device path: ";
                std::getline(std::cin, devicePath);
                std::cout << "Enter new baud rate: ";
                std::string baudStr;
                std::getline(std::cin, baudStr);
                if (!baudStr.empty()) {
                    baudRate = std::stoi(baudStr);
                }
                fd = openPort(devicePath, baudRate);
                if (fd < 0) {
                    std::cerr << "Failed to reopen port. Exiting.\n";
                    running = false;
                }
                break;
            }
            case 5: {
                running = false;
                break;
            }
            default:
                std::cout << "Unknown choice.\n";
                break;
        }
    }

    if (fd >= 0) {
        ::close(fd);
    }

    std::cout << "Exiting.\n";
    return 0;
}

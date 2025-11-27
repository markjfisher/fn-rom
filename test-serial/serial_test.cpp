#include <iostream>
#include <string>
#include <vector>
#include <sstream>
#include <iomanip>
#include <cstdint>
#include <cerrno>
#include <cstring>
#include <algorithm> // for std::min
#include <chrono>    // for baud timing test

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

// Reverse: map termios speed_t back to integer baud rate (for printing)
int speedTToBaud(speed_t speed) {
    switch (speed) {
        case B50: return 50;
        case B75: return 75;
        case B110: return 110;
        case B134: return 134;
        case B150: return 150;
        case B200: return 200;
        case B300: return 300;
        case B600: return 600;
        case B1200: return 1200;
        case B1800: return 1800;
        case B2400: return 2400;
        case B4800: return 4800;
        case B9600: return 9600;
        case B19200: return 19200;
        case B38400: return 38400;
        case B57600: return 57600;
        case B115200: return 115200;
#ifdef B230400
        case B230400: return 230400;
#endif
        default: return -1;
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
        std::cerr << "tcgetattr error (before configure): " << std::strerror(errno) << "\n";
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

    // Non-blocking reads with timeout handled via select()
    tty.c_cc[VMIN]  = 0;
    tty.c_cc[VTIME] = 0;

    if (tcsetattr(fd, TCSANOW, &tty) != 0) {
        std::cerr << "tcsetattr error (configure): " << std::strerror(errno) << "\n";
        return false;
    }

    // Read back to confirm what the kernel actually set
    struct termios check;
    if (tcgetattr(fd, &check) != 0) {
        std::cerr << "tcgetattr error (verify): " << std::strerror(errno) << "\n";
        return false;
    }
    speed_t is = cfgetispeed(&check);
    speed_t os = cfgetospeed(&check);
    int isBaud = speedTToBaud(is);
    int osBaud = speedTToBaud(os);
    std::cout << "Configured baud: " << baud
              << "  [kernel reports ispeed=" << (isBaud > 0 ? std::to_string(isBaud) : "unknown")
              << ", ospeed=" << (osBaud > 0 ? std::to_string(osBaud) : "unknown")
              << "]\n";

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

    std::cout << "Opened " << path << " at requested " << baud << " baud (8N1)\n";
    return fd;
}

// Rolling-carry checksum over first len bytes
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

// hexdump -C style dump
void dumpBufferHexC(const std::vector<uint8_t> &buffer) {
    if (buffer.empty()) {
        std::cout << "(no data)\n";
        return;
    }

    std::ios oldState(nullptr);
    oldState.copyfmt(std::cout);

    size_t offset = 0;
    while (offset < buffer.size()) {
        size_t lineLen = std::min<size_t>(16, buffer.size() - offset);

        // Offset
        std::cout << std::hex << std::nouppercase << std::setw(8)
                  << std::setfill('0') << offset << "  ";

        // Hex bytes
        for (size_t i = 0; i < 16; ++i) {
            if (i < lineLen) {
                std::cout << std::setw(2) << (int)buffer[offset + i] << ' ';
            } else {
                std::cout << "   ";
            }
            if (i == 7) std::cout << ' ';
        }

        // ASCII
        std::cout << " |";
        for (size_t i = 0; i < lineLen; ++i) {
            uint8_t c = buffer[offset + i];
            if (c >= 32 && c <= 126) {
                std::cout << static_cast<char>(c);
            } else {
                std::cout << '.';
            }
        }
        std::cout << "|\n";

        offset += lineLen;
    }

    std::cout.copyfmt(oldState); // restore formatting
}

// Read data until the line is idle for idleTimeoutMs or maxBytes reached
std::vector<uint8_t> readUntilIdle(int fd, int idleTimeoutMs, size_t maxBytes) {
    std::vector<uint8_t> result;
    if (fd < 0) {
        std::cerr << "Port not open.\n";
        return result;
    }

    while (result.size() < maxBytes) {
        fd_set readfds;
        FD_ZERO(&readfds);
        FD_SET(fd, &readfds);

        struct timeval tv;
        tv.tv_sec = idleTimeoutMs / 1000;
        tv.tv_usec = (idleTimeoutMs % 1000) * 1000;

        int ret = select(fd + 1, &readfds, nullptr, nullptr, &tv);
        if (ret < 0) {
            std::cerr << "select error: " << std::strerror(errno) << "\n";
            break;
        } else if (ret == 0) {
            // idle timeout, no more data
            break;
        }

        uint8_t buf[256];
        ssize_t n = ::read(fd, buf, sizeof(buf));
        if (n < 0) {
            std::cerr << "read error: " << std::strerror(errno) << "\n";
            break;
        }
        if (n == 0) {
            // no data, treat as idle as well
            break;
        }

        size_t toCopy = static_cast<size_t>(n);
        if (result.size() + toCopy > maxBytes) {
            toCopy = maxBytes - result.size();
        }
        result.insert(result.end(), buf, buf + toCopy);

        if (result.size() >= maxBytes) {
            break;
        }
        // loop again; idleTimeoutMs is per gap of no data
    }

    return result;
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

// Send arbitrary bytes as-is, with hex dump
bool sendRaw(int fd, const uint8_t *data, size_t len) {
    if (fd < 0) {
        std::cerr << "Port not open.\n";
        return false;
    }

    ssize_t written = ::write(fd, data, len);
    if (written < 0) {
        std::cerr << "write error: " << std::strerror(errno) << "\n";
        return false;
    } else if (written != (ssize_t)len) {
        std::cerr << "Partial write: " << written << " bytes (expected " << len << ")\n";
        return false;
    }

    std::cout << "Sent " << len << " raw bytes:\n";
    std::vector<uint8_t> v(data, data + len);
    dumpBufferHexC(v);
    return true;
}

// Baud timing self-test: send a large block, tcdrain, measure time
void baudTimingTest(int fd, int baud) {
    if (fd < 0) {
        std::cerr << "Port not open.\n";
        return;
    }
    if (baud <= 0) {
        std::cerr << "Invalid baud rate.\n";
        return;
    }

    const size_t bytesToSend = 50000; // big enough to notice at low baud
    std::vector<uint8_t> buf(bytesToSend, 0x55); // 0b01010101 pattern

    std::cout << "Running baud timing test: sending " << bytesToSend
              << " bytes at nominal " << baud << " baud...\n";

    // Write loop to ensure we push all bytes into the driver
    size_t totalWritten = 0;
    auto start = std::chrono::steady_clock::now();
    while (totalWritten < bytesToSend) {
        ssize_t n = ::write(fd, buf.data() + totalWritten,
                            bytesToSend - totalWritten);
        if (n < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK) {
                continue;
            }
            std::cerr << "write error during timing test: "
                      << std::strerror(errno) << "\n";
            return;
        }
        totalWritten += static_cast<size_t>(n);
    }

    // Wait for all data to actually leave the UART / driver
    if (tcdrain(fd) != 0) {
        std::cerr << "tcdrain error: " << std::strerror(errno) << "\n";
        return;
    }
    auto end = std::chrono::steady_clock::now();

    std::chrono::duration<double> elapsed = end - start;
    double seconds = elapsed.count();

    // 8N1 -> 1 start + 8 data + 1 stop = 10 bits per byte
    const double bitsPerByte = 10.0;
    double theoreticalSeconds =
        (bytesToSend * bitsPerByte) / static_cast<double>(baud);

    std::cout << std::fixed << std::setprecision(4);
    std::cout << "Measured time:   " << seconds << " s\n";
    std::cout << "Theoretical time:" << theoreticalSeconds << " s (ideal)\n";
    if (seconds > 0.0) {
        double effectiveBaud =
            (bytesToSend * bitsPerByte) / seconds;
        std::cout << "Effective baud: ~" << std::setprecision(0)
                  << effectiveBaud << " bps\n";
    }
    std::cout << "Note: on a PTY this mostly measures software buffering; on a\n"
              << "real serial port it should track baud quite closely.\n";
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
    std::cout << "2) Send HOST command  (70 F4 00 00 00 00 + checksum)\n";
    std::cout << "3) Set N'th HOST (two-part command)\n";
    std::cout << "4) Send custom 6-byte payload (checksum auto-calculated)\n";
    std::cout << "5) Read and dump incoming bytes (until idle timeout)\n";
    std::cout << "6) Change device/baud and reopen\n";
    std::cout << "7) Baud timing self-test\n";
    std::cout << "8) Quit\n";
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

    const int defaultIdleTimeoutMs = 100; // 0.1s

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
                if (sendPacket(fd, bytes6)) {
                    std::cout << "Waiting for RESET response (idle timeout "
                              << defaultIdleTimeoutMs << " ms)...\n";
                    auto resp = readUntilIdle(fd, defaultIdleTimeoutMs, 1024);
                    dumpBufferHexC(resp);

                    if (resp.size() == 2 && resp[0] == 'A' && resp[1] == 'C') {
                        std::cout << "RESET response OK: 'A' 'C'\n";
                    } else {
                        std::cout << "RESET response unexpected size/content. "
                                  << "Expected 2 bytes 'A','C'. Got "
                                  << resp.size() << " bytes.\n";
                    }
                }
                break;
            }
            case 2: {
                // HOST: device 0x70, command 0xF4, 4 x 0x00
                uint8_t bytes6[6] = {0x70, 0xF4, 0x00, 0x00, 0x00, 0x00};
                if (sendPacket(fd, bytes6)) {
                    std::cout << "Waiting for HOST response (idle timeout "
                              << defaultIdleTimeoutMs << " ms)...\n";
                    auto resp = readUntilIdle(fd, defaultIdleTimeoutMs, 4096);
                    dumpBufferHexC(resp);

                    if (resp.size() != 259) {
                        std::cout << "HOST response unexpected size: "
                                  << resp.size()
                                  << " (expected 259 bytes: A,256 payload,checksum,C or similar).\n";
                    } else {
                        if (resp[0] != 'A' || resp[258] != 'C') {
                            std::cout << "HOST Accept/Complete 'A','C' "
                                      << "(got "
                                      << (int)resp[0] << ", "
                                      << (int)resp[258] << ").\n";
                        } else {
                            std::cout << "HOST Ack/Complete bytes OK: 'A','C'\n";
                        }

                        const size_t payloadLen = 256;
                        const uint8_t *payload = &resp[1];
                        uint8_t receivedChecksum = resp[1 + payloadLen];

                        uint8_t computedChecksum =
                            computeChecksum(payload, payloadLen);

                        std::cout << "HOST payload checksum: "
                                  << "computed 0x"
                                  << std::hex << std::nouppercase
                                  << std::setw(2) << std::setfill('0')
                                  << (int)computedChecksum
                                  << ", received 0x"
                                  << std::setw(2) << (int)receivedChecksum
                                  << std::dec << "\n";

                        if (computedChecksum == receivedChecksum) {
                            std::cout << "HOST checksum OK.\n";
                        } else {
                            std::cout << "HOST checksum MISMATCH.\n";
                        }
                    }
                }
                break;
            }
            case 3: {
                // Set N'th HOST (two-part command)
                std::cout << "Enter host index (1-based): ";
                std::string idxStr;
                std::getline(std::cin, idxStr);
                if (idxStr.empty()) {
                    std::cerr << "Host index required.\n";
                    break;
                }
                int hostIndexInt = std::stoi(idxStr);
                if (hostIndexInt < 1 || hostIndexInt > 255) {
                    std::cerr << "Host index out of range (1-255).\n";
                    break;
                }
                // Convert to 0-based index
                uint8_t hostIndex = static_cast<uint8_t>(hostIndexInt - 1);

                std::cout << "Enter URL (max 32 chars; will be zero-padded): ";
                std::string url;
                std::getline(std::cin, url);

                // First part: command header 70 9F 00 00 00 00 + checksum
                uint8_t cmd6[6] = {0x70, 0x9F, 0x00, 0x00, 0x00, 0x00};
                if (!sendPacket(fd, cmd6)) {
                    break;
                }

                // Second part: payload: hostIndex + 32-byte URL + checksum
                uint8_t payload[33];
                payload[0] = hostIndex;
                // Zero-fill URL bytes
                for (int i = 0; i < 32; ++i) payload[i + 1] = 0x00;

                // Copy URL, truncated to 32 bytes
                size_t copyLen = std::min<size_t>(url.size(), 32);
                for (size_t i = 0; i < copyLen; ++i) {
                    payload[1 + i] = static_cast<uint8_t>(url[i]);
                }
                // At least one terminating 0x00 is guaranteed because we zero-filled

                uint8_t checksum = computeChecksum(payload, 33);
                uint8_t frame[34];
                for (int i = 0; i < 33; ++i) frame[i] = payload[i];
                frame[33] = checksum;

                if (!sendRaw(fd, frame, sizeof(frame))) {
                    break;
                }

                std::cout << "Waiting for DATA (idle timeout "
                          << defaultIdleTimeoutMs << " ms)...\n";
                {
                    auto resp = readUntilIdle(fd, defaultIdleTimeoutMs, 64);
                    dumpBufferHexC(resp);
                }

                break;
            }
            case 4: {
                std::cout << "Enter 6 hex bytes (e.g. '70 FF 01 02 03 04'): ";
                std::string line;
                std::getline(std::cin, line);
                uint8_t bytes6[6];
                if (!parseSixHexBytes(line, bytes6)) {
                    std::cerr << "Failed to parse 6 hex bytes.\n";
                } else {
                    if (sendPacket(fd, bytes6)) {
                        std::cout << "Wait for response? (y/N): ";
                        std::string ans;
                        std::getline(std::cin, ans);
                        if (!ans.empty() && (ans[0] == 'y' || ans[0] == 'Y')) {
                            auto resp = readUntilIdle(fd, defaultIdleTimeoutMs, 4096);
                            dumpBufferHexC(resp);
                        }
                    }
                }
                break;
            }
            case 5: {
                std::cout << "Enter idle timeout in ms (default "
                          << defaultIdleTimeoutMs << "): ";
                std::string tline;
                std::getline(std::cin, tline);
                int timeout = defaultIdleTimeoutMs;
                if (!tline.empty()) {
                    timeout = std::stoi(tline);
                }
                std::cout << "Enter max bytes to read (default 1024): ";
                std::string mline;
                std::getline(std::cin, mline);
                size_t maxBytes = 1024;
                if (!mline.empty()) {
                    maxBytes = static_cast<size_t>(std::stoul(mline));
                }

                auto resp = readUntilIdle(fd, timeout, maxBytes);
                dumpBufferHexC(resp);
                break;
            }
            case 6: {
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
            case 7: {
                baudTimingTest(fd, baudRate);
                break;
            }
            case 8: {
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

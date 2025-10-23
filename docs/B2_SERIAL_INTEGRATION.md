# B2 Emulator Serial Integration Guide

## Overview
This document explains how to integrate FujiNet serial communication into the b2 BBC Micro emulator using the existing SERPROC infrastructure.

## Current B2 Serial Architecture

### SERPROC Component
Located in `/home/markf/dev/bbc/b2/src/beeb/`:
- **serproc.h** - Serial Processor interface
- **serproc.cpp** - Implementation
- **serproc.inl** - Enums for baud rates

### How SERPROC Works

1. **Data Flow**:
   - **Transmit (TX)**: ACIA → SERPROC → Device (Sink)
   - **Receive (RX)**: Device (Source) → SERPROC → ACIA

2. **Key Components**:
   ```cpp
   class SerialDataSource {
       virtual uint8_t GetNextByte() = 0;  // Called by SERPROC for RX
   };
   
   class SerialDataSink {
       virtual void AddByte(uint8_t value) = 0;  // Called by SERPROC for TX
   };
   
   class SERPROC {
       std::shared_ptr<SerialDataSource> m_source;  // RX from device
       std::shared_ptr<SerialDataSink> m_sink;      // TX to device
       // ...
   };
   ```

3. **Supported Baud Rates**:
   ```cpp
   const unsigned SERPROC_BAUD_RATES[8] = {
       19200,  // 000
       1200,   // 001
       4800,   // 010
       150,    // 011
       9600,   // 100
       300,    // 101
       2400,   // 110
       75,     // 111
   };
   ```

4. **Memory Mapping**:
   - SERPROC registers at `$FE10-$FE17` (BBC Micro I/O space)
   - Configured in `BBCMicro.cpp:2926-2930`

## What Needs to be Implemented

### 1. Create PTY Source/Sink Classes

Create a new file: `/home/markf/dev/bbc/b2/src/beeb/src/PTYSerial.cpp`

```cpp
#include <beeb/serproc.h>
#include <fcntl.h>
#include <unistd.h>
#include <shared/mutex.h>
#include <vector>

class PTYSerialDataSource : public SerialDataSource {
public:
    PTYSerialDataSource(int fd) : m_fd(fd) {}
    
    uint8_t GetNextByte() override {
        uint8_t byte = 0;
        
        // Try non-blocking read
        ssize_t result = ::read(m_fd, &byte, 1);
        
        if (result == 1) {
            return byte;
        }
        
        // Return 0 if no data (or implement buffering)
        return 0;
    }
    
private:
    int m_fd;
};

class PTYSerialDataSink : public SerialDataSink {
public:
    PTYSerialDataSink(int fd) : m_fd(fd) {}
    
    void AddByte(uint8_t value) override {
        // Write byte to PTY
        ::write(m_fd, &value, 1);
    }
    
private:
    int m_fd;
};
```

### 2. Add Configuration Support

In `BeebConfig.h`, add:
```cpp
struct BeebConfig {
    // ... existing fields ...
    std::string serial_pty_path;  // e.g., "/tmp/fn-tty"
};
```

### 3. Wire Up in BBCMicro

Currently, the SERPROC m_source and m_sink are private. You need to either:

**Option A**: Add public methods to SERPROC (in `serproc.h`):
```cpp
class SERPROC {
public:
    // ... existing public methods ...
    
    void SetSource(std::shared_ptr<SerialDataSource> source) {
        m_source = source;
    }
    
    void SetSink(std::shared_ptr<SerialDataSink> sink) {
        m_sink = sink;
    }
    
    // ... rest of class ...
};
```

**Option B**: Add methods to BBCMicro (in `BBCMicro.h`):
```cpp
class BBCMicro {
public:
    // ... existing methods ...
    
    void SetSerialSource(std::shared_ptr<SerialDataSource> source);
    void SetSerialSink(std::shared_ptr<SerialDataSink> sink);
};
```

Then implement in `BBCMicro.cpp`:
```cpp
void BBCMicro::SetSerialSource(std::shared_ptr<SerialDataSource> source) {
    if (m_state.HasSerial()) {
        m_state.serproc.SetSource(source);  // Option A needed
    }
}

void BBCMicro::SetSerialSink(std::shared_ptr<SerialDataSink> sink) {
    if (m_state.HasSerial()) {
        m_state.serproc.SetSink(sink);  // Option A needed
    }
}
```

### 4. Initialize in BeebThread

In `BeebThread.cpp`, when creating/configuring a BBC Micro instance:

```cpp
void BeebThread::InitializeSerial(const std::string &pty_path) {
    if (pty_path.empty()) {
        return;  // No serial configured
    }
    
    // Open PTY in non-blocking mode
    int fd = open(pty_path.c_str(), O_RDWR | O_NONBLOCK);
    if (fd < 0) {
        // Log error
        return;
    }
    
    // Create source/sink
    auto source = std::make_shared<PTYSerialDataSource>(fd);
    auto sink = std::make_shared<PTYSerialDataSink>(fd);
    
    // Attach to BBCMicro
    m_beeb->SetSerialSource(source);
    m_beeb->SetSerialSink(sink);
}
```

### 5. Add UI Configuration

In `SettingsUI.cpp`, add a text field for the PTY path:
```cpp
ImGui::InputText("Serial PTY Path", &config.serial_pty_path);
if (ImGui::IsItemHovered()) {
    ImGui::SetTooltip("Path to PTY for serial communication (e.g., /tmp/fn-tty)");
}
```

## Testing Strategy

### 1. Start the Bridge
```bash
cd /home/markf/dev/bbc/fn-rom/serial-bridge
./bridge -d /dev/ttyS0 -b 115200 -p /tmp/fn-tty
```

### 2. Configure B2
- Set "Serial PTY Path" to `/tmp/fn-tty`
- Ensure BBC Model B or Master with serial support is selected

### 3. Test from BBC BASIC
```basic
*FX 2,2       REM Redirect output to RS423
PRINT "Hello FujiNet!"
*FX 2,0       REM Restore normal output
```

### 4. Test with Python Script
```bash
cd /home/markf/dev/bbc/fn-rom/serial-bridge
./send-packet.py -c reset -d 70 -o /tmp/inject-tty -r
```

## Implementation Checklist

- [ ] Add `SetSource()` and `SetSink()` methods to SERPROC class
- [ ] Create `PTYSerial.cpp` with PTYSerialDataSource and PTYSerialDataSink classes
- [ ] Add `serial_pty_path` field to BeebConfig
- [ ] Implement `SetSerialSource()` and `SetSerialSink()` in BBCMicro
- [ ] Add serial initialization in BeebThread
- [ ] Add UI configuration for serial PTY path
- [ ] Handle PTY file descriptor lifecycle (open/close)
- [ ] Add error handling for PTY connection failures
- [ ] Implement proper thread-safe buffering for serial data
- [ ] Test with FujiNet commands

## Notes

1. **Thread Safety**: The SerialDataSource and SerialDataSink may be called from the emulation thread. Ensure thread-safe access to the PTY file descriptor.

2. **Buffering**: The current simple implementation reads/writes one byte at a time. For better performance, consider buffering:
   - Source: Buffer incoming data from PTY, serve from buffer
   - Sink: Buffer outgoing bytes, flush periodically

3. **Non-blocking I/O**: The PTY should be opened in non-blocking mode (`O_NONBLOCK`) to prevent the emulation thread from stalling.

4. **ACIA Timing**: SERPROC handles the timing automatically based on the configured baud rate. The emulation will call GetNextByte() and AddByte() at the appropriate intervals.

5. **Testing Without Hardware**: Use the `socat` approach from `create-link.sh` to create two linked PTYs for testing without real serial hardware.

## References

- b2 SERPROC: `/home/markf/dev/bbc/b2/src/beeb/src/serproc.cpp`
- b2 BBC Micro: `/home/markf/dev/bbc/b2/src/beeb/src/BBCMicro.cpp`
- Bridge tool: `/home/markf/dev/bbc/fn-rom/serial-bridge/bridge.cpp`
- Test script: `/home/markf/dev/bbc/fn-rom/serial-bridge/send-packet.py`


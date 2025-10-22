# Makefile for serial-bridge applications

CXX = g++
CXXFLAGS = -std=c++17 -O2 -Wall

# Default target: build both programs
all: bridge client

# Build bridge program
bridge: bridge.cpp
	$(CXX) $(CXXFLAGS) bridge.cpp -o bridge

# Build client program
client: client.cpp
	$(CXX) $(CXXFLAGS) client.cpp -o client

# Clean build artifacts
clean:
	rm -f bridge client

# Phony targets
.PHONY: all clean


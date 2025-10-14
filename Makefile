# Build script for fn-rom based on cc65
#

PROGRAM = fujinet
CURRENT_TARGET = bbc

# Interface selection - can be overridden on command line
# Options: SERIAL (default), USERPORT, 1MHZ, DUMMY
BUILD_INTERFACE ?= DUMMY

# Ensure WSL2 Ubuntu and other linuxes use bash by default instead of /bin/sh, which does not always like the shell commands.
SHELL := /usr/bin/env bash
DISK_TASKS =

CC := cl65
LDFLAGS := -C cfg/fujinet-rom.cfg

ASFLAGS := --asm-define FN_DEBUG=1 --asm-define FN_DEBUG_CREATE_FILE=1 --asm-define FN_DEBUG_WRITE_DATA=1 --asm-define FN_DEBUG_CLOSE_FILE=1 --asm-define FN_DEBUG_OPEN_FILE=1 --asm-define FN_DEBUG_READ_DATA=1

# Define the appropriate interface based on BUILD_INTERFACE
ifeq ($(BUILD_INTERFACE),SERIAL)
ASFLAGS += --asm-define FUJINET_INTERFACE_SERIAL
else ifeq ($(BUILD_INTERFACE),USERPORT)
ASFLAGS += --asm-define FUJINET_INTERFACE_USERPORT
else ifeq ($(BUILD_INTERFACE),1MHZ)
ASFLAGS += --asm-define FUJINET_INTERFACE_1MHZ
else ifeq ($(BUILD_INTERFACE),DUMMY)
ASFLAGS += --asm-define FUJINET_INTERFACE_DUMMY
else
$(error Invalid BUILD_INTERFACE: $(BUILD_INTERFACE). Must be SERIAL, USERPORT, 1MHZ, or DUMMY)
endif

SRCDIR := src
BUILD_DIR := build
OBJDIR := obj
DIST_DIR := dist
CACHE_DIR := ./_cache

# This allows src to be nested withing sub-directories.
rwildcard=$(wildcard $(1)$(2))$(foreach d,$(wildcard $1*), $(call rwildcard,$d/,$2))

PROGRAM_TGT := $(PROGRAM).rom

# SOURCES := $(wildcard $(SRCDIR)/*.c)
# SOURCES += $(wildcard $(SRCDIR)/*.s)

SOURCES := $(call rwildcard,$(SRCDIR)/,*.s)
SOURCES += $(call rwildcard,$(SRCDIR)/,*.c)

# remove trailing and leading spaces.
SOURCES := $(strip $(SOURCES))

# convert from src/your/long/path/foo.[c|s] to obj/<target>/your/long/path/foo.o
# we need the target because compiling for previous target does not pick up potential macro changes
OBJ1 := $(SOURCES:.c=.o)
OBJECTS := $(OBJ1:.s=.o)
OBJECTS := $(OBJECTS:$(SRCDIR)/%=$(OBJDIR)/$(CURRENT_TARGET)/%)

# Ensure make recompiles parts it needs to if src files change
DEPENDS := $(OBJECTS:.o=.d)

ASFLAGS += --asm-include-dir $(SRCDIR) --asm-include-dir $(SRCDIR)/inc
CFLAGS += --include-dir $(SRCDIR) --include-dir $(SRCDIR)/inc

.SUFFIXES:
.PHONY: all clean release $(DISK_TASKS) $(BUILD_TASKS) $(PROGRAM_TGT)

all: $(PROGRAM_TGT)

$(OBJDIR):
	@mkdir -p $(OBJDIR)

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(DIST_DIR):
	@mkdir -p $(DIST_DIR)

SRC_INC_DIRS := \
  $(sort $(dir $(wildcard $(SRCDIR)/*)))

vpath %.c $(SRC_INC_DIRS)

$(OBJDIR)/$(CURRENT_TARGET)/%.o: %.c $(VERSION_FILE) | $(OBJDIR)
	@mkdir -p $(dir $@)
	$(CC) -t $(CURRENT_TARGET) -c $(CFLAGS) --create-dep $(@:.o=.d) --listing $(@:.o=.lst) -Ln $@.lbl -o $@ $<

vpath %.s $(SRC_INC_DIRS)

$(OBJDIR)/$(CURRENT_TARGET)/%.o: %.s $(VERSION_FILE) | $(OBJDIR)
	@mkdir -p $(dir $@)
	$(CC) -t $(CURRENT_TARGET) -c $(ASFLAGS) --create-dep $(@:.o=.d) --listing $(@:.o=.lst) -Ln $@.lbl -o $@ $<


$(BUILD_DIR)/$(PROGRAM_TGT): $(OBJECTS) $(LIBS) | $(BUILD_DIR)
	$(CC) -t $(CURRENT_TARGET) $(LDFLAGS) --mapfile $@.map -Ln $@.lbl -o $@ $^

$(PROGRAM_TGT): $(BUILD_DIR)/$(PROGRAM_TGT) | $(BUILD_DIR)

# Use "./" in front of all dirs being removed as a simple safety guard to
# ensure deleting from current dir, and not something like root "/".
clean:
	@for d in $(BUILD_DIR) $(OBJDIR) $(DIST_DIR); do \
      if [ -d "./$$d" ]; then \
	    echo "Removing $$d"; \
        rm -rf ./$$d; \
      fi; \
    done

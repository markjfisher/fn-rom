# Build script for fn-rom based on cc65
#

PROGRAM = fujinet
CURRENT_TARGET = none
BUILD_MACHINE ?= BBC

# Network device feature (role-split Lever A; see docs/ROM_ROLE_SPLIT_PLAN.md).
# FEATURE_NET=1 (default) is the DISK+NET build: OPENIN "scheme://", *FJSON and
# the OSWORD &78 network API. FEATURE_NET=0 is the DISK build: src/net/ is not
# linked and the network branch in the filing vectors is gated out.
FEATURE_NET ?= 1

# Transient utilities (role-split Lever B). UTILITIES=resident links the
# management/informational commands (src/utils/) into the ROM; UTILITIES=disk
# drops them (they ship on FN-UTLS.ssd and load on demand via the *RUN
# fallthrough). Default is 'resident' so the bare `make all` is the ALL build;
# the lean shipped builds use the disk/net targets below.
UTILITIES ?= resident

# obj/ is keyed by variant so net-on/off and utils resident/disk never collide.
BUILD_VARIANT = $(CURRENT_TARGET)-$(BUILD_MACHINE)$(if $(filter 0,$(FEATURE_NET)),-nonet)$(if $(filter disk,$(UTILITIES)),-utld)
SUPPORTED_BUILD_MACHINES := BBC MASTER

# Interface selection - can be overridden on command line
# Options: SERIAL (default), USERPORT, 1MHZ
BUILD_INTERFACE ?= SERIAL

# Ensure WSL2 Ubuntu and other linuxes use bash by default instead of /bin/sh, which does not always like the shell commands.
SHELL := /usr/bin/env bash
DISK_TASKS =

CC := cl65
LDFLAGS := -C cfg/fujinet-rom.cfg

CFLAGS += -Osir

#ASFLAGS := --asm-define FN_DEBUG=1 --asm-define FN_DEBUG_CREATE_FILE=1 --asm-define FN_DEBUG_WRITE_DATA=1 --asm-define FN_DEBUG_CLOSE_FILE=1 --asm-define FN_DEBUG_OPEN_FILE=1 --asm-define FN_DEBUG_READ_DATA=1
#ASFLAGS := --asm-define FN_DEBUG=1

# Define the appropriate interface based on BUILD_INTERFACE
ifeq ($(BUILD_INTERFACE),SERIAL)
ASFLAGS += --asm-define FUJINET_INTERFACE_SERIAL
CFLAGS += -DFUJINET_INTERFACE_SERIAL
else ifeq ($(BUILD_INTERFACE),USERPORT)
ASFLAGS += --asm-define FUJINET_INTERFACE_USERPORT
CFLAGS += -DFUJINET_INTERFACE_USERPORT
else ifeq ($(BUILD_INTERFACE),1MHZ)
ASFLAGS += --asm-define FUJINET_INTERFACE_1MHZ
CFLAGS += -DFUJINET_INTERFACE_1MHZ
else
$(error Invalid BUILD_INTERFACE: $(BUILD_INTERFACE). Must be SERIAL, USERPORT, 1MHZ)
endif

# Define the target machine profile.
# BBC is the existing baseline. MASTER starts enabling alternate workspace/layout.
ifeq ($(BUILD_MACHINE),BBC)

ASFLAGS += \
	--asm-define FUJINET_MACHINE_BBC

# we don't have any C at the moment... doubt we ever will again
CFLAGS += \
	-DFUJINET_MACHINE_BBC

PROGRAM_MACHINE_SUFFIX :=

else ifeq ($(BUILD_MACHINE),MASTER)

ASFLAGS += \
	--asm-define FUJINET_MACHINE_MASTER \
	--cpu 65C02

LDFLAGS += --cpu 65C02
CFLAGS += \
	-DFUJINET_MACHINE_MASTER \
	--cpu 65C02

PROGRAM_MACHINE_SUFFIX := -master

else
$(error Invalid BUILD_MACHINE: $(BUILD_MACHINE). Must be BBC or MASTER)
endif

SRCDIR := src
BUILD_DIR := build
OBJDIR := obj
DIST_DIR := dist
CACHE_DIR := ./_cache

# This allows src to be nested withing sub-directories.
rwildcard=$(wildcard $(1)$(2))$(foreach d,$(wildcard $1*), $(call rwildcard,$d/,$2))

PROGRAM_TGT := $(PROGRAM)$(PROGRAM_MACHINE_SUFFIX).rom

SSD_ROM_BBC := FN-BBC
SSD_ROM_MASTER := FN-MAST

# SOURCES := $(wildcard $(SRCDIR)/*.c)
# SOURCES += $(wildcard $(SRCDIR)/*.s)

SOURCES := $(call rwildcard,$(SRCDIR)/,*.s)
SOURCES += $(call rwildcard,$(SRCDIR)/,*.c)

# remove trailing and leading spaces.
SOURCES := $(strip $(SOURCES))

# Lever A: compile + link src/net/ only when the network feature is on. When off,
# drop the network modules entirely (cc65 omits unlinked object modules wholesale)
# and define nothing, so the gated network branch in the vectors is not assembled.
ifeq ($(FEATURE_NET),1)
ASFLAGS += --asm-define FEATURE_NET
CFLAGS += -DFEATURE_NET
else
SOURCES := $(filter-out $(call rwildcard,$(SRCDIR)/net/,*.s),$(SOURCES))
endif

# Lever B: link src/utils/ only when UTILITIES=resident. When on disk, drop the
# modules (their command-table fragments self-register from src/utils/, so they
# vanish from the table too) and they are instead built as FN-UTLS.ssd binaries.
ifeq ($(UTILITIES),resident)
ASFLAGS += --asm-define UTILITIES_RESIDENT
CFLAGS += -DUTILITIES_RESIDENT
else ifeq ($(UTILITIES),disk)
SOURCES := $(filter-out $(call rwildcard,$(SRCDIR)/utils/,*.s),$(SOURCES))
else
$(error Invalid UTILITIES: $(UTILITIES). Must be resident or disk)
endif

# convert from src/your/long/path/foo.[c|s] to obj/<variant>/your/long/path/foo.o
# we need the variant because target/machine macro changes must not reuse stale objects
OBJ1 := $(SOURCES:.c=.o)
OBJECTS := $(OBJ1:.s=.o)
OBJECTS := $(OBJECTS:$(SRCDIR)/%=$(OBJDIR)/$(BUILD_VARIANT)/%)

# Ensure make recompiles parts it needs to if src files change
DEPENDS := $(OBJECTS:.o=.d)

ASFLAGS += --asm-include-dir $(SRCDIR) --asm-include-dir $(SRCDIR)/inc
CFLAGS += --include-dir $(SRCDIR) --include-dir $(SRCDIR)/inc

.SUFFIXES:
.PHONY: all clean release $(DISK_TASKS) $(BUILD_TASKS) $(PROGRAM_TGT) all-machines ssd clean-imports sizes disk net all-rom

all: $(PROGRAM_TGT)

all-machines:
	@for machine in $(SUPPORTED_BUILD_MACHINES); do \
	  $(MAKE) BUILD_MACHINE=$$machine all || exit $$?; \
	done

# Role-split shipped builds. disk/net ship the utilities on FN-UTLS.ssd;
# all-rom (== bare `make all`) keeps everything resident.
disk:                       ## DISK profile: no network device, utils on disk
	$(MAKE) FEATURE_NET=0 UTILITIES=disk all
net:                        ## DISK+NET profile: network device, utils on disk
	$(MAKE) FEATURE_NET=1 UTILITIES=disk all
all-rom:                    ## ALL profile: network + utilities resident
	$(MAKE) FEATURE_NET=1 UTILITIES=resident all

# Report ROM size usage (segment usage, free bytes, per-feature subtotals) from
# the .map files in build/. Build first (e.g. `make all-machines`).
sizes:
	@maps="$(wildcard $(BUILD_DIR)/*.rom.map)"; \
	if [ -z "$$maps" ]; then \
	  echo "No .map files in $(BUILD_DIR) — run 'make all-machines' first."; \
	else \
	  python3 scripts/rom_sizes.py $$maps; \
	fi

$(OBJDIR):
	@mkdir -p $(OBJDIR)

$(OBJDIR)/$(BUILD_VARIANT): | $(OBJDIR)
	@mkdir -p $(OBJDIR)/$(BUILD_VARIANT)

$(BUILD_DIR):
	@mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/ssd:
	@mkdir -p $(BUILD_DIR)/ssd

$(DIST_DIR):
	@mkdir -p $(DIST_DIR)

SRC_INC_DIRS := \
  $(sort $(dir $(wildcard $(SRCDIR)/*)))

vpath %.c $(SRC_INC_DIRS)

$(OBJDIR)/$(BUILD_VARIANT)/%.o: %.c | $(OBJDIR)/$(BUILD_VARIANT)
	@mkdir -p $(dir $@)
	$(CC) -t $(CURRENT_TARGET) -c $(CFLAGS) --create-dep $(@:.o=.d) --listing $(@:.o=.lst) -Ln $@.lbl -o $@ $<

vpath %.s $(SRC_INC_DIRS)

$(OBJDIR)/$(BUILD_VARIANT)/%.o: %.s | $(OBJDIR)/$(BUILD_VARIANT)
	@mkdir -p $(dir $@)
	$(CC) -t $(CURRENT_TARGET) -c $(ASFLAGS) --create-dep $(@:.o=.d) --listing $(@:.o=.lst) -Ln $@.lbl -o $@ $<


$(BUILD_DIR)/$(PROGRAM_TGT): $(OBJECTS) $(LIBS) | $(BUILD_DIR)
	$(CC) -t $(CURRENT_TARGET) $(LDFLAGS) --mapfile $@.map -Ln $@.lbl -o $@ $^
$(PROGRAM_TGT): $(BUILD_DIR)/$(PROGRAM_TGT) | $(BUILD_DIR)

ssd: all-machines | $(BUILD_DIR) $(BUILD_DIR)/ssd
	rm -f $(BUILD_DIR)/ssd/*
	cp $(BUILD_DIR)/$(PROGRAM).rom $(BUILD_DIR)/ssd/$(SSD_ROM_BBC)
	cp $(BUILD_DIR)/$(PROGRAM)-master.rom $(BUILD_DIR)/ssd/$(SSD_ROM_MASTER)
	./scripts/create_ssd.py -i $(BUILD_DIR)/ssd -o $(BUILD_DIR)/fujinet.ssd -a 0x8000

# Strip and rebuild .import / .importzp for each src/**/*.s using the same cl65
# flags as a normal object build (via `make -n -B`) and import_layout rules.
# Optional: make clean-imports CLEAN_IMPORTS_ARGS='--dry-run src/commands/cmd_cat.s'
clean-imports:
	@mkdir -p build
	@CURRENT_TARGET=$(CURRENT_TARGET) BUILD_INTERFACE=$(BUILD_INTERFACE) python3 scripts/clean_imports.py $(CLEAN_IMPORTS_ARGS)


# Use "./" in front of all dirs being removed as a simple safety guard to
# ensure deleting from current dir, and not something like root "/".
clean:
	@for d in $(BUILD_DIR) $(OBJDIR) $(DIST_DIR); do \
      if [ -d "./$$d" ]; then \
	    echo "Removing $$d"; \
        rm -rf ./$$d; \
      fi; \
    done

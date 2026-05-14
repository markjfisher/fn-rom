# simple makefile to create bbc application from C and S source in single folder "src".
#
# requires CC65_SRC env var pointing to fork of CC65 with BBC support.

PROGRAM 		= ct1

ifeq ($(CC65_SRC),)
$(error Unknown CC65_SRC env: Point to folder containing fork of cc65 for BBC)
endif

SHELL          := /usr/bin/env bash
SRCDIR         := src
BUILD_DIR      := build
OBJDIR         := obj
CURRENT_TARGET := bbc


SOURCES        :=
SOURCES        += $(wildcard $(SRCDIR)/*.c)
SOURCES        += $(wildcard $(SRCDIR)/*.s)

SOURCES        := $(strip $(SOURCES))

# Object files: mirror src/* path under obj/
OBJ_TMP        := $(SOURCES:.c=.o)
OBJECTS        := $(OBJ_TMP:.s=.o)
OBJECTS        := $(OBJECTS:$(SRCDIR)/%=$(OBJDIR)/$(PROGRAM)/%)

DEPENDS        := $(OBJECTS:.o=.d)

# --------------------------------------------------------------------
# Compiler configuration
# --------------------------------------------------------------------
CC             := cl65

CFLAGS         :=
CFLAGS         += -I$(SRCDIR)

ASFLAGS        :=
ASFLAGS        += --asm-include-dir $(SRCDIR)
ASFLAGS        += --asm-include-dir $(CC65_SRC)/libsrc/bbc
ASFLAGS        += --asm-include-dir $(CC65_SRC)/asminc

LDFLAGS        := -C ../cfg/bbc.cfg

# Dependency files  
-include $(DEPENDS)

.SUFFIXES:
.PHONY: all clean

all: $(BUILD_DIR)/$(PROGRAM)

# Compile .c -> .o
$(OBJDIR)/$(PROGRAM)/%.o: $(SRCDIR)/%.c | $(OBJDIR)
	@mkdir -p $(dir $@)
	$(CC) -t bbc -c --create-dep $(@:.o=.d) --listing $(@:.o=.lst) $(CFLAGS) -o $@ $<

# Assemble .s -> .o
$(OBJDIR)/$(PROGRAM)/%.o: $(SRCDIR)/%.s | $(OBJDIR)
	@mkdir -p $(dir $@)
	$(CC) -t bbc -c --create-dep $(@:.o=.d) $(ASFLAGS) --listing $(@:.o=.lst) -o $@ $<

# Link
$(BUILD_DIR)/$(PROGRAM): $(OBJECTS)  | $(BUILD_DIR)
	$(CC) -t $(CURRENT_TARGET) $(LDFLAGS) --mapfile $@.map -Ln $@.lbl -o $@ $(OBJECTS) $(LIBS)

$(OBJDIR):
	@mkdir -p $@

$(BUILD_DIR):
	@mkdir -p $@

clean:
	rm -rf $(BUILD_DIR)/$(PROGRAM)
	rm -rf $(OBJDIR)/$(PROGRAM)

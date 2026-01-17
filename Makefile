ifeq (,$(filter help completion,$(MAKECMDGOALS)))
  # Dynamic compiler detection
  XCODE_PATH := $(shell xcode-select -p)
  XCODE_TOOLCHAIN := $(XCODE_PATH)/Toolchains/XcodeDefault.xctoolchain
  CC := $(shell xcrun -find clang)
  CXX := $(shell xcrun -find clang++)

  # SDK paths
  SDKROOT ?= $(shell xcrun --show-sdk-path)
  ISYSROOT := $(shell xcrun -sdk macosx --show-sdk-path)
  INCLUDE_PATH := $(shell xcrun -sdk macosx --show-sdk-platform-path)/Developer/SDKs/MacOSX.sdk/usr/include
else
  # Fallbacks for non-build goals to avoid SDK discovery
  CC := clang
  CXX := clang++
  SDKROOT :=
  ISYSROOT :=
  INCLUDE_PATH :=
endif

# Compiler and flags
CFLAGS = -Wall -Wextra -O2 \
    -fobjc-arc \
    -isysroot $(SDKROOT) \
    -iframework $(SDKROOT)/System/Library/Frameworks \
    -F/System/Library/PrivateFrameworks \
    -IZKSwizzle
ARCHS = -arch x86_64 -arch arm64 -arch arm64e
FRAMEWORK_PATH = $(SDKROOT)/System/Library/Frameworks
PRIVATE_FRAMEWORK_PATH = $(SDKROOT)/System/Library/PrivateFrameworks
PUBLIC_FRAMEWORKS = -framework Foundation -framework AppKit -framework QuartzCore -framework Cocoa \
    -framework CoreFoundation

# Project name and paths
PROJECT = zoomer
DYLIB_NAME = lib$(PROJECT).dylib
BUILD_DIR = build
SOURCE_DIR = src
INSTALL_DIR = /var/ammonia/core/tweaks

# Source files
DYLIB_SOURCES = $(SOURCE_DIR)/zoomer/zoomer.m \
                ZKSwizzle/ZKSwizzle.m
DYLIB_OBJECTS = $(DYLIB_SOURCES:%.m=$(BUILD_DIR)/%.o)

# Installation targets
INSTALL_PATH = $(INSTALL_DIR)/$(DYLIB_NAME)
BLACKLIST_SOURCE = lib$(PROJECT).dylib.blacklist
BLACKLIST_DEST = $(INSTALL_DIR)/lib$(PROJECT).dylib.blacklist

# Dylib settings
DYLIB_FLAGS = -dynamiclib \
              -install_name @rpath/$(DYLIB_NAME) \
              -compatibility_version 1.0.0 \
              -current_version 1.0.0

# Default target
all: clean $(BUILD_DIR)/$(DYLIB_NAME) ## Build dylib

# Create build directory and subdirectories
$(BUILD_DIR):
	@rm -rf $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(BUILD_DIR)/ZKSwizzle
	@mkdir -p $(BUILD_DIR)/src/zoomer

# Compile source files
$(BUILD_DIR)/%.o: %.m | $(BUILD_DIR)
	@mkdir -p $(dir $@)
	$(CC) $(CFLAGS) $(ARCHS) -c $< -o $@

# Link dylib
$(BUILD_DIR)/$(DYLIB_NAME): $(DYLIB_OBJECTS)
	$(CC) $(DYLIB_FLAGS) $(ARCHS) $(DYLIB_OBJECTS) -o $@ \
	-F$(FRAMEWORK_PATH) \
	-F$(PRIVATE_FRAMEWORK_PATH) \
	$(PUBLIC_FRAMEWORKS) \
	-L$(SDKROOT)/usr/lib

# Install dylib
install: $(BUILD_DIR)/$(DYLIB_NAME) ## Install dylib to system
	@echo "Installing dylib to $(INSTALL_DIR)"
	# Create the target directories.
	sudo mkdir -p $(INSTALL_DIR)
	# Install the tweak's dylib where injection takes place.
	sudo install -m 755 $(BUILD_DIR)/$(DYLIB_NAME) $(INSTALL_DIR)
	@if [ -f $(BLACKLIST_SOURCE) ]; then \
		sudo cp $(BLACKLIST_SOURCE) $(BLACKLIST_DEST); \
		sudo chmod 644 $(BLACKLIST_DEST); \
		echo "Installed $(DYLIB_NAME) and blacklist"; \
	else \
		echo "Warning: $(BLACKLIST_SOURCE) not found"; \
		echo "Installed $(DYLIB_NAME)"; \
	fi

# Test target that builds, installs, and relaunches test applications
test: install ## Build, install, and restart test applications
	@echo "Force quitting test applications..."
	$(eval TEST_APPS := Spotify "System Settings" Chess soffice "Brave Browser" Beeper Safari Finder qBittorrent zoom.us)
	@for app in $(TEST_APPS); do \
		pkill -9 "$$app" 2>/dev/null || true; \
	done
	@echo "Relaunching test applications..."
	@for app in $(TEST_APPS); do \
		if [ "$$app" != "soffice" ] && [ "$$app" != "zoom.us" ]; then \
			open -a "$$app" 2>/dev/null || true; \
		elif [ "$$app" = "zoom.us" ]; then \
			open -a "zoom.us" 2>/dev/null || true; \
		fi; \
	done
	@echo "Test applications restarted with new dylib loaded"

# Clean build files
clean: ## Remove build directory and artifacts
	@rm -rf $(BUILD_DIR)
	@echo "Cleaned build directory"

# Delete installed files
delete: ## Delete installed files and relaunch Finder
	@echo "Force quitting test applications..."
	$(eval TEST_APPS := Spotify "System Settings" Chess soffice "Brave Browser" Beeper Safari Finder qBittorrent zoom.us)
	@for app in $(TEST_APPS); do \
		pkill -9 "$$app" 2>/dev/null || true; \
	done
	@sleep 2 && open -a "Finder" || true
	@sudo rm -f $(INSTALL_PATH)
	@sudo rm -f $(BLACKLIST_DEST)
	@echo "Deleted $(DYLIB_NAME) and blacklist from $(INSTALL_DIR)"

# Uninstall
uninstall: ## Uninstall dylib and blacklist
	@sudo rm -f $(INSTALL_PATH)
	@sudo rm -f $(BLACKLIST_DEST)
	@echo "Uninstalled $(DYLIB_NAME) and blacklist"

installer: ## Create a .pkg installer
	@echo "Packaging Zoomer into a .pkg installer"
	./scripts/create_installer.sh

help: ## Show this help
	@echo "Available make targets:"
	@grep -E '^[a-zA-Z0-9_.-]+:.*##' $(MAKEFILE_LIST) | sed 's/^\([^:]*\):.*##\s*\(.*\)/  \1|\2/' | awk -F'|' '{printf "  %-20s %s\n", $$1, $$2}'

.PHONY: all clean install test delete uninstall installer help

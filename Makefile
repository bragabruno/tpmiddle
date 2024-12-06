# Compiler settings
CXX = clang++
CXXFLAGS = -std=c++17 -Wall -Wextra -g
OBJCXXFLAGS = $(CXXFLAGS) -framework Foundation -framework IOKit -framework AppKit -framework Cocoa -fobjc-arc

# Directories
SRC_DIR = src
BUILD_DIR = build
TEST_DIR = tests
BIN_DIR = bin
APP_DIR = tpmiddle.app

# Source files (explicitly list macOS files)
SOURCES = src/TPApplication.mm \
         src/TPButtonManager.mm \
         src/TPConfig.mm \
         src/TPEventViewController.mm \
         src/TPHIDManager.mm \
         src/TPHIDManagerConstants.mm \
         src/TPLogger.mm \
         src/TPMiddleMacOS.mm \
         src/TPStatusBarController.mm \
         src/main.mm

# Object files
OBJECTS = $(SOURCES:$(SRC_DIR)/%.mm=$(BUILD_DIR)/%.o)

# Test files
TEST_SOURCES = $(wildcard $(TEST_DIR)/unit/**/*.mm)
TEST_OBJECTS = $(TEST_SOURCES:$(TEST_DIR)/%.mm=$(BUILD_DIR)/%.o)

# Binary names
TARGET = tpmiddle
TEST_TARGET = test_runner

# Default target
all: app

# Create necessary directories
$(BUILD_DIR) $(BIN_DIR):
	mkdir -p $@
	mkdir -p $(BUILD_DIR)/unit/infrastructure

# Compile .mm files
$(BUILD_DIR)/%.o: $(SRC_DIR)/%.mm
	@mkdir -p $(dir $@)
	$(CXX) $(OBJCXXFLAGS) -c $< -o $@

# Link the main application
$(BIN_DIR)/$(TARGET): $(BUILD_DIR) $(BIN_DIR) $(OBJECTS)
	$(CXX) $(OBJECTS) $(OBJCXXFLAGS) -o $@

# Create the app bundle
app: $(BIN_DIR)/$(TARGET)
	@echo "Creating app bundle..."
	mkdir -p $(APP_DIR)/Contents/MacOS
	mkdir -p $(APP_DIR)/Contents/Resources
	cp $(BIN_DIR)/$(TARGET) $(APP_DIR)/Contents/MacOS/
	cp config/Info.plist $(APP_DIR)/Contents/
	cp -r resources/* $(APP_DIR)/Contents/Resources/

# Compile test files
$(BUILD_DIR)/%.o: $(TEST_DIR)/%.mm
	@mkdir -p $(dir $@)
	$(CXX) $(OBJCXXFLAGS) -c $< -o $@

# Build and run tests
test: $(BUILD_DIR) $(BIN_DIR) $(TEST_OBJECTS) $(filter-out $(BUILD_DIR)/main.o, $(OBJECTS))
	$(CXX) $(TEST_OBJECTS) $(filter-out $(BUILD_DIR)/main.o, $(OBJECTS)) $(OBJCXXFLAGS) -framework XCTest -o $(BIN_DIR)/$(TEST_TARGET)
	./$(BIN_DIR)/$(TEST_TARGET)

# Clean build files
clean:
	rm -rf $(BUILD_DIR) $(BIN_DIR) $(APP_DIR)

# Format source files
format:
	find $(SRC_DIR) $(TEST_DIR) -iname *.h -o -iname *.mm -o -iname *.cpp | xargs clang-format -i --style=llvm

# Static analysis
analyze:
	clang-tidy $(SOURCES) -- $(OBJCXXFLAGS)

# Install dependencies (for CI)
install-deps:
	brew install llvm
	brew install clang-format
	brew install clang-tidy

# Run the application
run: app
	open $(APP_DIR)

.PHONY: all clean test format analyze install-deps app run

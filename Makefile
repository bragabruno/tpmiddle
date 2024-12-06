CC = clang++
CFLAGS = -Wall -Wextra -g -O2 -fobjc-arc -DDEBUG
FRAMEWORKS = -framework Foundation -framework IOKit -framework AppKit -framework CoreGraphics
OBJC_FLAGS = -x objective-c++
IBTOOL = ibtool

TARGET = tpmiddle
SOURCES = TPApplication.mm \
          TPConfig.mm \
          TPHIDManager.mm \
          TPHIDManagerConstants.mm \
          TPButtonManager.mm \
          TPStatusBarController.mm \
          TPLogger.mm \
          TPEventViewController.mm

OBJECTS = $(SOURCES:.mm=.o)
XIB_FILES = TPEventViewController.xib
NIB_FILES = $(XIB_FILES:.xib=.nib)

all: $(TARGET) $(NIB_FILES)

$(TARGET): $(OBJECTS)
	$(CC) $(OBJECTS) -o $(TARGET) $(FRAMEWORKS)

%.o: %.mm
	$(CC) $(CFLAGS) $(OBJC_FLAGS) -c $< -o $@

%.nib: %.xib
	$(IBTOOL) --compile $@ $<

clean:
	rm -f $(OBJECTS) $(TARGET) $(NIB_FILES)

install: $(TARGET) $(NIB_FILES)
	mkdir -p ~/Applications/$(TARGET).app/Contents/MacOS
	mkdir -p ~/Applications/$(TARGET).app/Contents/Resources
	cp $(TARGET) ~/Applications/$(TARGET).app/Contents/MacOS/
	cp Info.plist ~/Applications/$(TARGET).app/Contents/
	cp $(NIB_FILES) ~/Applications/$(TARGET).app/Contents/Resources/

.PHONY: all clean install

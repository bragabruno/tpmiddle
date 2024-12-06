# TPMiddle Analysis

## Overview

TPMiddle is a Windows application designed to manage and customize the middle button behavior on ThinkPad laptops. It works with both the TrackPoint and TouchPad devices through the Synaptics device drivers.

## Version Information

- Current Version: 0.7.0.0
- Released: 2011-2015
- Authors: Marek Wróbel & Gerhard Wiesinger

## Technical Details

### Architecture

- Written in C++ for Windows
- Interfaces with Synaptics SDK (SynKit.h)
- Runs as a background Windows application
- Supports multiple input devices simultaneously

### Core Features

1. **Device Support**
   - TrackPoint (IBM Compatible Stick)
   - TouchPad
   - Synaptics Pointing Devices

2. **Operation Modes**
   - **Default Mode**: Custom middle button handling with timeout detection
   - **Normal Mode** (-n flag): Direct event forwarding from input devices
   - **Reset Mode** (-r flag): Restores original middle button behavior

3. **Device Management**
   - Automatic device detection
   - Support for multiple concurrent devices
   - Event-based handling through Windows API
   - Device reconnection handling

### Implementation Details

#### Device Interaction

- Uses Synaptics API for device communication
- Monitors device events through Windows event system
- Handles device connection/disconnection events
- Processes button states and coordinates

#### Event Processing

- Monitors middle button state changes
- Implements double-click timing logic
- Handles both TouchPad and TrackPoint specific events
- Supports event filtering in Normal Mode

#### Configuration

- Command-line parameter support
- Permanent driver configuration changes
- Device-specific settings management

### Requirements

- Windows OS
- Synaptics drivers
- ThinkPad must be configured in "Only Classic TrackPoint Mode"

## Key Features

### Middle Button Handling

- Custom timing for middle button clicks
- Support for both momentary and toggle modes
- Event filtering to prevent duplicate events
- Device-specific button state tracking

### System Integration

- Windows event system integration
- Driver-level configuration
- Support for multiple input devices
- Automatic device detection and reconnection

## Development Features

- Debug mode support
- Delta event debugging
- Comprehensive event logging in debug builds
- Resource versioning and localization support

## Project Structure

The project consists of several key files:

- `tpmiddle.cpp`: Main application logic
- `tpmiddle.rc`: Resource definitions and version info
- `resource.h`: Resource identifiers
- Project files for Visual Studio (*.sln,*.vcxproj)

## Notes

- The application requires specific ThinkPad configuration
- Implements permanent driver configuration changes
- Includes comprehensive error handling and device management
- Supports both debug and release builds with different feature sets

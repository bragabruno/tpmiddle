#include "HIDDevice.h"
#include <IOKit/hid/IOHIDManager.h>
#include <iostream>

namespace TPMiddle {
namespace Infrastructure {

HIDDevice::HIDDevice(const std::string& id, const std::string& name, const std::string& deviceType)
    : m_id(id)
    , m_name(name)
    , m_deviceType(deviceType)
    , m_connected(false)
    , m_deviceHandle(nullptr) {
}

HIDDevice::~HIDDevice() {
    Close();
}

std::string HIDDevice::GetId() const {
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_id;
}

std::string HIDDevice::GetName() const {
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_name;
}

bool HIDDevice::IsConnected() const {
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_connected;
}

std::string HIDDevice::GetDeviceType() const {
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_deviceType;
}

std::string HIDDevice::GetLastError() const {
    std::lock_guard<std::mutex> lock(m_mutex);
    return m_lastError;
}

bool HIDDevice::Reset() {
    std::lock_guard<std::mutex> lock(m_mutex);
    if (!m_connected || !m_deviceHandle) {
        SetLastError("Device not connected");
        return false;
    }

    Close();
    return Open();
}

bool HIDDevice::Open() {
    std::lock_guard<std::mutex> lock(m_mutex);
    if (m_connected) {
        return true;
    }

    if (!InitializeDevice()) {
        return false;
    }

    m_connected = true;
    return true;
}

void HIDDevice::Close() {
    std::lock_guard<std::mutex> lock(m_mutex);
    if (!m_connected) {
        return;
    }

    CleanupDevice();
    m_connected = false;
}

bool HIDDevice::SendReport(const std::vector<uint8_t>& report) {
    std::lock_guard<std::mutex> lock(m_mutex);
    if (!m_connected || !m_deviceHandle) {
        SetLastError("Device not connected");
        return false;
    }

    IOHIDDeviceRef device = static_cast<IOHIDDeviceRef>(m_deviceHandle);
    IOReturn result = IOHIDDeviceSetReport(
        device,
        kIOHIDReportTypeOutput,
        0,  // Report ID
        report.data(),
        report.size()
    );

    if (result != kIOReturnSuccess) {
        SetLastError("Failed to send report");
        return false;
    }

    return true;
}

bool HIDDevice::ReadReport(std::vector<uint8_t>& report) {
    std::lock_guard<std::mutex> lock(m_mutex);
    if (!m_connected || !m_deviceHandle) {
        SetLastError("Device not connected");
        return false;
    }

    // Implementation specific to macOS HID device reading
    // This is a simplified version - actual implementation would need proper error handling
    // and possibly async reading capabilities
    
    report.resize(64);  // Typical HID report size
    CFIndex reportLength = report.size();
    
    IOHIDDeviceRef device = static_cast<IOHIDDeviceRef>(m_deviceHandle);
    IOReturn result = IOHIDDeviceGetReport(
        device,
        kIOHIDReportTypeInput,
        0,  // Report ID
        report.data(),
        &reportLength
    );

    if (result != kIOReturnSuccess) {
        SetLastError("Failed to read report");
        return false;
    }

    report.resize(reportLength);
    return true;
}

void HIDDevice::SetLastError(const std::string& error) {
    m_lastError = error;
    std::cerr << "HIDDevice Error: " << error << std::endl;
}

bool HIDDevice::InitializeDevice() {
    // Implementation specific to macOS HID device initialization
    // This is a simplified version - actual implementation would need proper device matching
    // and initialization logic
    
    IOHIDManagerRef manager = IOHIDManagerCreate(kCFAllocatorDefault, kIOHIDOptionsTypeNone);
    if (!manager) {
        SetLastError("Failed to create HID Manager");
        return false;
    }

    IOHIDManagerSetDeviceMatching(manager, NULL);  // Match all devices
    IOHIDManagerOpen(manager, kIOHIDOptionsTypeNone);

    // Device matching and setup would go here
    // For now, just cleanup the manager
    CFRelease(manager);

    return true;
}

void HIDDevice::CleanupDevice() {
    if (m_deviceHandle) {
        IOHIDDeviceRef device = static_cast<IOHIDDeviceRef>(m_deviceHandle);
        IOHIDDeviceClose(device, kIOHIDOptionsTypeNone);
        m_deviceHandle = nullptr;
    }
}

} // namespace Infrastructure
} // namespace TPMiddle

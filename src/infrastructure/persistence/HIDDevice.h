#ifndef TPMIDDLE_HID_DEVICE_H
#define TPMIDDLE_HID_DEVICE_H

#include "../../domain/models/Device.h"
#include <string>
#include <mutex>

namespace TPMiddle {
namespace Infrastructure {

/**
 * @brief Concrete implementation of IDevice for HID devices
 * 
 * This class implements the IDevice interface for physical HID devices,
 * providing the actual implementation for device operations.
 */
class HIDDevice : public Domain::IDevice {
public:
    HIDDevice(const std::string& id, const std::string& name, const std::string& deviceType);
    ~HIDDevice() override;

    // IDevice interface implementation
    std::string GetId() const override;
    std::string GetName() const override;
    bool IsConnected() const override;
    std::string GetDeviceType() const override;
    std::string GetLastError() const override;
    bool Reset() override;

    // HIDDevice specific methods
    bool Open();
    void Close();
    bool SendReport(const std::vector<uint8_t>& report);
    bool ReadReport(std::vector<uint8_t>& report);

private:
    std::string m_id;
    std::string m_name;
    std::string m_deviceType;
    std::string m_lastError;
    bool m_connected;
    void* m_deviceHandle;  // Platform-specific device handle
    mutable std::mutex m_mutex;

    void SetLastError(const std::string& error);
    bool InitializeDevice();
    void CleanupDevice();
};

} // namespace Infrastructure
} // namespace TPMiddle

#endif // TPMIDDLE_HID_DEVICE_H

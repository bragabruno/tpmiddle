#ifndef TPMIDDLE_DEVICE_H
#define TPMIDDLE_DEVICE_H

#include <string>

namespace TPMiddle {
namespace Domain {

/**
 * @brief Interface representing a HID device
 * 
 * This interface defines the contract for HID devices in the system.
 * Following Domain-Driven Design principles, this is a core domain entity.
 */
class IDevice {
public:
    virtual ~IDevice() = default;

    /**
     * @brief Get the unique identifier of the device
     * @return std::string The device ID
     */
    virtual std::string GetId() const = 0;

    /**
     * @brief Get the name of the device
     * @return std::string The device name
     */
    virtual std::string GetName() const = 0;

    /**
     * @brief Check if the device is currently connected
     * @return bool True if connected, false otherwise
     */
    virtual bool IsConnected() const = 0;

    /**
     * @brief Get the device type
     * @return std::string The device type identifier
     */
    virtual std::string GetDeviceType() const = 0;

    /**
     * @brief Get the last error message if any
     * @return std::string The last error message or empty string if no error
     */
    virtual std::string GetLastError() const = 0;

    /**
     * @brief Reset the device to its default state
     * @return bool True if reset successful, false otherwise
     */
    virtual bool Reset() = 0;
};

} // namespace Domain
} // namespace TPMiddle

#endif // TPMIDDLE_DEVICE_H

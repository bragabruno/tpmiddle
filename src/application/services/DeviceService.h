#ifndef TPMIDDLE_DEVICE_SERVICE_H
#define TPMIDDLE_DEVICE_SERVICE_H

#include "../../domain/models/Device.h"
#include "../../domain/repositories/DeviceRepository.h"
#include <memory>
#include <vector>
#include <functional>
#include <map>
#include <string>

namespace TPMiddle {
namespace Application {

/**
 * @brief Service interface for device management operations
 * 
 * This service coordinates device-related operations between the presentation
 * layer and the domain layer, implementing use cases for device management.
 */
class IDeviceService {
public:
    virtual ~IDeviceService() = default;

    using DeviceCallback = std::function<void(std::shared_ptr<Domain::IDevice>)>;
    using DeviceErrorCallback = std::function<void(const std::string&)>;

    /**
     * @brief Initialize the device service
     * @return bool True if initialization successful, false otherwise
     */
    virtual bool Initialize() = 0;

    /**
     * @brief Start device monitoring
     * @param onDeviceConnected Callback for device connection events
     * @param onDeviceDisconnected Callback for device disconnection events
     * @param onError Callback for error events
     * @return bool True if monitoring started successfully, false otherwise
     */
    virtual bool StartMonitoring(
        DeviceCallback onDeviceConnected,
        DeviceCallback onDeviceDisconnected,
        DeviceErrorCallback onError) = 0;

    /**
     * @brief Stop device monitoring
     */
    virtual void StopMonitoring() = 0;

    /**
     * @brief Get all currently connected devices
     * @return std::vector<std::shared_ptr<Domain::IDevice>> List of connected devices
     */
    virtual std::vector<std::shared_ptr<Domain::IDevice>> GetConnectedDevices() = 0;

    /**
     * @brief Configure a device
     * @param deviceId The ID of the device to configure
     * @param config Configuration parameters as key-value pairs
     * @return bool True if configuration successful, false otherwise
     */
    virtual bool ConfigureDevice(
        const std::string& deviceId,
        const std::map<std::string, std::string>& config) = 0;

    /**
     * @brief Reset a device to default settings
     * @param deviceId The ID of the device to reset
     * @return bool True if reset successful, false otherwise
     */
    virtual bool ResetDevice(const std::string& deviceId) = 0;

    /**
     * @brief Get the status of a specific device
     * @param deviceId The ID of the device
     * @return std::optional<std::string> Device status if available, empty optional otherwise
     */
    virtual std::optional<std::string> GetDeviceStatus(const std::string& deviceId) = 0;
};

} // namespace Application
} // namespace TPMiddle

#endif // TPMIDDLE_DEVICE_SERVICE_H

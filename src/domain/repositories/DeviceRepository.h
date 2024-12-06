#ifndef TPMIDDLE_DEVICE_REPOSITORY_H
#define TPMIDDLE_DEVICE_REPOSITORY_H

#include "../models/Device.h"
#include <memory>
#include <vector>
#include <optional>

namespace TPMiddle {
namespace Domain {

/**
 * @brief Repository interface for Device entities
 * 
 * This interface defines the contract for Device persistence operations.
 * Following the Repository pattern, it abstracts the data access layer.
 */
class IDeviceRepository {
public:
    virtual ~IDeviceRepository() = default;

    /**
     * @brief Find a device by its ID
     * @param id The device ID to search for
     * @return std::optional<std::shared_ptr<IDevice>> The device if found, empty optional otherwise
     */
    virtual std::optional<std::shared_ptr<IDevice>> FindById(const std::string& id) = 0;

    /**
     * @brief Get all connected devices
     * @return std::vector<std::shared_ptr<IDevice>> List of all connected devices
     */
    virtual std::vector<std::shared_ptr<IDevice>> GetConnectedDevices() = 0;

    /**
     * @brief Get devices by type
     * @param deviceType The type of devices to retrieve
     * @return std::vector<std::shared_ptr<IDevice>> List of devices of the specified type
     */
    virtual std::vector<std::shared_ptr<IDevice>> GetDevicesByType(const std::string& deviceType) = 0;

    /**
     * @brief Add a new device to the repository
     * @param device The device to add
     * @return bool True if device was added successfully, false otherwise
     */
    virtual bool Add(std::shared_ptr<IDevice> device) = 0;

    /**
     * @brief Remove a device from the repository
     * @param id The ID of the device to remove
     * @return bool True if device was removed successfully, false otherwise
     */
    virtual bool Remove(const std::string& id) = 0;

    /**
     * @brief Update device information
     * @param device The device with updated information
     * @return bool True if device was updated successfully, false otherwise
     */
    virtual bool Update(std::shared_ptr<IDevice> device) = 0;
};

} // namespace Domain
} // namespace TPMiddle

#endif // TPMIDDLE_DEVICE_REPOSITORY_H

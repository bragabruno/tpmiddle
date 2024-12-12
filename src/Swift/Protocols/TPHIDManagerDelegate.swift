import Foundation

protocol TPHIDManagerDelegate: AnyObject {
    func didDetectDeviceAttached(_ deviceInfo: String)
    func didDetectDeviceDetached(_ deviceInfo: String)
    func didEncounterError(_ error: Error)
    func didReceiveButtonPress(left: Bool, right: Bool, middle: Bool)
    func didReceiveMovement(deltaX: Int, deltaY: Int, buttonState: UInt8)
}
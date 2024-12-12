import Foundation

protocol TPStatusBarControllerDelegate: AnyObject {
    func statusBarControllerDidToggleEventViewer(_ show: Bool)
    func statusBarControllerWillQuit()
}

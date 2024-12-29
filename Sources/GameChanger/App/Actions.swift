import Foundation
import AppKit

enum Action: String, Codable {
    case none = ""
    case restart = "restart"
    case sleep = "sleep"
    case logout = "logout"
    case quit = "quit"
    case path = "path"
    case activate = "activate"
    case process = "process"
    
    private func executeProcess(_ command: String, appName: String? = nil, setFullscreen: Bool = false) {
        guard !UIVisibilityState.shared.isExecutingPath else { return }
        UIVisibilityState.shared.isExecutingPath = true
        
        // Hide UI elements first with shorter fade duration
        UIVisibilityState.shared.isVisible = false
        
        // Launch the process
        DispatchQueue.global(qos: .userInitiated).async {
            let parts = command.split(separator: " ", maxSplits: 1).map(String.init)
            guard let executable = parts.first else {
                DispatchQueue.main.async {
                    print("Invalid command: \(command)")
                    UIVisibilityState.shared.isVisible = true
                    UIVisibilityState.shared.isExecutingPath = false
                }
                return
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            
            // Set up pipes for output
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe
            
            // If there are arguments after the executable
            if parts.count > 1 {
                process.arguments = [parts[1]]
            }
            
            do {
                try process.run()
                if setFullscreen {
                    setFullScreen(for: appName ?? "")
                }
                // Reset executing state after successful launch
                DispatchQueue.main.async {
                    UIVisibilityState.shared.isExecutingPath = false
                }
            } catch {
                print("Failed to execute process: \(error)")
                
                // Ensure UI updates happen on main thread
                DispatchQueue.main.async {
                    UIVisibilityState.shared.isVisible = false

                    showErrorModal(
                        title: "Failed to Execute App",
                        message: "Could not run: \(command)\nError: \(error.localizedDescription)",
                        buttons: ["OK"],
                        defaultButton: "OK"
                    ) { button in
                        switch button {
                        case "OK":
                            UIVisibilityState.shared.isVisible = true
                            UIVisibilityState.shared.isExecutingPath = false
                        default:
                            break
                        }

                        if UIVisibilityState.shared.mouseVisible {
                            NSCursor.unhide()
                        } else {
                            NSCursor.hide()
                        }
                    }
                }
            }
        }
    }
    
    func execute(with path: String? = nil, appName: String? = nil, fullscreen: Bool? = nil) {
        print("Executing action: \(self)")
        switch self {
            case .none: return
            case .activate: SystemActions.sendAppleEvent(kAEActivate)
            case .restart: SystemActions.sendAppleEvent(kAERestart)
            case .sleep: SystemActions.sendAppleEvent(kAESleep)
            case .logout: SystemActions.sendAppleEvent(kAEShutDown)
            case .quit: NSApplication.shared.terminate(nil)
            case .process:
                if let command = path {
                    executeProcess(command)
                }
            case .path:
                if let command = path {
                    executeProcess(command, appName: appName ?? "", setFullscreen: fullscreen ?? false)
                }
        }
    }
    
    private func setFullScreen(for appName: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName == appName }) else {
                print("Could not find application: \(appName)")
                return
            }
            
            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            
            var windowRef: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowRef)
            
            if result == .success,
               let windows = windowRef as? [AXUIElement],
               let window = windows.first {
                AXUIElementSetAttributeValue(window, "AXFullScreen" as CFString, true as CFBoolean)
            } else {
                print("Failed to get window or set fullscreen for: \(appName)")
            }
        }
    }
}

struct SystemActions {
    static func sendAppleEvent(_ eventID: UInt32) {
        var psn = ProcessSerialNumber(highLongOfPSN: 0, lowLongOfPSN: UInt32(kSystemProcess))
        let target = NSAppleEventDescriptor(
            descriptorType: typeProcessSerialNumber,
            bytes: &psn,
            length: MemoryLayout.size(ofValue: psn)
        )
        
        let event = NSAppleEventDescriptor(
            eventClass: kCoreEventClass,
            eventID: eventID,
            targetDescriptor: target,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        
        _ = try? event.sendEvent(
            options: [.noReply],
            timeout: TimeInterval(kAEDefaultTimeout)
        )
    }
} 
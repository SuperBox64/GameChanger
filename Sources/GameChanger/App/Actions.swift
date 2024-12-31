import Foundation
import AppKit

enum Action: String, Codable {
    case none = ""
    case restart = "restart"
    case sleep = "sleep"
    case logout = "logout"
    case quit = "quit"
    case app = "app"
    case activate = "activate"
    case wine = "wine"
    
    func isWinePreloaderRunning(appName:String) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-ax"]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        
        do {
            try process.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                return output.contains(appName)
            }
        } catch {
            print("Error checking for wine64-preloader: \(error)")
        }

        return false
    }

    private func executeProcess(_ command: String, action: Action, appName: String, setFullscreen: Bool) {
        guard UIVisibilityState.shared.isVisible else { return }
        
        // Hide UI elements first with shorter fade duration
        UIVisibilityState.shared.isVisible = false
        
        // Launch the process
        DispatchQueue.global(qos: .userInitiated).async {
            let parts = command.split(separator: " ", maxSplits: 1).map(String.init)
            guard let executable = parts.first else {
                DispatchQueue.main.async {
                    print("Invalid command: \(command)")
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
            
            let running = isWinePreloaderRunning(appName: appName)

            if action == .wine && running {
                if running {
                    showRunningAppModal(
                        title: "App Already Running",
                        message: "\(appName) is already running. Please close it before launching another instance."
                    ) {
                        resetUIState()
                    }
                    return
                }
            }


            do {
                try process.run()
                if setFullscreen {
                    setFullScreen(for: appName)
                }
                // Reset executing state after successful launch
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    UIVisibilityState.shared.isVisible = true
                }
            } catch {
                print("Failed to execute process: \(error)")
                
                // Ensure UI updates happen on main thread
                DispatchQueue.main.async {
                    showRunningAppModal(
                        title: "Failed to Execute App",
                        message: "Could not run: \(command)\nError: \(error.localizedDescription)"
                    ) {
                        resetUIState()
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
            case .wine:
                if let command: String = path, let appName, let fullscreen {
                    executeProcess(command, action: .wine, appName: appName, setFullscreen: fullscreen)
                }
            case .app:
                if let command: String = path, let appName, let fullscreen {
                    executeProcess(command, action: .app, appName: appName, setFullscreen: fullscreen)
                }
        }
    }
    
    private func setFullScreen(for appName: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
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

    private func activateRunningApp(pid: pid_t) {
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) {
            app.activate(options: .activateIgnoringOtherApps)
            UIVisibilityState.shared.isVisible = false
            UIVisibilityState.shared.isExecutingPath = false
        }
    }

    private func showRunningAppModal(title: String, message: String, completion: @escaping () -> Void) {
        DispatchQueue.main.async {
            showErrorModal(
                title: title,
                message: message,
                buttons: ["OK"]
            ) { _ in
                completion()
            }
        }
    }

    private func resetUIState() {
        UIVisibilityState.shared.isVisible = true
        UIVisibilityState.shared.isExecutingPath = false
        
        if UIVisibilityState.shared.mouseVisible {
            NSCursor.unhide()
        } else {
            NSCursor.hide()
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
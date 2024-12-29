import SwiftUI

func showErrorModal(
    title: String,
    message: String,
    buttons: [String] = ["OK"],
    defaultButton: String = "OK",
    completion: ((String) -> Void)? = nil
) {

    // Play system alert sound
    DispatchQueue.global(qos: .background).async {
        NSSound.beep()
    }

    if !Thread.isMainThread {
        print("Not on main thread")
        return
    }
    
    NSCursor.unhide()  // Show cursor before creating alert
    
    // Create a hidden window for alerts
    let alertWindow = NSWindow(
        contentRect: .zero,
        styleMask: [.titled],
        backing: .buffered,
        defer: true
    )
    alertWindow.isReleasedWhenClosed = true
    alertWindow.orderOut(nil)
    
    let alert = NSAlert()
    alert.messageText = title
    alert.informativeText = message
    alert.alertStyle = .warning
    
    for buttonTitle in buttons {
        let button = alert.addButton(withTitle: buttonTitle)
        if buttonTitle == defaultButton {
            button.keyEquivalent = "\r"
        }
    }
    
    alert.window.level = .floating  // Make alert float above main window
    
    // Move cursor to center of screen, adjusted up and right
    if let screen = NSScreen.main {
        let centerX = screen.frame.origin.x + screen.frame.width / 2 + 57.5  // 115/2 pixels right
        let centerY = screen.frame.origin.y + screen.frame.height / 2 - 115   // 115 pixels up (subtract to move up)
        CGWarpMouseCursorPosition(CGPoint(x: centerX, y: centerY))
    }
    
    let response = alert.runModal()
    
    print("After alert - MouseIndicator showing: \(MouseIndicatorState.shared.showingProgress)")
    
    let buttonIndex = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
    let clickedButton = buttons[Int(buttonIndex)]
    
    completion?(clickedButton)
}

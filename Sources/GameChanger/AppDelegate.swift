import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var cursorHideTimer: Timer?
    var screenshotTimer: Timer?
    
    private func initializeCache() {
        var loadedImages = 0
        var totalImages = 0
        
        // First pass - count total images
        for section in Section.allCases {
            let items = AppDataManager.shared.items(for: Section(rawValue: section.rawValue))
            totalImages += items.count
        }
        
        // Second pass - load images synchronously
        for section in Section.allCases {
            let items = AppDataManager.shared.items(for: Section(rawValue: section.rawValue))
            for item in items {
                autoreleasepool {
                    if let iconURL = Bundle.main.url(forResource: item.systemIcon, 
                                                   withExtension: "svg", 
                                                   subdirectory: "images/svg") {
                        if let image = NSImage(contentsOf: iconURL) {
                            ImageCache.shared.cache[item.systemIcon] = image
                            loadedImages += 1
                            print("[\(loadedImages)/\(totalImages)] Loaded: \(item.name)")
                        } else {
                            print("Failed to load image for: \(item.name)")
                        }
                    } else {
                        print("Failed to find image URL for: \(item.name)")
                    }
                }
            }
        }
        
        // Verify cache
        print("=== Verifying Cache ===")
        for section in Section.allCases {
            let items = AppDataManager.shared.items(for: Section(rawValue: section.rawValue))
            for item in items {
                if ImageCache.shared.cache[item.systemIcon] == nil {
                    print("WARNING: Missing cache entry for \(item.name)")
                }
            }
        }
        
        // Only set isLoaded after ALL images are confirmed in cache
        if loadedImages == totalImages {
            AppState.shared.isLoaded = true
            print("App state set to loaded")
        } else {
            print("ERROR: Not all images loaded!")
        }
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.hideOtherApplications(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    
        let presOptions: NSApplication.PresentationOptions = [.hideDock, .hideMenuBar]
        NSApp.presentationOptions = presOptions


        if let window = NSApp.windows.first {
            window.styleMask = [.borderless, .fullSizeContentView]
            window.makeKeyAndOrderFront(nil)
            window.setFrame(NSScreen.main?.frame ?? .zero, display: true)
            window.alphaValue = 0.0
  
            // Prevent window scaling when alerts appear
            NotificationCenter.default.addObserver(
                forName: NSWindow.willBeginSheetNotification,
                object: window,
                queue: .main
            ) { _ in
                window.setContentSize(NSScreen.main?.frame.size ?? .zero)
            }
  
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.5
                context.timingFunction = CAMediaTimingFunction(name: .linear)
                window.animator().alphaValue = 1.0
            }      
        }
        
        initializeCache()
        
        NotificationCenter.default.post(name: .startupBounce, object: nil)
 
        if UIVisibilityState.shared.mouseVisible {
            NSCursor.unhide()
        } else {
            NSCursor.hide()
        }

        for index in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index)) { 
                SystemActions.sendAppleEvent(kAEActivate)
            }
        }
      

        // Set up menu bar
        let mainMenu = NSMenu()
        NSApp.mainMenu = mainMenu
        
        // Add App menu
        let appMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)
        
        // Add Quit item
        let quitMenuItem = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenu.addItem(quitMenuItem)

        if SizingGuide.getCommonSettings().enableScreenshots {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.takeScreenshot()
            }
        }
        
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        //cursorHideTimer?.invalidate()
        screenshotTimer?.invalidate()
        NSCursor.unhide()
    }
    
    func applicationDidBecomeActive(_ notification: Notification) {
        NSApp.hideOtherApplications(nil)
        SystemActions.sendAppleEvent(kAEActivate)

        // Just trigger the fade in
        UIVisibilityState.shared.isVisible = true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
    
    private func takeScreenshot() {        
        if let window = NSApp.windows.first,
           let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            CGWindowID(window.windowNumber),
            [.boundsIgnoreFraming]
           ) {
            let image = NSImage(cgImage: cgImage, size: window.frame.size)
            if let tiffData = image.tiffRepresentation,
               let bitmapRep = NSBitmapImageRep(data: tiffData),
               let pngData = bitmapRep.representation(using: .png, properties: [:]) {
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
                let timestamp = dateFormatter.string(from: Date())
                let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
                let fileURL = desktopURL.appendingPathComponent("GameChanger_\(timestamp).png")
                
                try? pngData.write(to: fileURL)
                print("Screenshot saved to: \(fileURL.path)")
            }
        }
    }
}
//
//  SuerBox64 GameChanger.swift
//  Created by Todd Bruss on 3/17/24.
//

import SwiftUI
//import GameController
//import Carbon.HIToolbox

@main
struct GameChangerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var windowSizeMonitor = WindowSizeMonitor.shared
    @StateObject private var uiVisibility = UIVisibilityState.shared
    @StateObject private var screenRecorder = ScreenRecorder()
    @State var startupSound = false
    var body: some Scene {
        WindowGroup {
            ZStack {
                BackgroundView()
                .onAppear {
                    if !startupSound {
                        startupSound.toggle()
                    SoundPlayer.shared.playStartupSound()
                    }
                }
            
                Group {
                    LogoView()
                    ClockView()
                    if uiVisibility.isGridVisible {
                        GameGridView()
                    } else {
                        ContentView()
                    }
                    MouseIndicatorView()
                    NavigationOverlayView()
                    ShortcutHintView()
                    RecordingIndicatorView(screenRecorder: screenRecorder)
                }
                .opacity(uiVisibility.isVisible ? 1 : 0)
                .animation(
                    .spring(
                        response: 1.2,
                        dampingFraction: 0.8,
                        blendDuration: 1.0
                    ),
                    value: uiVisibility.isVisible
                )
            }
            .background(Color.black)
            .frame(width: .infinity, height: .infinity)
            .environmentObject(windowSizeMonitor)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.automatic)
    }
}




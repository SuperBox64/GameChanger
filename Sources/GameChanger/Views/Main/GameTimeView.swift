import SwiftUI
import Carbon.HIToolbox

struct GameTimeView: View {
    @StateObject private var uiVisibility = UIVisibilityState.shared
    @State private var keyMonitor: Any?
    @State private var mouseMonitor: Any?
    @Binding var currentSection: String
    @Binding var selectedIndex: Int
    @Binding var titleOpacity: Double
    @Binding var opacity: Double
    let back: () -> Void
    let handleSelection: () -> Void
    let moveLeft: () -> Void
    let moveRight: () -> Void
    let resetMouseState: () -> Void
    let visibleItems: [AppItem]
    let showingNextItems: Bool
    let nextItems: [AppItem]
    let currentOffset: CGFloat
    let nextOffset: CGFloat
    let sizingManager: SizingManager
    
    private func setupKeyMonitorForGameTimeView() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case kVK_Escape:
                UIVisibilityState.shared.mouseVisible.toggle()
                if UIVisibilityState.shared.mouseVisible {
                    SystemActions.sendAppleEvent(kAEActivate)
                    NSCursor.unhide()
                } else {
                    NSCursor.hide()
                    SystemActions.sendAppleEvent(kAEActivate)
                }
            case kVK_ANSI_Q:
                NSApplication.shared.terminate(nil)
            case kVK_UpArrow:
                resetMouseState()
                back()
            case kVK_DownArrow:
                resetMouseState()
                handleSelection()
            case kVK_LeftArrow:
                resetMouseState()
                moveLeft()
            case kVK_RightArrow:
                resetMouseState()
                moveRight()
            case kVK_Return, kVK_Space:
                resetMouseState()
                handleSelection()
            default: break
            }
            return nil
        }
    }
    
    private func setupMouseMonitor() {
        // mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { event in
        //     return nil
        // }
        
        // // Left click for selection
        // NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
        //     resetMouseState()
        //     handleSelection()
        //     return nil
        // }
        
        // // Right click for back
        // NSEvent.addLocalMonitorForEvents(matching: .rightMouseDown) { event in
        //     resetMouseState()
        //     back()
        //     return nil
        // }
    }
    
    var body: some View {
        ZStack {
            // Title at the top
            VStack {
                Text(currentSection)
                    .font(.custom(
                        SizingGuide.getCommonSettings().fonts.title,
                        size: SizingGuide.getCurrentSettings().title.size
                    ))
                    .foregroundColor(.white)
                    .opacity(titleOpacity)
                    .padding(.top, SizingGuide.getCurrentSettings().title.topPadding)
                Spacer()
            }
            .opacity(uiVisibility.isVisible ? 1 : 0)

            // Carousel in center
            CarouselView(
                visibleItems: visibleItems,
                selectedIndex: UIVisibilityState.shared.mouseVisible ? -1 : selectedIndex,
                sizing: sizingManager.sizing,
                currentOffset: currentOffset,
                showingNextItems: showingNextItems,
                nextOffset: nextOffset,
                nextItems: nextItems,
                onHighlight: { index in
                    if UIVisibilityState.shared.mouseVisible {
                        selectedIndex = index
                    }
                },
                onSelect: { index in
                    selectedIndex = index
                    resetMouseState()
                    handleSelection()
                },
                onBack: { index in
                    selectedIndex = index
                    resetMouseState()
                    back()
                },
                onSwipeLeft: {
                    if UIVisibilityState.shared.mouseVisible {
                        resetMouseState()
                        moveRight()
                    }
                },
                onSwipeRight: {
                    if UIVisibilityState.shared.mouseVisible {
                        resetMouseState()
                        moveLeft()
                    }
                }
            )
            .opacity(opacity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            setupKeyMonitorForGameTimeView()
            setupMouseMonitor()
        }
        .onDisappear {
            if let keyMonitor = keyMonitor {
                NSEvent.removeMonitor(keyMonitor)
            }
            if let mouseMonitor = mouseMonitor {
                NSEvent.removeMonitor(mouseMonitor)
            }
        }
    }
} 
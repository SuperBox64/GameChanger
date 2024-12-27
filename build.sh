#!/bin/bash
source ./common.sh

# Default values
BUILD_TYPE="release"
SHOULD_OPEN=false
ONLY_OPEN=false

show_help() {
    echo "Usage: ./build.sh [-d|-r] [-o] [-h]"
    echo ""
    echo "Options:"
    echo "  -d    Build debug version"
    echo "  -r    Build release version (default)"
    echo "  -o    Open app after building, or just open if no other flags"
    echo "  -h    Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./build.sh -r        # Build release version"
    echo "  ./build.sh -d        # Build debug version"
    echo "  ./build.sh -o        # Open existing app"
    echo "  ./build.sh -r -o     # Build release and open"
    echo "  ./build.sh -d -o     # Build debug and open with debugger"
    exit 0
}

# Parse command line arguments
while getopts "droh" opt; do
    case $opt in
        d) BUILD_TYPE="debug" ;;
        r) BUILD_TYPE="release" ;;
        o) 
            if [ $OPTIND -eq 2 ]; then
                ONLY_OPEN=true
            else
                SHOULD_OPEN=true
            fi
            ;;
        h) show_help ;;
        \?) echo "Invalid option -$OPTARG" >&2; exit 1 ;;
    esac
done

# Add this function near the top of the script
show_debug_help() {
    echo ""
    echo "Common LLDB Commands:"
    echo "-----------------------------------"
    echo "run                     # Start the app"
    echo "breakpoint set -n name  # Set breakpoint at function name"
    echo "bt                      # Show backtrace (call stack)"
    echo "continue               # Continue execution"
    echo "next                   # Step over"
    echo "step                   # Step into"
    echo "quit                   # Exit debugger"
    echo "-----------------------------------"
    echo ""
}

check_debug_permissions() {
    if ! csrutil status | grep -q "disabled"; then
        echo "Note: System Integrity Protection might prevent debugging."
        echo "You may need to grant additional permissions in:"
        echo "System Settings > Privacy & Security > Developer Tools"
        echo ""
    fi
    
    if ! DevToolsSecurity -status | grep -q "enabled"; then
        echo "Debug permissions not enabled. Please run:"
        echo "sudo DevToolsSecurity -enable"
        echo ""
        echo "Then try again."
        exit 1
    fi
    
    if ! dscl . read /Groups/_developer GroupMembership | grep -q $(whoami); then
        echo "User not in developer group. Please run:"
        echo "sudo dscl . append /Groups/_developer GroupMembership $(whoami)"
        echo ""
        echo "Then try again."
        exit 1
    fi
}

if [ "$ONLY_OPEN" = true ]; then
    if [ -d "GameChanger.app" ]; then
        echo "Opening existing GameChanger.app..."
        open GameChanger.app
        exit 0
    else
        echo "Error: GameChanger.app not found. Build it first."
        exit 1
    fi
fi

# Execute common setup
clean_builds
create_app_structure
create_info_plist

if [ "$BUILD_TYPE" = "debug" ]; then
    echo "Building debug version for Apple Silicon..."
    # Remove the problematic -O0 flag and simplify debug build
    swift build -c debug \
        --arch arm64 \
        --jobs $(sysctl -n hw.ncpu) \
        -Xswiftc "-g"
    
    # Copy binary
    cp .build/arm64-apple-macosx/debug/GameChanger GameChanger.app/Contents/MacOS/GameChanger
else
    echo "Building release version..."
    # Build Universal Binary
    echo "Building for Apple Silicon..."
    swift build -c release --arch arm64 --jobs $(sysctl -n hw.ncpu) -Xswiftc -O -Xswiftc -whole-module-optimization
    echo "Building for Intel..."
    swift build -c release --arch x86_64 --jobs $(sysctl -n hw.ncpu) -Xswiftc -O -Xswiftc -whole-module-optimization

    # Create Universal Binary
    lipo -create \
        .build/arm64-apple-macosx/release/GameChanger \
        .build/x86_64-apple-macosx/release/GameChanger \
        -output GameChanger.app/Contents/MacOS/GameChanger
fi

# Copy resources and sign
copy_resources
chmod +x GameChanger.app/Contents/MacOS/GameChanger
sign_app

# Add this after signing in debug mode
if [ "$BUILD_TYPE" = "debug" ]; then
    echo "Verifying debug build signing..."
    codesign -dvv GameChanger.app
fi

echo "App bundle created at GameChanger.app"
if [ "$SHOULD_OPEN" = true ]; then
    if [ "$BUILD_TYPE" = "debug" ]; then
        check_debug_permissions
        show_debug_help
        echo "Launching in debug mode with lldb..."
        echo "Type 'run' to start the app"
        echo "Type 'bt' for backtrace if it crashes"
        echo "Type 'quit' to exit debugger"
        echo "-----------------------------------"
        
        # Try launching with different flags
        lldb -o "run" \
             -f GameChanger.app/Contents/MacOS/GameChanger \
             --wait-for
    else
        open GameChanger.app
    fi
fi
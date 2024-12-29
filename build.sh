#!/bin/bash
source ./common.sh

# Default values
BUILD_TYPE="release"
SHOULD_OPEN=false
ONLY_OPEN=false
SHOULD_CLEAN=false

# Function definitions first
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

clean_build() {
    echo "Cleaning build directory..."
    rm -rf .build
    rm -rf GameChanger.app
    echo "Clean complete"
}

sign_app() {
    if [ "$BUILD_TYPE" = "debug" ]; then
        # For debug builds, use development certificate
        echo "Signing with development certificate..."
        DEVELOPER_ID=$(security find-identity -v -p codesigning | grep "Apple Development" | head -1 | awk -F '"' '{print $2}')
        
        if [ -z "$DEVELOPER_ID" ]; then
            echo "No Development certificate found. Using ad-hoc signing."
            codesign --force --deep --sign - \
                     --entitlements "GameChanger.entitlements" \
                     --options runtime \
                     GameChanger.app
        else
            echo "Signing with: $DEVELOPER_ID"
            codesign --force --deep --sign "$DEVELOPER_ID" \
                     --entitlements "GameChanger.entitlements" \
                     --options runtime \
                     GameChanger.app
        fi
    else
        # For release builds, use distribution certificate
        echo "Signing with distribution certificate..."
        DEVELOPER_ID=$(security find-identity -v -p codesigning | grep "Apple Distribution" | head -1 | awk -F '"' '{print $2}')
        
        if [ -z "$DEVELOPER_ID" ]; then
            echo "No Distribution certificate found. Using ad-hoc signing."
            codesign --force --deep --sign - \
                     --entitlements "GameChanger.entitlements" \
                     --options runtime \
                     GameChanger.app
        else
            echo "Signing with: $DEVELOPER_ID"
            codesign --force --deep --sign "$DEVELOPER_ID" \
                     --entitlements "GameChanger.entitlements" \
                     --options runtime \
                     GameChanger.app
        fi
    fi
}

show_help() {
    echo "Usage: ./build.sh [-d|-r] [-o] [-c] [-h]"
    echo ""
    echo "Options:"
    echo "  -d    Build debug version"
    echo "  -r    Build release version (default)"
    echo "  -o    Open app after building, or just open if no other flags"
    echo "  -c    Clean build directory before building"
    echo "  -h    Show this help message"
    echo ""
    echo "Examples:"
    echo "  ./build.sh -r        # Build release version"
    echo "  ./build.sh -d        # Build debug version"
    echo "  ./build.sh -o        # Open existing app"
    echo "  ./build.sh -r -o     # Build release and open"
    echo "  ./build.sh -d -o     # Build debug and open with debugger"
    echo "  ./build.sh -c -d     # Clean and build debug version"
    exit 0
}

# Parse command line arguments
while getopts "droch" opt; do
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
        c) SHOULD_CLEAN=true ;;
        h) show_help ;;
        \?) echo "Invalid option -$OPTARG" >&2; exit 1 ;;
    esac
done

# Handle cleaning first if requested
if [ "$SHOULD_CLEAN" = true ]; then
    clean_build
    # Don't exit here - allow build to continue if other flags are present
fi

# Execute common setup
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
    swift build -c release \
        --arch arm64 \
        --jobs $(sysctl -n hw.ncpu) \
        -Xswiftc -O

    echo "Building for Intel..."
    swift build -c release \
        --arch x86_64 \
        --jobs $(sysctl -n hw.ncpu) \
        -Xswiftc -O

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
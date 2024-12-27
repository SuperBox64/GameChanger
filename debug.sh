#!/bin/bash
source ./common.sh

# Execute common setup
clean_builds
create_app_structure
create_info_plist

# Build debug version
echo "Building for Apple Silicon..."
swift build -c debug --arch arm64 --jobs $(sysctl -n hw.ncpu)

# Copy binary
cp .build/arm64-apple-macosx/debug/GameChanger GameChanger.app/Contents/MacOS/GameChanger

# Copy resources and sign
copy_resources
chmod +x GameChanger.app/Contents/MacOS/GameChanger
sign_app

echo "App bundle created at GameChanger.app"
open GameChanger.app
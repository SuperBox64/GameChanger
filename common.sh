#!/bin/bash

# Clean previous builds
clean_builds() {
    rm -rf GameChanger.app
    rm -rf .build
    rm -rf AppIcon.iconset
}

# Create app structure and icons
create_app_structure() {
    # Create directories
    mkdir -p GameChanger.app/Contents/{MacOS,Resources}
    mkdir -p AppIcon.iconset

    # Create icon sizes
    for size in 16 32 128 256 512; do
        sips -z $size $size Sources/GameChanger/images/png/superbox64.png --out AppIcon.iconset/icon_${size}x${size}.png
        if [ $size != 512 ]; then
            sips -z $((size*2)) $((size*2)) Sources/GameChanger/images/png/superbox64.png --out AppIcon.iconset/icon_${size}x${size}@2x.png
        fi
    done
    sips -z 1024 1024 Sources/GameChanger/images/png/superbox64.png --out AppIcon.iconset/icon_512x512@2x.png

    # Create icns file
    iconutil -c icns AppIcon.iconset -o GameChanger.app/Contents/Resources/AppIcon.icns
}

# Create Info.plist
create_info_plist() {
    cat > GameChanger.app/Contents/Info.plist << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>GameChanger</string>
    <key>CFBundleIdentifier</key>
    <string>com.SuperBox64.GameChanger</string>
    <key>CFBundleName</key>
    <string>GameChanger</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>CFBundleSupportedPlatforms</key>
    <array>
        <string>MacOSX</string>
    </array>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>NSCameraUsageDescription</key>
    <string>GameChanger needs camera access for recording with camera overlay.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>GameChanger needs microphone access to record audio during screen recording.</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>SuperBox64 GameChanger needs to control window state of launched applications.</string>
    <key>NSAccessibilityUsageDescription</key>
    <string>SuperBox64 GameChanger needs accessibility access to control application windows.</string>
</dict>
</plist>
EOF
}

# Copy resources
copy_resources() {
    # Create Resources directory structure
    mkdir -p GameChanger.app/Contents/Resources/images/{svg,jpg,png,logo}
    mkdir -p Sources/GameChanger/Resources

    # Copy JSON files if they don't exist in source
    [ ! -f Sources/GameChanger/Resources/app_items.json ] && cp Resources/app_items.json Sources/GameChanger/Resources/ || true
    [ ! -f Sources/GameChanger/Resources/gamechanger-ui.json ] && cp Resources/gamechanger-ui.json Sources/GameChanger/Resources/ || true

    # Copy resources
    cp -r Sources/GameChanger/images/svg/* GameChanger.app/Contents/Resources/images/svg/
    cp -r Sources/GameChanger/images/jpg/* GameChanger.app/Contents/Resources/images/jpg/
    cp -r Sources/GameChanger/images/png/* GameChanger.app/Contents/Resources/images/png/
    cp -r Sources/GameChanger/images/logo/* GameChanger.app/Contents/Resources/images/logo/
    cp Sources/GameChanger/Resources/app_items.json GameChanger.app/Contents/Resources/
    cp Sources/GameChanger/Resources/gamechanger-ui.json GameChanger.app/Contents/Resources/
    cp Sources/GameChanger/Resources/StartupTwentiethAnniversaryMac.wav GameChanger.app/Contents/Resources/
}

# Sign the app
sign_app() {
    # Clean any resource forks and Finder metadata
    xattr -cr GameChanger.app
    find GameChanger.app -type f -name "._*" -delete
    find GameChanger.app -type f -name ".DS_Store" -delete

    if [ "$BUILD_TYPE" = "debug" ]; then
        echo "Signing for debugging..."
        codesign --force --deep --sign - \
                 --entitlements "GameChanger.entitlements" \
                 --options runtime \
                 --preserve-metadata=identifier,requirements,flags,runtime \
                 GameChanger.app
    else
        # Release signing code...
        DEVELOPER_ID=$(security find-identity -v -p codesigning | grep "Apple Distribution" | head -1 | awk -F '"' '{print $2}')
        if [ -z "$DEVELOPER_ID" ]; then
            echo "No Developer ID found. Using ad-hoc signing with entitlements."
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
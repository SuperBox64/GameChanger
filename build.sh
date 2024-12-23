#!/bin/bash

# Clean previous builds
rm -rf GameChanger.app
rm -rf .build
rm -rf AppIcon.iconset

# Create app bundle structure
mkdir -p GameChanger.app/Contents/{MacOS,Resources}
mkdir -p AppIcon.iconset

# Create icon sizes from superbox64.png
sips -z 16 16     Sources/GameChanger/images/png/superbox64.png --out AppIcon.iconset/icon_16x16.png
sips -z 32 32     Sources/GameChanger/images/png/superbox64.png --out AppIcon.iconset/icon_16x16@2x.png
sips -z 32 32     Sources/GameChanger/images/png/superbox64.png --out AppIcon.iconset/icon_32x32.png
sips -z 64 64     Sources/GameChanger/images/png/superbox64.png --out AppIcon.iconset/icon_32x32@2x.png
sips -z 128 128   Sources/GameChanger/images/png/superbox64.png --out AppIcon.iconset/icon_128x128.png
sips -z 256 256   Sources/GameChanger/images/png/superbox64.png --out AppIcon.iconset/icon_128x128@2x.png
sips -z 256 256   Sources/GameChanger/images/png/superbox64.png --out AppIcon.iconset/icon_256x256.png
sips -z 512 512   Sources/GameChanger/images/png/superbox64.png --out AppIcon.iconset/icon_256x256@2x.png
sips -z 512 512   Sources/GameChanger/images/png/superbox64.png --out AppIcon.iconset/icon_512x512.png
sips -z 1024 1024 Sources/GameChanger/images/png/superbox64.png --out AppIcon.iconset/icon_512x512@2x.png

# Create icns file
iconutil -c icns AppIcon.iconset -o GameChanger.app/Contents/Resources/AppIcon.icns

# Create Info.plist
cat > GameChanger.app/Contents/Info.plist << EOL
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
</dict>
</plist>
EOL

# Build Universal Binary (Apple Silicon and Intel)
echo "Building for Apple Silicon..."
swift build -c release --arch arm64 --jobs $(sysctl -n hw.ncpu) -Xswiftc -O -Xswiftc -whole-module-optimization
echo "Building for Intel..."
swift build -c release --arch x86_64 --jobs $(sysctl -n hw.ncpu) -Xswiftc -O -Xswiftc -whole-module-optimization

# Create Universal Binary
echo "Creating Universal Binary..."
lipo -create \
    .build/arm64-apple-macosx/release/GameChanger \
    .build/x86_64-apple-macosx/release/GameChanger \
    -output GameChanger.app/Contents/MacOS/GameChanger

# Create Resources directory structure
mkdir -p GameChanger.app/Contents/Resources/images/{svg,jpg,png,logo}
mkdir -p Sources/GameChanger/Resources
# Copy JSON if it doesn't exist in source
[ ! -f Sources/GameChanger/Resources/app_items.json ] && cp Resources/app_items.json Sources/GameChanger/Resources/
[ ! -f Sources/GameChanger/Resources/carousel-ui.json ] && cp Resources/carousel-ui.json Sources/GameChanger/Resources/

# Copy resources
cp -r Sources/GameChanger/images/svg/* GameChanger.app/Contents/Resources/images/svg/
cp -r Sources/GameChanger/images/jpg/* GameChanger.app/Contents/Resources/images/jpg/
cp -r Sources/GameChanger/images/png/* GameChanger.app/Contents/Resources/images/png/
cp -r Sources/GameChanger/images/logo/* GameChanger.app/Contents/Resources/images/logo/
cp Sources/GameChanger/Resources/app_items.json GameChanger.app/Contents/Resources/
cp Sources/GameChanger/Resources/carousel-ui.json GameChanger.app/Contents/Resources/

# Set permissions
chmod +x GameChanger.app/Contents/MacOS/GameChanger

# Debug: Show all available certificates
echo "Available certificates:"
security find-identity -v -p codesigning

# Get first available Developer ID (modified pattern)
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

echo "App bundle created at GameChanger.app"
open GameChanger.app 
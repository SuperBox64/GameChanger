#!/bin/bash

# Create main directory structure
mkdir -p Sources/GameChanger/{App,Views,Models,Utils,Extensions,Services}

# App - Core application files
mv Sources/GameChanger/GameChanger.swift Sources/GameChanger/App/
mv Sources/GameChanger/AppDelegate.swift Sources/GameChanger/App/
mv Sources/GameChanger/Actions.swift Sources/GameChanger/App/

# Views - All SwiftUI views
mkdir -p Sources/GameChanger/Views/{Main,Components}
mv Sources/GameChanger/ContentView.swift Sources/GameChanger/Views/Main/
mv Sources/GameChanger/GameGridView.swift Sources/GameChanger/Views/Main/
mv Sources/GameChanger/NavigatorView.swift Sources/GameChanger/Views/Main/

# View Components
mv Sources/GameChanger/AppIconView.swift Sources/GameChanger/Views/Components/
mv Sources/GameChanger/BackgroundView.swift Sources/GameChanger/Views/Components/
mv Sources/GameChanger/ClockView.swift Sources/GameChanger/Views/Components/
mv Sources/GameChanger/LogoView.swift Sources/GameChanger/Views/Components/
mv Sources/GameChanger/MouseIndicatorView.swift Sources/GameChanger/Views/Components/
mv Sources/GameChanger/ShortcutView.swift Sources/GameChanger/Views/Components/
mv Sources/GameChanger/CarouselView.swift Sources/GameChanger/Views/Components/

# Models - Data models and state objects
mv Sources/GameChanger/SettingsModels.swift Sources/GameChanger/Models/
mv Sources/GameChanger/StateObjects.swift Sources/GameChanger/Models/

# Utils - Helper utilities
mv Sources/GameChanger/SizingGuide.swift Sources/GameChanger/Utils/
mv Sources/GameChanger/ShowErrorModalView.swift Sources/GameChanger/Utils/
mv Sources/GameChanger/Notifications.swift Sources/GameChanger/Utils/

# Services - Service layer classes
mv Sources/GameChanger/AppDataManager.swift Sources/GameChanger/Services/
mv Sources/GameChanger/ImageCache.swift Sources/GameChanger/Services/
mv Sources/GameChanger/SoundPlayer.swift Sources/GameChanger/Services/

# Extensions
mv Sources/GameChanger/Extensions.swift Sources/GameChanger/Extensions/

# Keep Resources folder at root level
mkdir -p Sources/GameChanger/Resources
# Resources are already in place

echo "File structure reorganized successfully!"
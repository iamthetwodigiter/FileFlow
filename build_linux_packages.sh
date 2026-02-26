#!/bin/bash

# FileFlow Linux Package Build Script
# Builds .deb and .appimage packages for Linux

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get app information from pubspec.yaml
APP_NAME="FileFlow"
VERSION=$(grep "^version:" pubspec.yaml | awk '{print $2}')
DESCRIPTION="P2P File Transfer App"
ICON_PATH="$(pwd)/icon.png"

echo -e "${GREEN}Building $APP_NAME v$VERSION${NC}"

# Check if icon exists
if [ ! -f "$ICON_PATH" ]; then
    echo -e "${RED}Error: icon.png not found in root directory${NC}"
    exit 1
fi

# Clean previous builds
echo -e "${YELLOW}Cleaning previous builds...${NC}"
flutter clean
rm -rf build/linux-packages

# Build Flutter Linux app
echo -e "${YELLOW}Building Flutter Linux application...${NC}"
flutter build linux --release

BUILD_DIR="build/linux/x64/release/bundle"
PACKAGES_DIR="build/linux-packages"
mkdir -p "$PACKAGES_DIR"

# Architecture mapping
ARCH_DEB="amd64"
ARCH_RPM="x86_64"
ARCH_APPIMAGE="x86_64"

# =======================
# Build .deb package
# =======================
echo -e "${GREEN}Building .deb package...${NC}"

DEB_DIR="$PACKAGES_DIR/deb"
# Naming format: FileFlow-v1.1.1-amd64.deb
DEB_NAME="FileFlow-v${VERSION}-${ARCH_DEB}"
DEB_BUILD_DIR="$DEB_DIR/$DEB_NAME"

mkdir -p "$DEB_BUILD_DIR/DEBIAN"
mkdir -p "$DEB_BUILD_DIR/usr/bin"
mkdir -p "$DEB_BUILD_DIR/usr/lib/fileflow"
mkdir -p "$DEB_BUILD_DIR/usr/share/applications"
mkdir -p "$DEB_BUILD_DIR/usr/share/icons/hicolor/256x256/apps"

# Copy application files
cp -r "$BUILD_DIR"/* "$DEB_BUILD_DIR/usr/lib/fileflow/"

# Create launcher script
cat > "$DEB_BUILD_DIR/usr/bin/fileflow" << 'EOF'
#!/bin/bash
cd /usr/lib/fileflow
exec ./fileflow "$@"
EOF
chmod +x "$DEB_BUILD_DIR/usr/bin/fileflow"

# Copy icon
cp "$ICON_PATH" "$DEB_BUILD_DIR/usr/share/icons/hicolor/256x256/apps/fileflow.png"

# Create .desktop file
cat > "$DEB_BUILD_DIR/usr/share/applications/fileflow.desktop" << EOF
[Desktop Entry]
Name=$APP_NAME
Comment=$DESCRIPTION
Exec=/usr/bin/fileflow
Icon=fileflow
Type=Application
Categories=Network;FileTransfer;Utility;
Terminal=false
StartupWMClass=fileflow
EOF

# Create control file
cat > "$DEB_BUILD_DIR/DEBIAN/control" << EOF
Package: fileflow
Version: $VERSION
Section: net
Priority: optional
Architecture: $ARCH_DEB
Maintainer: FileFlow Team
Description: $DESCRIPTION
 FileFlow is a peer-to-peer file transfer application
 that allows secure and fast file sharing between devices.
EOF

# Create postinst script
cat > "$DEB_BUILD_DIR/DEBIAN/postinst" << 'EOF'
#!/bin/bash
set -e
update-desktop-database || true
gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
EOF
chmod +x "$DEB_BUILD_DIR/DEBIAN/postinst"

# Build .deb package
dpkg-deb --build "$DEB_BUILD_DIR"
mv "$DEB_DIR/${DEB_NAME}.deb" "$PACKAGES_DIR/"
rm -rf "$DEB_BUILD_DIR"

echo -e "${GREEN}.deb package created: $PACKAGES_DIR/${DEB_NAME}.deb${NC}"

# =======================
# Build .rpm package (using alien)
# =======================
echo -e "${GREEN}Building .rpm package...${NC}"
if command -v alien &> /dev/null; then
    sudo alien --to-rpm "$PACKAGES_DIR/${DEB_NAME}.deb"
    RPM_FILE=$(ls fileflow-*.rpm | head -n 1)
    if [ -n "$RPM_FILE" ]; then
        mv "$RPM_FILE" "$PACKAGES_DIR/FileFlow-v${VERSION}-${ARCH_RPM}.rpm"
    fi
else
    echo -e "${YELLOW}Warning: alien not found, skipping .rpm build. Install with 'sudo apt install alien'${NC}"
fi

# =======================
# Build AppImage
# =======================
echo -e "${GREEN}Building AppImage...${NC}"

APPIMAGE_DIR="$PACKAGES_DIR/AppImage"
APPDIR="$APPIMAGE_DIR/FileFlow.AppDir"

mkdir -p "$APPDIR/usr/bin"
mkdir -p "$APPDIR/usr/lib"
mkdir -p "$APPDIR/usr/share/applications"
mkdir -p "$APPDIR/usr/share/icons/hicolor/256x256/apps"

# Copy application files
cp -r "$BUILD_DIR"/* "$APPDIR/usr/bin/"

# Copy icon
cp "$ICON_PATH" "$APPDIR/usr/share/icons/hicolor/256x256/apps/fileflow.png"
cp "$ICON_PATH" "$APPDIR/fileflow.png"
cp "$ICON_PATH" "$APPDIR/.DirIcon"

# Create .desktop file for AppImage
cat > "$APPDIR/fileflow.desktop" << EOF
[Desktop Entry]
Name=$APP_NAME
Comment=$DESCRIPTION
Exec=fileflow
Icon=fileflow
Type=Application
Categories=Network;FileTransfer;
Terminal=false
EOF

cp "$APPDIR/fileflow.desktop" "$APPDIR/usr/share/applications/"

# Create AppRun script
cat > "$APPDIR/AppRun" << 'EOF'
#!/bin/bash
SELF=$(readlink -f "$0")
HERE=${SELF%/*}
export PATH="${HERE}/usr/bin:${PATH}"
export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"
cd "${HERE}/usr/bin"
exec ./fileflow "$@"
EOF
chmod +x "$APPDIR/AppRun"

# Download appimagetool if not present (in project root)
APPIMAGETOOL="$(pwd)/appimagetool-x86_64.AppImage"
if [ ! -f "$APPIMAGETOOL" ]; then
    echo -e "${YELLOW}Downloading appimagetool...${NC}"
    curl -L "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" -o "$APPIMAGETOOL"
    chmod +x "$APPIMAGETOOL"
fi

# Build AppImage (using absolute paths)
OUTPUT_APPIMAGE="$(pwd)/$PACKAGES_DIR/FileFlow-v${VERSION}-${ARCH_APPIMAGE}.AppImage"
# We need to run it with --appimage-extract-and-run because we are inside a docker/CI environment often
ARCH=x86_64 "$APPIMAGETOOL" --appimage-extract-and-run "$APPDIR" "$OUTPUT_APPIMAGE"

echo -e "${GREEN}AppImage created: $OUTPUT_APPIMAGE${NC}"


# =======================
# Build .tar.gz bundle
# =======================
echo -e "${GREEN}Building .tar.gz bundle...${NC}"
TAR_NAME="FileFlow-v${VERSION}-linux-x64.tar.gz"
tar -czf "$PACKAGES_DIR/$TAR_NAME" -C "build/linux/x64/release" bundle
echo -e "${GREEN}.tar.gz bundle created: $PACKAGES_DIR/$TAR_NAME${NC}"

# =======================
# Summary
# =======================
echo -e "\n${GREEN}================================${NC}"
echo -e "${GREEN}Build completed successfully!${NC}"
echo -e "${GREEN}================================${NC}"
echo -e "\nPackages created in: ${YELLOW}$PACKAGES_DIR${NC}"
ls -lh "$PACKAGES_DIR"/*.deb "$PACKAGES_DIR"/*.AppImage "$PACKAGES_DIR"/*.rpm "$PACKAGES_DIR"/*.tar.gz 2>/dev/null || true
echo -e "\n${GREEN}Done!${NC}"



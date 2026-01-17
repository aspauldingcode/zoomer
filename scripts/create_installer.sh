#!/bin/bash

# Get the repository root directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

# Version - read from VERSION file
VERSION=$(cat "$REPO_ROOT/VERSION")
PKG_NAME="zoomer-${VERSION}.pkg"
CHANGELOG_FILE="$REPO_ROOT/CHANGELOG.md"
BUILD_FILE="$REPO_ROOT/build/libzoomer.dylib"

# Change to repository root
cd "$REPO_ROOT"

# Check if version already exists in CHANGELOG
if [ -f "$CHANGELOG_FILE" ] && grep -q "## \[${VERSION}\]" "$CHANGELOG_FILE"; then
    echo "Warning: Version ${VERSION} already exists in CHANGELOG"
    echo "Consider updating the VERSION file to a new version number"
    echo "Continuing with installer creation..."
fi

# Check if build exists, if not, run make
if [ ! -f "$BUILD_FILE" ]; then
    echo "Build not found. Running make..."
    if ! make; then
        echo "Error: Build failed"
        exit 1
    fi
fi

# Create temporary directory structure
TEMP_DIR="$(mktemp -d)"
PAYLOAD_DIR="$TEMP_DIR/payload"
SCRIPTS_DIR="$TEMP_DIR/scripts"

mkdir -p "$PAYLOAD_DIR/var/ammonia/core/tweaks"
mkdir -p "$SCRIPTS_DIR"

# Copy files to payload
if ! cp "$BUILD_FILE" "$PAYLOAD_DIR/var/ammonia/core/tweaks/"; then
    echo "Error: Failed to copy dylib"
    rm -rf "$TEMP_DIR"
    exit 1
fi

if ! cp libzoomer.dylib.blacklist "$PAYLOAD_DIR/var/ammonia/core/tweaks/"; then
    echo "Error: Failed to copy blacklist"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Create postinstall script
cat > "$SCRIPTS_DIR/postinstall" << 'EOF'
#!/bin/bash

# Restart Ammonia service (script runs as root in pkg context; sudo not required)
sleep 2
launchctl bootout system /Library/LaunchDaemons/com.bedtime.ammonia.plist 2>/dev/null || true
sleep 2
launchctl bootstrap system /Library/LaunchDaemons/com.bedtime.ammonia.plist

exit 0
EOF

chmod +x "$SCRIPTS_DIR/postinstall"

# Build package
pkgbuild --root "$PAYLOAD_DIR" \
         --scripts "$SCRIPTS_DIR" \
         --identifier com.aspauldingcode.zoomer \
         --version "$VERSION" \
         --install-location "/" \
         "$PKG_NAME"

# Check if package was created successfully
if [ $? -eq 0 ] && [ -f "$PKG_NAME" ]; then
    # Clean up temp directory
    rm -rf "$TEMP_DIR"

    echo "Created installer package: $REPO_ROOT/$PKG_NAME"
    echo "Version $VERSION packaged successfully"
    echo "Note: Update CHANGELOG.md manually to document this release"
else
    # Clean up on failure
    rm -rf "$TEMP_DIR"
    [ -f "$PKG_NAME" ] && rm "$PKG_NAME"
    echo "Error: Failed to create installer package"
    exit 1
fi
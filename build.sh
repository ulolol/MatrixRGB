#!/bin/bash

##############################################################################
# Build Script for Matrix Digital Rain - Rainbow Edition (Go Implementation)
# Compiles the Go implementation for multiple platforms
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
BUILD_DIR="build"
VERSION="${1:-1.0.0}"
VERBOSE=false

# Supported platforms
declare -A PLATFORMS=(
    [linux/amd64]="matrix-rain-linux-x86_64"
    [linux/arm64]="matrix-rain-linux-arm64"
    [linux/arm]="matrix-rain-linux-arm32"
)

print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Matrix Digital Rain - Build Script${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

show_help() {
    cat << 'EOF'
Usage: ./build.sh [VERSION] [OPTIONS]

Arguments:
  VERSION         Version string (default: 1.0.0)

Options:
  -h, --help      Show this help message
  -v, --verbose   Enable verbose build output
  -c, --clean     Clean build directory before building

Examples:
  ./build.sh                      # Build with default version
  ./build.sh 2.0.0               # Build with version 2.0.0
  ./build.sh 2.0.0 -v            # Build with verbose output
  ./build.sh 2.0.0 --clean       # Clean and build
EOF
}

# Parse additional arguments
CLEAN_BUILD=false
for arg in "$@"; do
    case $arg in
        -h|--help)
            show_help
            exit 0
            ;;
        -v|--verbose)
            VERBOSE=true
            ;;
        -c|--clean)
            CLEAN_BUILD=true
            ;;
    esac
done

print_header

# Check if Go is installed
if ! command -v go &> /dev/null; then
    print_error "Go is not installed. Please install Go 1.16 or later."
    exit 1
fi

GO_VERSION=$(go version | awk '{print $3}')
print_info "Found Go version: $GO_VERSION"

# Get current directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

# Create or clean build directory
if [ -d "$BUILD_DIR" ]; then
    if [ "$CLEAN_BUILD" = true ]; then
        print_info "Cleaning build directory..."
        rm -rf "$BUILD_DIR"
    fi
fi

mkdir -p "$BUILD_DIR"
print_success "Build directory ready: $BUILD_DIR"

# Build for each platform
echo ""
print_info "Starting builds..."
echo ""

BUILD_COUNT=0
FAILED_BUILDS=0

for platform in "${!PLATFORMS[@]}"; do
    IFS='/' read -r OS ARCH <<< "$platform"
    OUTPUT_NAME="${PLATFORMS[$platform]}"
    OUTPUT_PATH="$BUILD_DIR/$OUTPUT_NAME"

    print_info "Building for $platform..."

    # Set build variables
    BUILD_CMD="GOOS=$OS GOARCH=$ARCH"
    if [ "$ARCH" = "arm" ]; then
        BUILD_CMD="$BUILD_CMD GOARM=7"
    fi
    BUILD_CMD="$BUILD_CMD go build -o $OUTPUT_PATH"

    # Add verbose flags if requested
    if [ "$VERBOSE" = true ]; then
        BUILD_CMD="$BUILD_CMD -v"
    fi

    # Execute build
    if eval "$BUILD_CMD" 2>&1; then
        SIZE=$(du -h "$OUTPUT_PATH" | cut -f1)
        print_success "Built: $OUTPUT_NAME ($SIZE)"
        ((BUILD_COUNT++))
    else
        print_error "Failed to build: $OUTPUT_NAME"
        ((FAILED_BUILDS++))
    fi
done

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo "Build Summary:"
echo -e "  ${GREEN}Successful: $BUILD_COUNT${NC}"
if [ "$FAILED_BUILDS" -gt 0 ]; then
    echo -e "  ${RED}Failed: $FAILED_BUILDS${NC}"
fi
echo -e "${BLUE}========================================${NC}"

# List generated binaries
echo ""
print_info "Generated binaries:"
echo ""
if [ -d "$BUILD_DIR" ] && [ "$(ls -A $BUILD_DIR 2>/dev/null)" ]; then
    ls -lh "$BUILD_DIR" | tail -n +2 | awk '{print "  " $9 " (" $5 ")"}'
    echo ""
    print_success "All binaries are ready in: $BUILD_DIR/"
else
    print_error "No binaries were generated"
    exit 1
fi

# Exit with failure if any builds failed
if [ "$FAILED_BUILDS" -gt 0 ]; then
    exit 1
fi

print_success "Build completed successfully!"
echo ""
print_info "Next steps:"
echo "  1. Copy the appropriate binary to your target system"
echo "  2. Make it executable: chmod +x matrix-rain-*"
echo "  3. Run it: ./matrix-rain-linux-x86_64 [options]"
echo ""

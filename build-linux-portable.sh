#!/bin/bash

# Build script for creating a portable Linux binary
set -e

echo "Building portable Linux binary for lyretune..."

# Clean previous builds
cargo clean

# Build with release optimizations
cargo build --release

# Create distribution directory
mkdir -p dist/lyretune-linux

# Copy the binary
cp target/release/lyretune dist/lyretune-linux/

# Create a README for dependencies
cat > dist/lyretune-linux/README.txt << EOF
Lyretune - Linux Binary

This binary requires the following system libraries:
- libasound.so.2 (ALSA sound library)
- Standard C library (glibc)

To install dependencies on Debian/Ubuntu:
  sudo apt-get install libasound2

To install dependencies on Fedora/RHEL:
  sudo dnf install alsa-lib

To install dependencies on Arch:
  sudo pacman -S alsa-lib

To run:
  ./lyretune
EOF

# Make the binary executable
chmod +x dist/lyretune-linux/lyretune

# Create a tarball
cd dist
tar -czf lyretune-linux-x86_64.tar.gz lyretune-linux/
cd ..

echo "Build complete! Binary package created at: dist/lyretune-linux-x86_64.tar.gz"
echo "Binary location: dist/lyretune-linux/lyretune"
echo ""
echo "The binary depends on ALSA (libasound.so.2) which is commonly available on most Linux systems."
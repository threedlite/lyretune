#!/bin/bash

# Script to prepare LyreTune for deployment

echo "Preparing LyreTune for deployment..."

# Create deployment directory
mkdir -p deployment

# Copy the binary
cp target/release/lyretune deployment/

# Strip the binary to reduce size
strip deployment/lyretune

# Check file size
echo "Binary size:"
ls -lh deployment/lyretune

# Create a run script
cat > deployment/run_lyretune.sh << 'EOF'
#!/bin/bash
# LyreTune launcher script

# Check if ALSA is available
if ! command -v aplay &> /dev/null; then
    echo "Warning: ALSA tools not found. Audio might not work."
    echo "Please install ALSA: sudo apt-get install alsa-utils libasound2"
fi

# Run LyreTune
./lyretune "$@"
EOF

chmod +x deployment/run_lyretune.sh

# Create README for deployment
cat > deployment/README.txt << 'EOF'
LyreTune - Ancient Greek Lyre Tuner
====================================

Requirements:
- Linux x86_64
- ALSA sound system (libasound2)
- Microphone access

To run:
  ./run_lyretune.sh

If you get audio errors, install ALSA:
  Ubuntu/Debian: sudo apt-get install libasound2
  Fedora/RHEL:  sudo dnf install alsa-lib
  Arch:         sudo pacman -S alsa-lib

The application will request microphone permissions when started.
EOF

echo "Deployment package ready in ./deployment/"
echo "Contents:"
ls -la deployment/
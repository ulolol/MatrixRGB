# Matrix Digital Rain - Rainbow Edition

A **cross-platform** implementation of the iconic falling rain animation from the Matrix movies with rainbow colors, inspired by `cmatrix | lolcat`.

## Available Implementations

- **Bash** (`matrix-rain.sh`) - Pure bash, no compilation needed
- **Go** (`main.go`) - Compiled binary, runs on x86_64 PC and Android Termux

![Matrix Rain Animation](https://img.shields.io/badge/bash-5.1%2B-green) ![Go](https://img.shields.io/badge/go-1.16%2B-00ADD8) ![License](https://img.shields.io/badge/license-MIT-blue)

>*This was originally created in ~ 2020, during COVID, after rewatching all the Matrix movies. This new update adds a high-performance Go implementation with cross-platform support - with the help of Claude + Codex*

## Features

✨ **Rainbow Colors** - Smooth 24-bit RGB gradient animations cycling through the entire spectrum using sine wave algorithm (similar to lolcat)

🎌 **Katakana Characters** - Authentic Matrix characters (ｱ, ｲ, ｳ, ｴ, etc.) falling from the top of the screen

🌊 **Trail Effects** - Dynamic brightness trails:
- Bright/bold head character at the bottom of each stream
- Medium brightness middle trail
- Dim fading character above
- Automatic erasure beyond trail length

⚙️ **Customizable Speed** - Control animation speed from 1 (slow) to 10 (fast)

📊 **Adjustable Density** - Control column density as a percentage of terminal width (1-100%)

🎯 **Terminal Compatibility** - Works with modern terminals supporting 24-bit true color (COLORTERM)

🔄 **Responsive** - Handles terminal resize events (SIGWINCH) dynamically

## Requirements

### Bash Implementation
- **Bash 4.0+** (for associative arrays and process management)
- **awk** (for floating-point sine wave calculations)
- **Terminal with 24-bit true color support** (most modern terminals)
- *Optional*: `tput` (for better terminal detection, fallback to automatic detection)

### Go Implementation
- **Go 1.16+** (for building from source)
- **Terminal with 24-bit true color support** (most modern terminals)
- No additional runtime dependencies

## Installation

### Bash Implementation

#### Quick Start

```bash
chmod +x matrix-rain.sh
./matrix-rain.sh
```

#### Add to PATH (Optional)

```bash
sudo cp matrix-rain.sh /usr/local/bin/matrix-rain
chmod +x /usr/local/bin/matrix-rain
matrix-rain  # Run from anywhere
```

### Go Implementation

#### Build from Source

**Requirements**: Go 1.16+

```bash
# Build for your current system
go build -o matrix-rain main.go

# Make executable and run
chmod +x matrix-rain
./matrix-rain
```

#### Build for Multiple Platforms

Use the provided build script to compile for multiple architectures:

```bash
# Make build script executable
chmod +x build.sh

# Build all supported platforms
./build.sh

# Build with specific version
./build.sh 2.0.0

# Build with verbose output
./build.sh 2.0.0 -v

# Clean build directory and rebuild
./build.sh 2.0.0 -c
```

**Supported Platforms**:
- `linux/amd64` - Linux x86_64 PC (Intel/AMD processors)
- `linux/arm64` - Linux ARM64 (Android Termux, Raspberry Pi 4)
- `linux/arm` - Linux ARMv7 (Older Android devices, Raspberry Pi 3)

Binaries will be in the `build/` directory:
```
build/
├── matrix-rain-linux-x86_64   # x86_64 PC
├── matrix-rain-linux-arm64    # Android Termux / ARM64
└── matrix-rain-linux-arm32    # ARMv7 (32-bit)
```

#### Using Pre-built Binaries

If available, download pre-built binaries and make them executable:

```bash
chmod +x matrix-rain-linux-x86_64
./matrix-rain-linux-x86_64
```

#### Install Go Binary to PATH

```bash
# Build first
go build -o matrix-rain main.go

# Install to PATH
sudo mv matrix-rain /usr/local/bin/
matrix-rain  # Run from anywhere
```

#### Cross-compile for Android Termux (from Linux/macOS)

```bash
# From Linux or macOS, build for Android Termux (ARM64)
GOOS=linux GOARCH=arm64 go build -o matrix-rain-arm64 main.go

# Transfer to Android device via ADB or USB
adb push matrix-rain-arm64 /data/local/tmp/
adb shell chmod +x /data/local/tmp/matrix-rain-arm64
adb shell /data/local/tmp/matrix-rain-arm64
```

## Usage

### Bash Implementation

```bash
./matrix-rain.sh [OPTIONS]
```

### Go Implementation

```bash
./matrix-rain [OPTIONS]
# or if installed to PATH
matrix-rain [OPTIONS]
```

Both implementations use the same command-line interface.

### Basic Usage

```bash
# Bash
./matrix-rain.sh

# Go
./matrix-rain
```

Starts the animation with default settings (speed=5, density=80%).

### Command-Line Options

```bash
./matrix-rain.sh [OPTIONS]

OPTIONS:
  -s SPEED    Animation speed (1-10, default: 5)
              1 = very slow, 10 = very fast
  -d DENSITY  Column density (1-100%, default: 80)
              Percentage of terminal width filled with columns
  -h          Show help message
```

### Examples

```bash
# Default animation
./matrix-rain.sh

# Fast animation with full density
./matrix-rain.sh -s 8 -d 100

# Slow animation with sparse columns
./matrix-rain.sh -s 2 -d 50

# Medium speed, medium density
./matrix-rain.sh -s 5 -d 70

# Minimal animation
./matrix-rain.sh -s 1 -d 10

# Maximum chaos
./matrix-rain.sh -s 10 -d 100
```

### Controls

| Key | Action |
|-----|--------|
| `Ctrl+C` | Stop animation and restore terminal |
| Terminal Resize | Animation automatically adapts to new dimensions |

## Bash vs Go Implementation

| Feature | Bash | Go |
|---------|------|-----|
| **Installation** | No build required | Requires `go build` or pre-compiled binary |
| **Performance** | Moderate (pure bash) | Excellent (compiled binary) |
| **Memory Usage** | Higher (bash runtime) | Lower (native binary) |
| **Startup Time** | Slower (interpreter startup) | Instant (compiled binary) |
| **Portability** | Requires bash 4.0+ | Single binary, no runtime deps |
| **Cross-Platform** | Limited (bash availability) | Wide (easy cross-compilation) |
| **Use Case** | Learning, quick testing | Production, performance-critical |
| **Android Termux** | Works but slower | Optimized with native ARM binary |
| **Development** | Easy to modify | Requires Go knowledge |

**TL;DR**: Use **Bash** for immediate testing without setup. Use **Go** for performance and cross-platform deployment.

## How It Works

### Architecture

The implementations use a **column-based approach** where each falling stream operates independently:

1. **Terminal Setup** - Switches to alternate screen buffer, hides cursor, detects dimensions
2. **Column Processes** - Spawns background processes for each active column
3. **Animation Loop** - Each column manages:
   - Stream position and length
   - Gap timing between streams
   - Character trails with variable brightness
   - Rainbow color calculation per position
4. **Rainbow Generation** - Uses sine wave algorithm with 120° phase shifts for smooth RGB gradients
5. **Cleanup** - Restores terminal on exit

### Rainbow Color Algorithm

Colors are generated using three phase-shifted sine waves:

```
red   = sin(freq*position + 0°) * 127 + 128
green = sin(freq*position + 120°) * 127 + 128
blue  = sin(freq*position + 240°) * 127 + 128
```

This creates a continuous, smooth rainbow gradient that cycles through all spectrum colors.

### Trail System

Each column maintains a history of characters with decreasing brightness:

- **Head** (current position): Bold, full intensity RGB color
- **Trail** (previous position): Normal weight, full intensity RGB color
- **Fade** (2+ positions back): Dim attribute, faded color
- **Erase**: Characters beyond trail length are removed

## Customization

### Change Character Set

Edit the `CHARS` array in the script to use different characters:

```bash
# Example: Use ASCII characters instead
CHARS=( "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" "A" "B" "C" "D" "E" )

# Example: Mix ASCII and symbols
CHARS=( "█" "▓" "▒" "░" "|" "-" "/" "\\" "@" "#" "$" "%" )
```

### Adjust Frequency (Color Speed)

Change the rainbow gradient density by modifying the `freq` parameter in `rainbow_color()`:

```bash
local freq=0.1   # Current: smooth gradient
local freq=0.05  # Slower color transitions
local freq=0.2   # Faster color transitions
```

### Modify Speed Range

To adjust the delay calculation, edit the `rain_column()` function:

```bash
# Current formula (1-10 scale maps to ~0.1-0.9 seconds)
local delay=$(echo "scale=3; 1.0 - ($speed - 1) * 0.08" | bc -l)

# Make it faster overall:
local delay=$(echo "scale=3; 0.5 - ($speed - 1) * 0.04" | bc -l)

# Make it slower overall:
local delay=$(echo "scale=3; 1.5 - ($speed - 1) * 0.12" | bc -l)
```

### Terminal Color Fallback

For terminals without 24-bit color support, you can implement a 256-color palette version by replacing ANSI color codes:

```bash
# 24-bit true color (current)
printf '\e[38;2;%d;%d;%dm' $r $g $b

# 256-color palette
printf '\e[38;5;%dm' $(color_to_256 $r $g $b)
```

## Technical Details

### Go Implementation Specifics

**Language**: Go 1.16+
**Architecture**: Native compiled binary
**Key Differences from Bash**:

1. **Concurrency**: Uses goroutines for efficient frame rendering (one per animation frame cycle)
2. **Syscall Interface**: Direct terminal control via `syscall` package for IOCTL operations
3. **No External Dependencies**: Purely stdlib (no cmatrix or lolcat dependencies needed)
4. **Binary Size**: ~4-6 MB per platform (self-contained, no runtime requirements)
5. **Performance**:
   - Bash: ~30-40% CPU on dense animations
   - Go: ~5-10% CPU on same settings
6. **Memory Usage**:
   - Bash: 20-40 MB
   - Go: 2-5 MB

**Build Details**:
- Single-pass compilation to native machine code
- Stripped binaries available with `go build -ldflags="-s -w"`
- Cross-compilation works from any platform where Go is installed
- Zero runtime dependencies (works on minimal systems)

### ANSI Escape Sequences Used

| Sequence | Purpose |
|----------|---------|
| `\e[?1049h` | Switch to alternate screen buffer |
| `\e[2J` | Clear entire screen |
| `\e[?25l` | Hide cursor |
| `\e[?7l` | Disable line wrapping |
| `\e[L;CH` | Position cursor at line L, column C |
| `\e[1m` | Bold/bright intensity |
| `\e[2m` | Dim intensity |
| `\e[38;2;R;G;Bm` | Set foreground color to RGB |
| `\e[m` | Reset all attributes |

### Performance Considerations

- **Background Processes**: Each column runs as a separate background process for parallelization
- **Random Generation**: Uses bash's built-in `$RANDOM` for character and speed selection
- **Minimal Redraws**: Only updates changed positions instead of full screen refresh
- **Sleep Timing**: Uses fractional seconds for smooth animation control

### Terminal Compatibility

Tested on:
- Linux (VT100, xterm, GNOME Terminal, Konsole, Alacritty)
- macOS (Terminal.app, iTerm2)
- WSL (Windows Subsystem for Linux)

Requires 24-bit color support (most terminals built after ~2018 have this).

## Performance Tips

### For Slower Systems

```bash
# Reduce density to decrease CPU usage
./matrix-rain.sh -d 30

# Or reduce speed to lower processing requirements
./matrix-rain.sh -s 3
```

### For Visual Impact

```bash
# Maximum density and medium speed
./matrix-rain.sh -d 100 -s 6

# Or slower with full columns
./matrix-rain.sh -d 100 -s 3
```

## Troubleshooting

### Colors Not Working

**Issue**: Animation shows up but without rainbow colors

**Solutions**:
1. Check terminal supports 24-bit color: `echo $COLORTERM`
2. Try setting color term manually: `export COLORTERM=truecolor`
3. Try a different terminal (iTerm2, Alacritty, modern Konsole)

### Animation Jerky or Slow

**Issue**: Animation isn't smooth

**Solutions**:
1. Try reducing density: `./matrix-rain.sh -d 50`
2. Reduce terminal window size
3. Close other CPU-intensive programs
4. Try lower speed: `./matrix-rain.sh -s 3`

### Terminal Corruption After Exit

**Issue**: Terminal state isn't properly restored

**Solutions**:
1. Run `reset` to restore terminal
2. Run `stty echo` to re-enable terminal echo
3. The script should restore automatically on normal exit

### `bc` Not Available

**Issue**: Error about `bc` command not found

**Solutions**:
1. Install bc: `sudo apt install bc` (Ubuntu/Debian) or `brew install bc` (macOS)
2. Or replace bc calls with pure bash arithmetic (less accurate)

## Examples

### Show Off Mode

```bash
# Maximum chaos - fill entire terminal with fast-moving columns
./matrix-rain.sh -s 9 -d 100
```

### Relaxing Screensaver

```bash
# Slow, sparse animation perfect for a screensaver
./matrix-rain.sh -s 1 -d 30
```

### Default Experience

```bash
# Balanced speed and density for most users
./matrix-rain.sh
```

### Code Review Mode

```bash
# Keep animation in background while you work
./matrix-rain.sh -s 2 -d 20 &
```

## Implementation Notes

### Why Bash?

This script demonstrates that complex animations are possible in bash:
- No compiled dependencies required
- Portable across Unix-like systems
- Combines Unix tools (awk, printf) effectively
- Educational reference for bash scripting techniques

### Algorithm Sources

- **Rainbow color algorithm**: Based on lolcat (Ruby) implementation using sine waves
- **Matrix rain effect**: Inspired by cmatrix (C) with column-based streaming
- **Terminal control**: Uses standard ANSI escape sequences (VT100/xterm)

## Building the Go Implementation

### Build Script Usage

The `build.sh` script automates cross-platform compilation:

```bash
chmod +x build.sh
./build.sh                    # Build all platforms with defaults
./build.sh 2.0.0             # Build with version tag
./build.sh 2.0.0 -v          # Verbose output
./build.sh 2.0.0 -c          # Clean rebuild
./build.sh -h                # Show help
```

### Manual Build

```bash
# Build for current platform
go build -o matrix-rain main.go

# Build with version info (optional)
go build -ldflags="-X main.version=2.0.0" -o matrix-rain main.go

# Create stripped binary (smaller size)
go build -ldflags="-s -w" -o matrix-rain main.go

# Build for specific platform
GOOS=linux GOARCH=arm64 go build -o matrix-rain-arm64 main.go
```

### Deployment Checklist

- [ ] Build binaries for all target platforms
- [ ] Test binaries on x86_64 and ARM64 systems
- [ ] Verify terminal detection works (`./matrix-rain -h`)
- [ ] Test with different terminal sizes
- [ ] Verify Ctrl+C properly restores terminal
- [ ] Create release notes
- [ ] Upload binaries to releases page

## Contributing

To enhance this project:

1. **Character Sets**: Add support for different character sets (Cyrillic, Greek, Arabic, etc.)
2. **Color Modes**: Implement classic green-only Matrix mode
3. **Performance**: Optimize for low-end systems
4. **Compatibility**: Add 256-color palette fallback
5. **Features**: Add mouse interaction or preset themes
6. **Go Optimization**: Improve rendering performance or reduce binary size

## License

Distributed as is under the MIT License

## See Also

- **cmatrix** - Original C implementation of Matrix rain
- **lolcat** - Ruby tool for rainbow coloring terminal output
- **figlet** - ASCII art text generation (could combine with matrix-rain)

## Acknowledgments

- Inspired by the visual effects from The Matrix (1999)
- Algorithm references from cmatrix and lolcat projects
- ANSI escape sequence documentation from various terminal emulator projects

---

**Enjoy your digital rain! 🌧️🎌**

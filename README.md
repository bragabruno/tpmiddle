# TPMiddle for macOS

A macOS port of the TPMiddle TrackPoint middle button scroll utility.

## Project Status

- [x] Core Architecture
  - [x] Component-based design
  - [x] Event handling system
  - [x] Configuration management
  - [x] Device monitoring

- [x] Basic Features
  - [x] Middle button detection
  - [x] Scroll event generation
  - [x] Status bar integration
  - [x] Settings persistence

- [x] Advanced Features
  - [x] Configurable scroll speed
  - [x] Acceleration control
  - [x] Natural scrolling
  - [x] Direction inversion

- [ ] Testing Phase
  - [ ] Hardware compatibility
  - [ ] Application support
  - [ ] Performance testing
  - [ ] Error handling

- [ ] Distribution
  - [ ] Code signing
  - [ ] Notarization
  - [ ] Installation package
  - [ ] Update system

## Documentation

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - System design and components
- [FEATURES.md](docs/FEATURES.md) - Feature implementation status
- [TESTING.md](docs/TESTING.md) - Testing plans and status
- [BUILD.md](docs/BUILD.md) - Build system and distribution

## Quick Start

### Building from Source

```bash
# Clone the repository
git clone [repository-url]

# Build the application
cd tpmiddle
make

# Install to Applications folder
make install
```

### Configuration

1. Launch TPMiddle.app
2. Click the status bar icon (○/●)
3. Configure settings:
   - Scroll speed
   - Acceleration
   - Natural scrolling
   - Direction controls

## Requirements

- macOS 10.12 or later
- Lenovo TrackPoint device
- Input Monitoring permissions
- Accessibility permissions

## Contributing

See individual documentation files for specific areas:
- Architecture changes: [ARCHITECTURE.md](docs/ARCHITECTURE.md)
- Feature development: [FEATURES.md](docs/FEATURES.md)
- Testing: [TESTING.md](docs/TESTING.md)
- Build system: [BUILD.md](docs/BUILD.md)

## Original Project

TPMiddle is a port of the Windows version (0.7.0.0, 2011-2015) by:
- Marek Wróbel
- Gerhard Wiesinger

## License

[License information to be added]

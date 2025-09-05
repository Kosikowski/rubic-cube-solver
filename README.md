# RubicCube

A 3D Rubik's Cube simulator and solver built with SwiftUI and Metal for iOS and macOS.

![RubicCube Screenshot](docs/screenshot.png)

## Features

- **3D Visualization**: Real-time 3D rendering using Metal shaders
- **Interactive Controls**: Manual cube manipulation with standard notation (U, R, L, F, B, D, H, V)
- **Scrambling**: Random cube scrambling with configurable move count
- **Smooth Animations**: Fluid rotation animations for all cube moves
- **Cross-Platform**: Supports both iOS 17+ and macOS 15+

## Architecture

The project follows a clean architecture pattern with three main components:

```
┌──────────────────┐      ┌──────────────────┐      ┌───────────────────┐
│  Solver Module   │───►──│  Animation Queue │───►──│    Renderer       │
│  (CPU – Swift)   │      │  (Swift)         │      │  (GPU – Metal)    │
└──────────────────┘      └──────────────────┘      └───────────────────┘
         ▲                          ▲                         ▲
         │                          │                         │
         │                          └─── Model (CubeState) ───┘
         │                                       │
         └────────── User Input/UI ──────────────┘
```

### Core Components

- **Solver Module**: Handles cube state manipulation and move application
- **Animation Queue**: Manages smooth transitions between cube states
- **Metal Renderer**: GPU-accelerated 3D rendering with custom shaders
- **SwiftUI Interface**: Modern, responsive user interface

## Requirements

- iOS 17.0+ / macOS 15.0+
- Xcode 15.0+
- Swift 6.1+

## Installation

### Swift Package Manager

Add the following to your `Package.swift` file:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/RubicCube.git", from: "1.0.0")
]
```

### Manual Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/RubicCube.git
```

2. Open `RubicCube.xcworkspace` in Xcode
3. Build and run the project

## Usage

### Basic Controls

- **U, R, L, F, B, D**: Standard Rubik's cube face rotations
- **H, V**: Horizontal and vertical middle layer rotations
- **Scramble**: Randomly scrambles the cube with 20 moves
- **Reset**: Returns the cube to solved state

### Integration

To use RubicCube in your own project:

```swift
import SwiftUI
import RubicCubeSolver

struct MyView: View {
    var body: some View {
        ContentView()
    }
}
```

## Project Structure

```
Sources/RubicCubeSolver/
├── Animators/           # Animation system
├── Helpers/            # Utility functions
├── Shaders/            # Metal shader files
├── Solver/             # Core cube logic
│   ├── Model/          # Data structures
│   └── RubicCubeSolver.swift
└── View/               # SwiftUI components
```

## Technical Details

### Cube Representation

The cube is represented as a 3x3x3 grid of 27 cubies, each containing:
- Position and orientation transforms
- Face color information
- Original position tracking

### Move System

Moves are defined by:
- **Axis**: X, Y, or Z rotation axis
- **Layer**: Which layer to rotate (0-2)
- **Direction**: Clockwise or counter-clockwise

### Rendering Pipeline

1. **CPU**: Move calculation and state updates
2. **Animation**: Smooth interpolation between states
3. **GPU**: Metal shader-based 3D rendering

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

**Mateusz Kosikowski**

- GitHub: [@yourusername](https://github.com/yourusername)

## Acknowledgments

- Built with SwiftUI and Metal
- Inspired by classic Rubik's Cube mechanics
- Thanks to the Swift community for excellent documentation and examples

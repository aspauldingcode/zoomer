# Zoomer

**Zoomer** is a macOS tweak that replaces the native "Fullscreen" (Green Button) behavior with a "Zoom to Display" action. Maximize as it should be!

![License](https://img.shields.io/badge/license-MIT-blue.svg)

![Zoomer in action](./zoomer.gif)

## Installation

```bash
make install
```

## Usage

Simply click the green button on any standard macOS window to zoom to display size. Click again to return to original size before zoom.

To enter native Fullscreen, hold the **Option (CMD)** key and click the green button.

## Uninstall

```bash
make uninstall
```

## Requirements

- macOS (tested on Tahoe)
- [Ammonia](https://github.com/CoreBedtime/ammonia) injection system installed (requires SIP disabled)

### System Security Settings

For Ammonia injection to work, System Integrity Protection (SIP) must be disabled.

## How It Works

- **_zoomButtonIsFullScreenButton**: Swizzled to return `NO` (Zoom) unless Option is held.
- **zoom:**: Swizzled to maximize window width to the screen's visible frame.

## License

Licensed under the [MIT License](./LICENSE).

## Acknowledgments

- [Ammonia](https://github.com/CoreBedtime/ammonia) for the injection framework
- [ZKSwizzle](https://github.com/alexzielenski/ZKSwizzle) for the swizzling implementation

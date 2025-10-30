# Assets Folder

This folder contains app assets like images and icons.

## Structure

- `images/` - App images, logos, etc.
- `icons/` - App icons and custom icon files

## Usage

Reference assets in your code:

```dart
Image.asset('assets/images/logo.png')
```

Or in pubspec.yaml:

```yaml
flutter:
  assets:
    - assets/images/
    - assets/icons/
```

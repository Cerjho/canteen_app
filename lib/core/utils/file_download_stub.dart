/// Stub implementation for non-web platforms
/// This function is not supported on mobile platforms
void downloadFile(List<int> bytes, String fileName, String mimeType) {
  throw UnsupportedError(
    'File download is only supported on web platform. '
    'On mobile, use share functionality or save to device storage instead.',
  );
}

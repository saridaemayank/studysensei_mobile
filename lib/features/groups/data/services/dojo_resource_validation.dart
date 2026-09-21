class DojoResourceValidation {
  static const int maxSizeBytes = 25 * 1024 * 1024;

  static const Set<String> supportedExtensions = {
    'pdf',
    'doc',
    'docx',
    'ppt',
    'pptx',
    'jpg',
    'jpeg',
    'png',
    'webp',
  };

  static const Map<String, String> mimeByExtension = {
    'pdf': 'application/pdf',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'ppt': 'application/vnd.ms-powerpoint',
    'pptx':
        'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'png': 'image/png',
    'webp': 'image/webp',
  };

  static String extensionFor(String fileName) {
    final sanitized = fileName.trim().toLowerCase();
    final dot = sanitized.lastIndexOf('.');
    if (dot < 0 || dot == sanitized.length - 1) return '';
    return sanitized.substring(dot + 1);
  }

  static String canonicalMimeType(String fileName) {
    return mimeByExtension[extensionFor(fileName)] ??
        'application/octet-stream';
  }

  static String mimeTypeFor(String fileName, String? reportedMimeType) {
    return reportedMimeType?.trim().isNotEmpty == true
        ? reportedMimeType!.trim()
        : canonicalMimeType(fileName);
  }

  static String storagePath({
    required String dojoId,
    required String resourceId,
    required String fileName,
  }) {
    return 'dojos/$dojoId/resources/$resourceId/${sanitizeFileName(fileName)}';
  }

  static bool isSupported(String fileName, String? reportedMimeType) {
    final extension = extensionFor(fileName);
    if (!supportedExtensions.contains(extension)) return false;

    final mimeType = reportedMimeType?.toLowerCase();
    if (mimeType == null || mimeType.trim().isEmpty) return true;
    if (mimeTypeByFamily(extension).contains(mimeType)) return true;
    return mimeByExtension[extension] == mimeType;
  }

  static Set<String> mimeTypeByFamily(String extension) => switch (extension) {
        'jpg' || 'jpeg' => {'image/jpeg'},
        'png' => {'image/png'},
        'webp' => {'image/webp'},
        'pdf' => {'application/pdf'},
        'doc' => {'application/msword', 'application/octet-stream'},
        'docx' => {
            'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'application/zip',
            'application/octet-stream',
          },
        'ppt' => {'application/vnd.ms-powerpoint', 'application/octet-stream'},
        'pptx' => {
            'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            'application/zip',
            'application/octet-stream',
          },
        _ => const <String>{},
      };

  static String sanitizeFileName(String fileName) {
    final trimmed = fileName.trim().isEmpty ? 'resource' : fileName.trim();
    final cleaned = trimmed
        .replaceAll(RegExp(r'[\\/:*?"<>|#%\{\}\[\]^~`]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
    final collapsed = cleaned
        .replaceAll(RegExp(r'_+'), '_')
        .replaceFirst(RegExp(r'^\.+'), '');
    final safeName = collapsed.trim().isEmpty ? 'resource' : collapsed;
    return safeName.length <= 96 ? safeName : safeName.substring(0, 96);
  }

  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(kb >= 10 ? 0 : 1)} KB';
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(mb >= 10 ? 0 : 1)} MB';
  }
}

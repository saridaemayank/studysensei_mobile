# Study Sensei

Cross-platform productivity platform built with Flutter. The codebase now
targets Android, iOS, desktop, and Flutter Web so the same experience can be
deployed to Firebase Hosting.

## Prerequisites

- Flutter 3.35.x with web support enabled (`flutter config --enable-web`)
- Firebase CLI (used for hosting deployments)
- A configured Firebase project (`study-sensei-53462`) with Hosting enabled

## Local Development

```bash
flutter pub get
flutter run -d chrome # any supported device target works
```

## Building & Releasing The Web App

1. Build the optimized Flutter Web bundle:
   ```bash
   flutter build web --release --web-renderer canvaskit
   ```
2. Copy (or move) `build/web` into `public/`. The Firebase Hosting config in
   `firebase.json` points at this directory.
3. Deploy to Firebase Hosting:
   ```bash
   firebase deploy --only hosting:studysensei-main
   ```

After deployment the latest web build is available at
https://studysensei-main.web.app (or the custom domain mapped in Firebase).

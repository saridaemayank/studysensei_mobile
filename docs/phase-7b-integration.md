# Phase 7B — Doubt API integration

## Flow

Doubt camera/gallery → centralized image preparation → Select Area → Help Type → Doubt Processing → typed response → temporary Phase 8 preview.

The selector remains underneath Processing. Back restores the same prepared image and normalized region. Existing Help Type request-return behavior is retained. Explain video services and all approved screen designs are unchanged.

## Endpoint and request

POST `https://us-central1-study-sensei-53462.cloudfunctions.net/api/sensei/doubt`

This is the Firebase `api` function route established in the adjacent `gemini_surrounding_analyser` backend. An unauthenticated POST returned HTTP 401 with the expected `UNAUTHORIZED` error.

`SenseiDoubtApiService` uses the existing `http` package. It obtains `FirebaseAuth.instance.currentUser?.getIdToken(true)` for each submission and sets `Authorization: Bearer <token>`. No UID, API key, storage upload, or Gemini credentials are sent. Multipart fields are `image`, JSON `focusRegion`, `helpMode`, `academicLevel`, and optional `userPrompt` (maximum 2000 characters). The library generates the multipart boundary. Mode wire values are centralized in enum getters.

The overall timeout is 100 seconds, including auth, image reads, upload, and response reads. A timeout closes the transport. Retries create a fresh service/client; there are no automatic retries. Disposal closes the active client and late completions do not navigate. Closing the connection cannot guarantee cancellation of inference already running on the server.

## Images and coordinates

Supported JPEG, PNG and WebP within 8 MiB and 32 MP retain the same XFile and bytes. Content signatures determine format, and image metadata validates dimensions.

HEIC/HEIF and oversized supported media are normalized before Select Area. Flutter's platform-aware decoder applies orientation and targets a bounded long edge without upscaling. The normalized raster is encoded as JPEG using flutter_image_compress with orientation metadata removed. Conversion tries 4096, 3072, 2048 and 1536-pixel bounds only as needed. Every output is checked against backend limits. Sources above 64 MiB or 64 MP are rejected before pixel conversion to limit resource use.

No rotation, resize, crop, or recompression happens after selection. Upload uses exactly the selected full image and serializes its normalized region unchanged. Native HEIF decode/encode remains a physical-device verification item; unsupported platform codecs produce a controlled media error.

## Responses, errors and UI

`SenseiDoubtResponse` is immutable. It validates version 1, required fields, confidence range, enums, and mode-specific nullable fields. Unsupported versions, malformed JSON, contradictory fields, and mismatched response modes become typed client errors. Input/work/mistake statuses have enums.

`SenseiDoubtError` maps backend codes, auth, network, timeout, cancellation, malformed response and unsupported version to controlled student-facing copy. Raw backend messages, tokens, image bytes and student content are not logged.

Processing starts once in initState, uses local state, guards repeated submissions, and offers Retry and Back on error. Its status is cosmetic and adds no delay. Success immediately replaces Processing with a temporary preview containing subject, topic, title and explanation. Mode-specific result cards are deferred to Phase 8.

## Files created

- `lib/features/sensei/models/sensei_doubt_error.dart`
- `lib/features/sensei/models/sensei_doubt_response.dart`
- `lib/features/sensei/services/sensei_doubt_api_service.dart`
- `lib/features/sensei/services/sensei_image_preparation.dart`
- `lib/features/sensei/screens/doubt_processing_screen.dart` (includes temporary preview)
- `test/sensei_doubt_api_test.dart`
- `test/sensei_image_preparation_test.dart`
- `test/doubt_processing_screen_test.dart`
- `test/fixtures/preparation.jpg`, `preparation.webp`, `preparation_rotated.jpg`, `preparation_upright.jpg` (synthetic fixtures)
- This report.

## Files modified

- `lib/features/sensei/models/academic_level.dart`
- `lib/features/sensei/models/focus_region.dart`
- `lib/features/sensei/models/sensei_help_mode.dart`
- `lib/features/sensei/models/sensei_help_request.dart`
- `lib/features/sensei/screens/sensei_image_flow.dart`
- `lib/features/sensei/screens/select_area_screen.dart` (handoff callback only)
- `test/sensei_image_flow_test.dart`
- `pubspec.yaml`, `pubspec.lock`
- `ios/Podfile.lock`
- `macos/Flutter/GeneratedPluginRegistrant.swift` (generated plugin registration)

Other pre-existing working tree changes belong to earlier work and were preserved.

## Verification

- `dart format .`: completed.
- `flutter test`: 98 tests passed; the existing 61 remain covered.
- Tests cover multipart/auth/no UID, all mode/level mappings, optional prompt, version/schema/error parsing, network/timeouts, cancellation/concurrency, processing retries and handoff for all three modes, selection restoration, HEIF preparation with mocked native boundaries, supported-format pass-through, large-image guards, and real EXIF decoding before mocked JPEG encoding.
- Processing/layout tests cover 320×568 and 412×915 with safe areas and 1.5× text scaling.
- Full analyzer: 351 historical findings; zero findings in Phase 7B files.
- `flutter build ios --debug --no-codesign`: succeeded; built `build/ios/iphoneos/Runner.app`.
- iOS simulator build could not find a simulator destination in the installed Xcode environment.
- Live authenticated Gemini inference was not performed: no signed-in Firebase user/session is available to the test runner. The endpoint/auth rejection probe is not an end-to-end inference test.

## Manual checks remaining

On a signed-in device, submit a small synthetic question through photo/gallery, selection and each help mode. Verify the returned temporary preview, expired auth, offline/retry/back behavior, physical iPhone HEIC images and EXIF rotations, 48 MP photos, handwriting readability after required downsampling, and memory usage. Native platform image encoding is mocked in automated tests.

Phase 8 result design, chat, history, Focus, Dojos, Profile, and backend changes are intentionally deferred.

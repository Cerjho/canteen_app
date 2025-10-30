# Cloud Functions for Canteen App

This folder contains a TypeScript Firebase Cloud Function `placeWeeklyOrder` which performs atomic weekly order placement and parent wallet deduction using the Admin SDK.

## Local setup

1. Install Node.js (v18) and npm.
2. From the functions folder, install dependencies:

```powershell
cd c:\Developments\projects\canteen_app\functions
npm install
```

3. Build TypeScript:

```powershell
npm run build
```

4. (Optional) Use the Firebase emulator for local testing:

```powershell
firebase emulators:start --only functions,firestore
```

## Deploy

```powershell
cd c:\Developments\projects\canteen_app\functions
npm run build
firebase deploy --only functions
```

## Notes

- The callable function `placeWeeklyOrder` must be deployed to the same Firebase project your Flutter app uses.
- Since the function uses the Admin SDK, it runs with elevated privileges and can update protected fields like `parents/{parentId}.balance` even if Firestore rules prevent client-side updates.
- No changes to Firestore rules are required for this function to work.

## Client changes

- The Flutter app must add `cloud_functions` to `pubspec.yaml` and call the callable function:

```dart
final callable = FirebaseFunctions.instance.httpsCallable('placeWeeklyOrder');
final result = await callable.call(payload);
```

- After successful deployment, run `flutter pub get` and rebuild the app.

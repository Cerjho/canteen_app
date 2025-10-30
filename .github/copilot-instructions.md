## Canteen App — Copilot / AI agent quick instructions

Purpose: give an AI coding assistant the minimum, actionable knowledge to be productive in this multi-app Flutter repo.

- Short summary: This is a Flutter multi-app project (Admin web + Parent mobile/web) with shared core logic under `lib/core/`, feature modules under `lib/features/`, centralized routing in `lib/router/`, and Firebase Cloud Functions in `functions/`.

Quick start (PowerShell)

```powershell
# Default platform-dispatcher
flutter run -d chrome                       # runs Admin web (via lib/main.dart dispatcher)
flutter run -d emulator-5554                # runs Parent mobile (via lib/main.dart dispatcher)

# Explicit entry points
flutter run -d chrome --target lib/app/main_admin_web.dart
flutter run -d emulator-5554 --target lib/app/main_parent_mobile.dart

# Codegen (Riverpod annotations)
flutter pub get ; flutter pub run build_runner build --delete-conflicting-outputs

# Tests
flutter test

# Cloud Functions (TypeScript)
cd functions ; npm install ; npm run build
firebase emulators:start --only functions,firestore    # local testing
firebase deploy --only functions                       # deploy functions
```

Key files and why they matter

- `pubspec.yaml` — lists Riverpod, Firebase SDKs, build_runner and functions integration. Run codegen after changing annotated providers/models.
- `lib/main.dart` — platform dispatcher: runs web admin on web and parent mobile on non-web. If changing behavior, prefer editing entry points in `lib/app/` instead.
-- `lib/app/` — contains `main_admin_web.dart`, `main_parent_mobile.dart` and shared initialization (`main_common.dart`). Use these for targeted runs.
- `lib/core/` — shared services, providers, models. Business logic lives here and should be platform-agnostic.
- `lib/features/` — feature-based modules; there are `admin/` and `parent/` subtrees. Follow the same pattern (screens, widgets, models) when adding features.
- `lib/router/` — centralized routing (admin vs parent routes and guards). Register new routes here; router enforces role and platform restrictions.
- `lib/shared/` — shared UI widgets, utils and theming used across apps.
- `functions/` & `functions/README.md` — contains server-side logic (TypeScript Cloud Functions). Use the emulator for local testing because some flows (wallet deduction) require Admin privileges.
- `firebase.json`, `firestore.rules`, `firestore.indexes.json` — deployment and security rules. Be careful: functions run with admin privileges and can bypass client rule restrictions.

Project-specific patterns and conventions

- Multi-app design: `lib/main.dart` is a dispatcher; individual entrypoints live under `lib/app/`. When adding or modifying platform behavior, prefer editing `lib/app/*` not `lib/main.dart` unless changing dispatch logic.
- Feature-first layout: each feature owns its UI and logic (e.g., `lib/features/admin/menu/`). New features should follow that pattern.
- Shared core: put models, services, and providers in `lib/core/` so both Admin and Parent apps reuse them.
- Riverpod + codegen: providers use Riverpod 2.x and annotation-based generation. After editing provider annotations, run build_runner to regenerate files.
- Relative imports: codebase uses relative imports across feature layers (examples: `../../../core/services/auth_service.dart`, or within feature `widgets/menu_item_card.dart`). Maintain this import style for consistency.
- Naming: entrypoints use `main_<role>_<platform>.dart` (e.g., `main_admin_web.dart`, `main_parent_mobile.dart`). Services are named `*_service.dart` and live in `lib/core/services/`.
- Environment: an `.env` file is included as an asset; `flutter_dotenv` is used to load it.

State, services and data flow

- State management: Riverpod providers under `lib/core/providers/` are the single source of truth. UI consumes providers from features. When changing provider signatures, update dependent consumer code and run codegen.
- Services: `lib/core/services/` encapsulate Firebase access (auth, firestore, storage, functions). Prefer calling services from providers, not directly from widgets.
- Cloud Functions: critical server-side logic (e.g., atomic weekly order placement and parent wallet deduction). Clients call via `FirebaseFunctions.instance.httpsCallable('placeWeeklyOrder')`.

Small actionable examples

- Run Admin web explicitly:
```powershell
flutter run -d chrome --target lib/app/main_admin_web.dart
```

- Regenerate Riverpod providers:
```powershell
flutter pub run build_runner build --delete-conflicting-outputs
```

- Call cloud function from Flutter (example):
```dart
final callable = FirebaseFunctions.instance.httpsCallable('placeWeeklyOrder');
final result = await callable.call(payload);
```

Rules for making changes (advice for an AI assistant)

- Preserve the platform dispatcher unless explicitly instructed to change app routing or platform behavior.
- If you add or remove providers/models with annotations, run codegen and update imports referencing generated files.
- When adding features, always register UI routes in `lib/router/` and update role guards if needed.
- Avoid editing deployed Cloud Functions without running local emulator tests. Use `firebase emulators:start` to validate firestore and functions together.
- When modifying shared services, search for usages across `lib/features/` and `lib/app/` before changing public method signatures.

Files to inspect first when debugging or implementing a feature

- `lib/main.dart`
- `lib/app/main_admin_web.dart`, `lib/app/main_parent_mobile.dart`
- `lib/core/services/` (auth_service.dart, order_service.dart, etc.)
- `lib/core/providers/`
- `lib/features/` (admin and parent subtrees)
- `lib/router/` (router.dart, admin_routes.dart, parent_routes.dart)
- `functions/` and `functions/README.md`
- `pubspec.yaml`, `firebase.json`, `firestore.rules`

If there's an existing `.github/copilot-instructions.md` in the repo: merge any unique, actionable lines above rather than overwriting nuanced guidance. (No previous file was found when this was created.)

Questions for you

- Anything missing or should we add specific code ownership, CI steps, or sensitive-file handling (e.g., where to store service account keys) to this guide?

---
Generated from repository inspection on 2025-10-21. Update as the project evolves (entrypoints, providers, or functions change).

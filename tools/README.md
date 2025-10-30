# Migration tools for canteen_app

## migrate_user_roles.js

This script updates documents in `users` collection to ensure explicit boolean flags `isAdmin` and `isParent` exist.

Prerequisites

- Node.js (v18+). This repo has been tested locally with Node v22.

- Install dependencies (from `tools` folder):

```powershell
cd tools
npm install
```

Usage

Run the migration (test in emulator or dev project first):

```powershell
# From repo root
cd tools
# Populate booleans from legacy 'role' if missing
node migrate_user_roles.js --project your-firebase-project-id

# To also remove legacy 'role' field after verifying
node migrate_user_roles.js --project your-firebase-project-id --remove-legacy
```

Authentication

- The script uses Application Default Credentials. Set `GOOGLE_APPLICATION_CREDENTIALS` to point to a service account JSON with Firestore write permission, or run where ADC is already configured.

- VERY IMPORTANT: Do not run against production without testing in a staging/dev environment first.

Notes

- The script is intentionally conservative: it preserves existing boolean flags and only writes missing ones. When `--remove-legacy` is passed it will delete legacy `role` fields.

/*
 Migration script for canteen_app users collection
 - Ensures each users/{uid} doc has explicit boolean flags: isAdmin, isParent
 - Preference order when deriving flags:
   1) If isAdmin/isParent already present, keep them
   2) Else, if legacy 'role' string exists, derive flags from it
   3) Else, default to isParent=true, isAdmin=false (safe fallback)
 - Optionally removes the legacy 'role' field when run with --remove-legacy

 Usage:
   node migrate_user_roles.js --project <FIREBASE_PROJECT_ID> [--remove-legacy]

 Requirements:
 - Node 18+ (or installed firebase-admin)
 - A service account JSON available and set in GOOGLE_APPLICATION_CREDENTIALS env
   or run from an environment with ADC configured.

 NOTE: This script performs writes to your production Firestore if pointed
       to a production project. Test against a dev project or emulator first.
*/

const admin = require('firebase-admin');
const { argv } = require('process');

function parseArgs() {
  const args = {
    project: null,
    removeLegacy: false,
  };
  for (let i = 2; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--project' && argv[i + 1]) {
      args.project = argv[++i];
    } else if (a === '--remove-legacy') {
      args.removeLegacy = true;
    }
  }
  return args;
}

(async function main() {
  const args = parseArgs();

  // Initialize admin SDK
  try {
    admin.initializeApp();
  } catch (err) {
    // Already initialized in some envs
  }

  const db = admin.firestore();
  const usersCol = db.collection('users');

  console.log('Starting migration: will ensure isAdmin/isParent booleans exist on users documents');
  if (args.removeLegacy) console.log('Will also remove legacy `role` field from user docs.');
  console.log('WARNING: Run against emulator or dev project first.');

  let processed = 0;
  const snapshot = await usersCol.get();
  console.log(`Found ${snapshot.size} user documents`);

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const updates = {};
    let needsUpdate = false;

    const hasIsAdmin = Object.prototype.hasOwnProperty.call(data, 'isAdmin');
    const hasIsParent = Object.prototype.hasOwnProperty.call(data, 'isParent');
    const hasLegacyRole = Object.prototype.hasOwnProperty.call(data, 'role');

    if (!hasIsAdmin || !hasIsParent) {
      let parsedIsAdmin = false;
      let parsedIsParent = false;

      if (hasIsAdmin || hasIsParent) {
        parsedIsAdmin = !!data.isAdmin;
        parsedIsParent = !!data.isParent;
      } else if (hasLegacyRole) {
        const role = String(data.role || '').toLowerCase();
        if (role === 'admin') {
          parsedIsAdmin = true;
          parsedIsParent = false;
        } else {
          parsedIsAdmin = false;
          parsedIsParent = true;
        }
      } else {
        // Safe default
        parsedIsAdmin = false;
        parsedIsParent = true;
      }

      updates.isAdmin = parsedIsAdmin;
      updates.isParent = parsedIsParent;
      needsUpdate = true;
    }

    if (args.removeLegacy && hasLegacyRole) {
      updates.role = admin.firestore.FieldValue.delete();
      needsUpdate = true;
    }

    if (needsUpdate) {
      updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();
      try {
        await doc.ref.update(updates);
        processed += 1;
        console.log(`Updated ${doc.id} -> isAdmin=${updates.isAdmin} isParent=${updates.isParent}${args.removeLegacy && hasLegacyRole ? ' (removed legacy role)' : ''}`);
      } catch (err) {
        console.error(`Failed to update ${doc.id}:`, err.message || err);
      }
    }
  }

  console.log(`Migration complete. Documents updated: ${processed}`);
  process.exit(0);
})();

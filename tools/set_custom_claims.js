/**
 * Utility to set/unset `admin` and `parent` custom claims for a Firebase user.
 *
 * This script merges provided flags with existing custom claims so other
 * claims are preserved. To change a claim, pass --admin true|false and/or
 * --parent true|false. If a flag is omitted, that claim is left unchanged.
 *
 * Usage:
 *   node set_custom_claims.js <serviceAccountKey.json> <uid> [--admin true|false] [--parent true|false]
 *
 * Examples:
 *   node set_custom_claims.js ./serviceAccountKey.json abc123 --admin true --parent false
 *   node set_custom_claims.js ./serviceAccountKey.json abc123 --admin false
 */

const admin = require('firebase-admin');

function parseArgs(argv) {
  if (argv.length < 4) return null;
  const keyPath = argv[2];
  const uid = argv[3];
  const result = { keyPath, uid, adminFlag: null, parentFlag: null };

  for (let i = 4; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--admin' && argv[i + 1]) {
      result.adminFlag = argv[++i] === 'true';
    } else if (a === '--parent' && argv[i + 1]) {
      result.parentFlag = argv[++i] === 'true';
    }
  }

  return result;
}

const args = parseArgs(process.argv);
if (!args) {
  console.error('Usage: node set_custom_claims.js <serviceAccountKey.json> <uid> [--admin true|false] [--parent true|false]');
  process.exit(1);
}

try {
  const serviceAccount = require(args.keyPath);

  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });

  (async () => {
    try {
      const auth = admin.auth();
      // Fetch existing claims and merge
      const userRecord = await auth.getUser(args.uid);
      const existing = userRecord.customClaims || {};

      const updated = { ...existing };
      if (args.adminFlag !== null) updated.admin = !!args.adminFlag;
      if (args.parentFlag !== null) updated.parent = !!args.parentFlag;

      await auth.setCustomUserClaims(args.uid, updated);

      console.log(`SUCCESS! Updated claims for user ${args.uid}:`);
      Object.keys(updated).forEach((k) => console.log(`  ${k}: ${updated[k]}`));
      console.log('\nTell your app to refresh the token!');
      process.exit(0);
    } catch (err) {
      console.error('ERROR setting claims:', err.message || err);
      process.exit(2);
    }
  })();
} catch (err) {
  console.error('Failed to load service account key:', err.message || err);
  process.exit(3);
}

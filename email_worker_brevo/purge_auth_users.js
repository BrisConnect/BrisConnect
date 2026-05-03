const admin = require('firebase-admin');

const args = parseArgs(process.argv.slice(2));

if (args.help) {
  printHelp();
  process.exit(0);
}

if (!args.all && args.emails.length === 0 && !args.domain) {
  console.error('No filter provided. Use --all, --emails, or --domain.');
  printHelp();
  process.exit(1);
}

if (!args.dryRun && !args.yes) {
  console.error('Refusing destructive action without --yes.');
  printHelp();
  process.exit(1);
}

main().catch((error) => {
  console.error('Auth purge failed.');
  console.error(error instanceof Error ? error.message : String(error));
  console.error(
    'Set GOOGLE_APPLICATION_CREDENTIALS or FIREBASE_SERVICE_ACCOUNT_JSON (and optionally FIREBASE_PROJECT_ID).',
  );
  process.exit(1);
});

async function main() {
  initFirebase();

  const auth = admin.auth();
  const selected = await collectMatchingUsers(auth, args);

  if (selected.length === 0) {
    console.log('No matching Firebase Auth users found.');
    return;
  }

  console.log(`Matched ${selected.length} user(s).`);
  for (const user of selected.slice(0, 20)) {
    console.log(` - ${user.email || '(no-email)'} [${user.uid}]`);
  }
  if (selected.length > 20) {
    console.log(` ... and ${selected.length - 20} more.`);
  }

  if (args.dryRun) {
    console.log('Dry run only. No users deleted.');
    return;
  }

  const uids = selected.map((u) => u.uid);
  let totalSuccess = 0;
  let totalFailure = 0;

  for (let i = 0; i < uids.length; i += 1000) {
    const chunk = uids.slice(i, i + 1000);
    const result = await auth.deleteUsers(chunk);
    totalSuccess += result.successCount;
    totalFailure += result.failureCount;

    if (result.errors.length > 0) {
      for (const err of result.errors.slice(0, 20)) {
        console.error(`Delete error index=${err.index} reason=${err.error?.message || 'unknown'}`);
      }
      if (result.errors.length > 20) {
        console.error(`... plus ${result.errors.length - 20} more errors in this chunk.`);
      }
    }
  }

  console.log(`Deleted users: ${totalSuccess}`);
  if (totalFailure > 0) {
    console.log(`Failed deletions: ${totalFailure}`);
    process.exitCode = 1;
  }
}

function initFirebase() {
  if (admin.apps.length > 0) {
    return;
  }

  const serviceAccountJson = (process.env.FIREBASE_SERVICE_ACCOUNT_JSON || '').trim();
  const projectId = (process.env.FIREBASE_PROJECT_ID || '').trim();

  if (serviceAccountJson) {
    const credentials = JSON.parse(serviceAccountJson);
    admin.initializeApp({
      credential: admin.credential.cert(credentials),
      ...(projectId ? { projectId } : {}),
    });
    return;
  }

  admin.initializeApp(projectId ? { projectId } : undefined);
}

async function collectMatchingUsers(auth, options) {
  const matches = [];
  let nextPageToken;

  do {
    const page = await auth.listUsers(1000, nextPageToken);
    for (const user of page.users) {
      if (matchesUser(user, options)) {
        matches.push(user);
      }
    }
    nextPageToken = page.pageToken;
  } while (nextPageToken);

  return matches;
}

function matchesUser(user, options) {
  if (options.all) {
    return true;
  }

  const email = (user.email || '').trim().toLowerCase();
  if (!email) {
    return false;
  }

  if (options.emails.includes(email)) {
    return true;
  }

  if (options.domain && email.endsWith(`@${options.domain}`)) {
    return true;
  }

  return false;
}

function parseArgs(argv) {
  const output = {
    all: false,
    yes: false,
    dryRun: false,
    help: false,
    domain: '',
    emails: [],
  };

  for (let i = 0; i < argv.length; i += 1) {
    const arg = argv[i];
    if (arg === '--all') {
      output.all = true;
      continue;
    }
    if (arg === '--yes') {
      output.yes = true;
      continue;
    }
    if (arg === '--dry-run') {
      output.dryRun = true;
      continue;
    }
    if (arg === '--help' || arg === '-h') {
      output.help = true;
      continue;
    }
    if (arg === '--emails') {
      const value = (argv[i + 1] || '').trim();
      i += 1;
      if (value) {
        output.emails.push(
          ...value
            .split(',')
            .map((e) => e.trim().toLowerCase())
            .filter(Boolean),
        );
      }
      continue;
    }
    if (arg === '--domain') {
      const value = (argv[i + 1] || '').trim().toLowerCase();
      i += 1;
      output.domain = value.startsWith('@') ? value.slice(1) : value;
      continue;
    }

    console.error(`Unknown argument: ${arg}`);
    output.help = true;
    return output;
  }

  output.emails = Array.from(new Set(output.emails));
  return output;
}

function printHelp() {
  console.log('Usage:');
  console.log('  node purge_auth_users.js --all --dry-run');
  console.log('  node purge_auth_users.js --all --yes');
  console.log('  node purge_auth_users.js --emails a@x.com,b@y.com --yes');
  console.log('  node purge_auth_users.js --domain example.com --dry-run');
  console.log('');
  console.log('Flags:');
  console.log('  --all            Select all Firebase Auth users');
  console.log('  --emails         Comma-separated list of emails to match');
  console.log('  --domain         Match users by email domain');
  console.log('  --dry-run        Show matched users without deleting');
  console.log('  --yes            Required for actual deletion');
  console.log('  --help, -h       Show this help');
}

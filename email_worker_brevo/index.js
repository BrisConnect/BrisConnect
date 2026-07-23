const admin = require('firebase-admin');
const crypto = require('node:crypto');
const twilio = require('twilio');

const POLL_INTERVAL_MS = parsePositiveInt(process.env.POLL_INTERVAL_MS, 3000);
const MAX_BATCH_SIZE = parsePositiveInt(process.env.MAX_BATCH_SIZE, 20);
const SMS_PROVIDER = (process.env.SMS_PROVIDER || 'mock').trim().toLowerCase();
const EMAIL_PROVIDER = (process.env.EMAIL_PROVIDER || 'mock').trim().toLowerCase();
const WORKER_ID = process.env.WORKER_ID || `worker-${crypto.randomBytes(4).toString('hex')}`;
const RUN_ONCE = process.argv.includes('--once');

bootstrap().catch((error) => {
	console.error(`[worker:${WORKER_ID}] fatal startup error`);
	console.error(error instanceof Error ? error.message : error);
	console.error(
		'Set GOOGLE_APPLICATION_CREDENTIALS or FIREBASE_SERVICE_ACCOUNT_JSON (and optionally FIREBASE_PROJECT_ID).',
	);
	process.exit(1);
});

async function bootstrap() {
	initFirebase();
	const db = admin.firestore();

	console.log(`[worker:${WORKER_ID}] started; smsProvider=${SMS_PROVIDER}; emailProvider=${EMAIL_PROVIDER}; runOnce=${RUN_ONCE}`);

	if (RUN_ONCE) {
		const processed = await processBatch(db);
		console.log(`[worker:${WORKER_ID}] runOnce complete; processed=${processed}`);
		return;
	}

	let stopped = false;
	process.on('SIGINT', () => {
		stopped = true;
		console.log(`[worker:${WORKER_ID}] stopping (SIGINT)`);
	});
	process.on('SIGTERM', () => {
		stopped = true;
		console.log(`[worker:${WORKER_ID}] stopping (SIGTERM)`);
	});

	while (!stopped) {
		try {
			const processed = await processBatch(db);
			if (processed > 0) {
				console.log(`[worker:${WORKER_ID}] processed=${processed}`);
			}
		} catch (error) {
			console.error(`[worker:${WORKER_ID}] batch error`, error);
		}
		await delay(POLL_INTERVAL_MS);
	}
}

function initFirebase() {
	if (admin.apps.length > 0) {
		return;
	}

	const serviceAccountJson = (process.env.FIREBASE_SERVICE_ACCOUNT_JSON || '').trim();
	const emulatorHost = (process.env.FIRESTORE_EMULATOR_HOST || '').trim();
	const projectId = (process.env.FIREBASE_PROJECT_ID || '').trim() ||
			(emulatorHost ? 'demo-brisconnect' : '');

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

async function processBatch(db) {
	let processed = 0;

	// Process email queue first.
	const emailSnap = await db
		.collection('mail')
		.where('status', 'in', ['pending', '==', null])
		.orderBy('createdAt', 'asc')
		.limit(MAX_BATCH_SIZE)
		.get();

	for (const doc of emailSnap.docs) {
		const claimed = await claimEmailJob(db, doc.id);
		if (!claimed) continue;
		processed += 1;
		await processEmailJob(db, doc.id);
	}

	// Process SMS queue.
	const candidatesSnap = await db
		.collection('sms_queue')
		.orderBy('createdAt', 'asc')
		.limit(MAX_BATCH_SIZE)
		.get();

	for (const doc of candidatesSnap.docs) {
		const claimed = await claimJob(db, doc.id);
		if (!claimed) {
			continue;
		}
		processed += 1;
		await processJob(db, doc.id);
	}
	return processed;
}

async function claimJob(db, id) {
	const ref = db.collection('sms_queue').doc(id);
	return db.runTransaction(async (tx) => {
		const snap = await tx.get(ref);
		if (!snap.exists) {
			return false;
		}

		const data = snap.data() || {};
		const status = (data.status || 'pending').toString().toLowerCase();
		if (status !== 'pending') {
			return false;
		}

		tx.update(ref, {
			status: 'processing',
			claimedAt: admin.firestore.FieldValue.serverTimestamp(),
			workerId: WORKER_ID,
			updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			attempts: Number(data.attempts || 0) + 1,
		});
		return true;
	});
}

async function processJob(db, id) {
	const ref = db.collection('sms_queue').doc(id);
	const snap = await ref.get();
	if (!snap.exists) {
		return;
	}
	const data = snap.data() || {};

	const to = String(data.to || '').trim();
	const message = String(data.message || '').trim();
	if (!to || !message) {
		await markFailed(ref, 'Missing required fields: to/message.');
		return;
	}

	try {
		const providerResult = await sendSms({ to, message, meta: data.meta || {} });
		await ref.set(
			{
				status: 'sent',
				sentAt: admin.firestore.FieldValue.serverTimestamp(),
				updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				provider: SMS_PROVIDER,
				providerResponse: providerResult,
			},
			{ merge: true },
		);
	} catch (error) {
		await markFailed(ref, error instanceof Error ? error.message : String(error));
	}
}

async function markFailed(ref, message) {
	await ref.set(
		{
			status: 'failed',
			failedAt: admin.firestore.FieldValue.serverTimestamp(),
			updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			error: message,
		},
		{ merge: true },
	);
}

async function sendSms(job) {
	if (SMS_PROVIDER === 'mock') {
		console.log(`[worker:${WORKER_ID}] mock SMS -> ${job.to}: ${job.message}`);
		return {
			mock: true,
			accepted: true,
			at: new Date().toISOString(),
		};
	}

	if (SMS_PROVIDER === 'twilio') {
		return sendViaTwilio(job);
	}

	throw new Error(`Unsupported SMS_PROVIDER: ${SMS_PROVIDER}`);
}

async function sendViaTwilio(job) {
	const accountSid = mustGetEnv('TWILIO_ACCOUNT_SID');
	const messagingServiceSid = mustGetEnv('TWILIO_MESSAGING_SERVICE_SID');
	const apiKeySid = (process.env.TWILIO_API_KEY_SID || '').trim();
	const apiKeySecret = (process.env.TWILIO_API_KEY_SECRET || '').trim();
	const authToken = (process.env.TWILIO_AUTH_TOKEN || '').trim();

	let client;
	if (apiKeySid && apiKeySecret) {
		client = twilio(apiKeySid, apiKeySecret, { accountSid });
	} else {
		client = twilio(accountSid, mustGetEnv('TWILIO_AUTH_TOKEN'));
	}

	if (!apiKeySid && !authToken) {
		throw new Error(
			'Missing Twilio credentials: set TWILIO_AUTH_TOKEN or TWILIO_API_KEY_SID/TWILIO_API_KEY_SECRET.',
		);
	}

	const msg = await client.messages.create({
		to: job.to,
		messagingServiceSid,
		body: job.message,
	});

	return {
		sid: msg.sid,
		status: msg.status,
		to: msg.to,
		from: msg.from,
	};
}

async function claimEmailJob(db, id) {
	const ref = db.collection('mail').doc(id);
	return db.runTransaction(async (tx) => {
		const snap = await tx.get(ref);
		if (!snap.exists) return false;

		const data = snap.data() || {};
		const status = (data.status || 'pending').toString().toLowerCase();
		if (status !== 'pending') return false;

		tx.update(ref, {
			status: 'processing',
			claimedAt: admin.firestore.FieldValue.serverTimestamp(),
			workerId: WORKER_ID,
			updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			attempts: Number(data.attempts || 0) + 1,
		});
		return true;
	});
}

async function processEmailJob(db, id) {
	const ref = db.collection('mail').doc(id);
	const snap = await ref.get();
	if (!snap.exists) return;

	const data = snap.data() || {};
	const to = String(data.to || '').trim();
	const message = data.message || {};
	const subject = String(message.subject || '').trim();
	const html = String(message.html || '').trim();

	if (!to || !subject || !html) {
		await markEmailFailed(ref, 'Missing required fields: to/subject/html.');
		return;
	}

	try {
		const providerResult = await sendEmail({ to, subject, html, meta: data.meta || {} });
		await ref.set(
			{
				status: 'sent',
				sentAt: admin.firestore.FieldValue.serverTimestamp(),
				updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				provider: EMAIL_PROVIDER,
				providerResponse: providerResult,
			},
			{ merge: true },
		);
	} catch (error) {
		await markEmailFailed(ref, error instanceof Error ? error.message : String(error));
	}
}

async function markEmailFailed(ref, message) {
	await ref.set(
		{
			status: 'failed',
			failedAt: admin.firestore.FieldValue.serverTimestamp(),
			updatedAt: admin.firestore.FieldValue.serverTimestamp(),
			error: message,
		},
		{ merge: true },
	);
}

async function sendEmail(job) {
	if (EMAIL_PROVIDER === 'mock') {
		console.log(`[worker:${WORKER_ID}] mock email -> ${job.to}: ${job.subject}`);
		console.log(`[worker:${WORKER_ID}] mock email html -> ${job.html.substring(0, 200)}...`);
		return {
			mock: true,
			accepted: true,
			at: new Date().toISOString(),
		};
	}

	if (EMAIL_PROVIDER === 'brevo') {
		return sendViaBrevo(job);
	}

	throw new Error(`Unsupported EMAIL_PROVIDER: ${EMAIL_PROVIDER}`);
}

async function sendViaBrevo(job) {
	const apiKey = mustGetEnv('BREVO_API_KEY');
	const senderEmail = (process.env.BREVO_SENDER_EMAIL || 'noreply@brisconnect.app').trim();
	const senderName = (process.env.BREVO_SENDER_NAME || 'BrisConnect+').trim();

	const response = await fetch('https://api.brevo.com/v3/smtp/email', {
		method: 'POST',
		headers: {
			'Content-Type': 'application/json',
			'api-key': apiKey,
		},
		body: JSON.stringify({
			sender: { email: senderEmail, name: senderName },
			to: [{ email: job.to }],
			subject: job.subject,
			htmlContent: job.html,
		}),
	});

	const text = await response.text();
	if (!response.ok) {
		throw new Error(`Brevo API error ${response.status}: ${text}`);
	}

	let parsed;
	try {
		parsed = JSON.parse(text);
	} catch (_) {
		parsed = { raw: text };
	}

	return {
		provider: 'brevo',
		status: response.status,
		response: parsed,
	};
}

function mustGetEnv(name) {
	const value = (process.env[name] || '').trim();
	if (!value) {
		throw new Error(`Missing environment variable: ${name}`);
	}
	return value;
}

function parsePositiveInt(value, fallback) {
	const parsed = Number.parseInt(String(value || ''), 10);
	return Number.isFinite(parsed) && parsed > 0 ? parsed : fallback;
}

function delay(ms) {
	return new Promise((resolve) => setTimeout(resolve, ms));
}

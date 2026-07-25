/**
 * Unit tests for business-owner notification Cloud Functions.
 *
 * Run with: cd functions && npm test
 *
 * Uses firebase-functions-test offline mode so no live project is required.
 */

const { expect } = require('chai');
const functionsTest = require('firebase-functions-test')();
const sinon = require('sinon');

// Stub firebase-admin before requiring the functions module.
let adminStub;
let collectionStub;
let docStub;
let messagingStub;

function createDocSnapshot(data = {}, id = 'doc-id', exists = true) {
  return {
    exists,
    id,
    data: () => data,
    ref: { id, update: sinon.stub().resolves() },
  };
}

function createQuerySnapshot(docs = []) {
  return {
    docs,
    size: docs.length,
    empty: docs.length === 0,
  };
}

function createChange(beforeData, afterData) {
  return {
    data: {
      before: { data: () => beforeData, ref: { update: sinon.stub().resolves() } },
      after: { data: () => afterData, ref: { update: sinon.stub().resolves() } },
    },
    params: { promotionId: 'promo-1' },
  };
}

/**
 * Builds a CloudEvent-shaped change for v2 Firestore triggers.
 * firebase-functions-test wraps v2 onDocumentUpdated with an event normalizer
 * that reads event.data.before/after; this helper produces that shape.
 *
 * We use makeDocumentSnapshot for the *before* document (the normalizer needs
 * a real snapshot to derive metadata), but keep *after* as a plain object with
 * a stubbed ref so the test can avoid real Firestore writes.
 */
function createCloudEventChange(beforeData, afterData) {
  return {
    data: functionsTest.makeChange(
      functionsTest.firestore.makeDocumentSnapshot(beforeData, 'promotions/promo-1'),
      functionsTest.firestore.makeDocumentSnapshot(afterData, 'promotions/promo-1'),
    ),
    params: { promotionId: 'promo-1' },
  };
}

before(() => {
  // Build a fake admin namespace.
  docStub = sinon.stub();
  collectionStub = sinon.stub().returns({ doc: docStub });
  messagingStub = sinon.stub();

  const fakeFirestore = {
    collection: collectionStub,
    FieldValue: {
      serverTimestamp: () => '__SERVER_TIMESTAMP__',
    },
    Timestamp: {
      now: () => ({ toMillis: () => Date.now(), _seconds: Math.floor(Date.now() / 1000) }),
      fromMillis: (ms) => ({ toMillis: () => ms, toDate: () => new Date(ms) }),
    },
  };

  adminStub = {
    apps: [],
    initializeApp: sinon.stub(),
    firestore: sinon.stub().returns(fakeFirestore),
    messaging: messagingStub,
  };
  // The code accesses admin.firestore.FieldValue/Timestamp directly, so attach
  // them to the stub function as properties.
  adminStub.firestore.FieldValue = fakeFirestore.FieldValue;
  adminStub.firestore.Timestamp = fakeFirestore.Timestamp;

  // Replace firebase-admin with our stub in the require cache.
  require.cache[require.resolve('firebase-admin')] = {
    id: require.resolve('firebase-admin'),
    filename: require.resolve('firebase-admin'),
    loaded: true,
    exports: adminStub,
  };

  // Stub config-dependent secrets so og_proxy does not fail to load.
  require.cache[require.resolve('firebase-functions/params')] = {
    id: require.resolve('firebase-functions/params'),
    filename: require.resolve('firebase-functions/params'),
    loaded: true,
    exports: {
      defineSecret: (name) => ({ name, value: () => 'dummy-secret' }),
      defineString: (name) => ({ name, value: () => 'dummy-string' }),
    },
  };
});

after(() => {
  functionsTest.cleanup();
  sinon.restore();
});

beforeEach(() => {
  // Reset stubs between tests.
  collectionStub.resetHistory();
  docStub.resetHistory();
  messagingStub.resetHistory();
});

describe('onPromotionEngagementSpike', () => {
  let onPromotionEngagementSpike;

  beforeEach(() => {
    delete require.cache[require.resolve('../index.js')];
    const mod = require('../index.js');
    onPromotionEngagementSpike = mod.onPromotionEngagementSpike;
  });

  it('does nothing when delta is below threshold', async () => {
    const change = createCloudEventChange(
      { views: 0, clicks: 0 },
      { views: 10, clicks: 5, ownerId: 'owner-1' },
    );

    // Even with a low delta the function looks up the owner doc; stub it.
    const ownerDoc = createDocSnapshot({ notifyTrendingPromotion: true });
    docStub.withArgs('owner-1').returns({
      get: sinon.stub().resolves(ownerDoc),
    });

    const wrapped = functionsTest.wrap(onPromotionEngagementSpike);
    await wrapped(change);

    expect(messagingStub.called).to.be.false;
  });

  it('sends a notification when engagement crosses threshold', async () => {
    const afterUpdateStub = sinon.stub().resolves();
    const change = createCloudEventChange(
      { views: 0, clicks: 0 },
      { views: 60, clicks: 0, ownerId: 'owner-1', title: 'Big Sale' },
    );
    change.data.after.ref.update = afterUpdateStub;

    const ownerDoc = createDocSnapshot({ notifyTrendingPromotion: true });
    const tokenDoc = createDocSnapshot({}, 'token-abc', true);
    const tokensSnap = createQuerySnapshot([tokenDoc]);

    const notificationsDocStub = sinon.stub().returns({
      set: sinon.stub().resolves(),
    });

    docStub.withArgs('owner-1').returns({
      get: sinon.stub().resolves(ownerDoc),
      collection: sinon.stub().callsFake((name) => {
        if (name === 'fcmTokens') {
          return {
            get: sinon.stub().resolves(tokensSnap),
            doc: sinon.stub().returns({ delete: sinon.stub().resolves() }),
          };
        }
        if (name === 'notifications') {
          return {
            doc: notificationsDocStub,
          };
        }
        return { get: sinon.stub().resolves(createQuerySnapshot([])) };
      }),
    });

    collectionStub.withArgs('user_notifications').returns({ add: sinon.stub().resolves({ id: 'user-notif-1' }) });

    messagingStub.returns({
      sendEachForMulticast: sinon.stub().resolves({ successCount: 1, responses: [{ success: true }] }),
    });

    const wrapped = functionsTest.wrap(onPromotionEngagementSpike);
    await wrapped(change);

    expect(afterUpdateStub.calledOnce).to.be.true;
    const updateArg = afterUpdateStub.firstCall.args[0];
    expect(updateArg).to.have.property('lastSpikeNotifiedAt');
  });

  it('does not notify when owner disabled trending notifications', async () => {
    const change = createCloudEventChange(
      { views: 0, clicks: 0 },
      { views: 100, clicks: 0, ownerId: 'owner-1' },
    );

    const ownerDoc = createDocSnapshot({ notifyTrendingPromotion: false });
    docStub.withArgs('owner-1').returns({
      get: sinon.stub().resolves(ownerDoc),
    });

    const wrapped = functionsTest.wrap(onPromotionEngagementSpike);
    await wrapped(change);

    expect(messagingStub.called).to.be.false;
  });
});

describe('extendPromotion', () => {
  let extendPromotion;

  beforeEach(() => {
    delete require.cache[require.resolve('../index.js')];
    const mod = require('../index.js');
    extendPromotion = mod.extendPromotion;
  });

  it('extends endAt by the requested number of days', async () => {
    const now = Date.now();
    const existingEndAt = adminStub.firestore().Timestamp.fromMillis(now);
    const promotionDoc = createDocSnapshot(
      { ownerId: 'owner-1', endAt: { toMillis: () => now } },
      'promo-1',
    );

    const updateStub = sinon.stub().resolves();
    docStub.withArgs('promo-1').returns({
      get: sinon.stub().resolves(promotionDoc),
      update: updateStub,
    });

    const wrapped = functionsTest.wrap(extendPromotion);
    const result = await wrapped({ data: { promotionId: 'promo-1', extensionDays: 3 } });

    expect(result.success).to.be.true;
    expect(result.extensionDays).to.equal(3);
    expect(updateStub.calledOnce).to.be.true;
    const updateArg = updateStub.firstCall.args[0];
    expect(updateArg).to.have.property('endAt');
    expect(updateArg).to.have.property('status', 'active');
    expect(updateArg).to.have.property('expiryReminderSentAt', null);
  });

  it('rejects when promotion is not found', async () => {
    const missingDoc = createDocSnapshot({}, 'promo-1', false);
    docStub.withArgs('promo-1').returns({
      get: sinon.stub().resolves(missingDoc),
    });

    const wrapped = functionsTest.wrap(extendPromotion);
    try {
      await wrapped({ data: { promotionId: 'promo-1' } });
      expect.fail('Expected HttpsError');
    } catch (e) {
      expect(e.code).to.equal('not-found');
    }
  });
});

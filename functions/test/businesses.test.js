/**
 * Unit tests for business management Cloud Functions.
 */

const { expect } = require('chai');
const functionsTest = require('firebase-functions-test')();
const sinon = require('sinon');

let adminStub;
let collectionStub;
let docStub;

function createDocSnapshot(data = {}, id = 'doc-id', exists = true) {
  return {
    exists,
    id,
    data: () => data,
    ref: { id, update: sinon.stub().resolves() },
  };
}

function createQuerySnapshot(docs = []) {
  return { docs, size: docs.length, empty: docs.length === 0 };
}

before(() => {
  docStub = sinon.stub();
  let queryGetStub = sinon.stub().resolves(createQuerySnapshot([]));
  collectionStub = sinon.stub().callsFake(() => ({
    doc: docStub,
    where: sinon.stub().returns({
      where: sinon.stub().returns({
        get: queryGetStub,
      }),
    }),
  }));
  // Expose so individual tests can replace the query .get() result.
  collectionStub.setQueryGetStub = (stub) => { queryGetStub = stub; };
  collectionStub.getQueryGetStub = () => queryGetStub;

  const fakeFirestore = {
    collection: collectionStub,
    FieldValue: {
      serverTimestamp: () => '__SERVER_TIMESTAMP__',
      delete: () => '__DELETE__',
    },
    Timestamp: {
      now: () => ({ toMillis: () => Date.now(), _seconds: Math.floor(Date.now() / 1000) }),
      fromDate: (date) => ({ toMillis: () => date.getTime(), _seconds: Math.floor(date.getTime() / 1000) }),
    },
  };

  adminStub = {
    apps: [],
    initializeApp: sinon.stub(),
    firestore: sinon.stub().returns(fakeFirestore),
    messaging: sinon.stub().returns({}),
  };
  adminStub.firestore.FieldValue = fakeFirestore.FieldValue;
  adminStub.firestore.Timestamp = fakeFirestore.Timestamp;

  require.cache[require.resolve('firebase-admin')] = {
    id: require.resolve('firebase-admin'),
    filename: require.resolve('firebase-admin'),
    loaded: true,
    exports: adminStub,
  };

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

describe('flagDuplicateBusinesses', () => {
  let flagDuplicateBusinesses;

  beforeEach(() => {
    // Re-inject our stubbed firebase-admin before re-requiring index.js so
    // other test files do not overwrite the cache with their own admin stub.
    require.cache[require.resolve('firebase-admin')] = {
      id: require.resolve('firebase-admin'),
      filename: require.resolve('firebase-admin'),
      loaded: true,
      exports: adminStub,
    };

    delete require.cache[require.resolve('../index.js')];
    const mod = require('../index.js');
    flagDuplicateBusinesses = mod.flagDuplicateBusinesses;

    collectionStub.resetHistory();
    docStub.resetHistory();
  });

  it('flags a business when a similar nearby business exists', async () => {
    const updateStub = sinon.stub().resolves();
    const afterData = {
      businessName: 'Cafe Bravo',
      lat: -27.4679,
      lng: 153.0281,
      isActive: true,
    };
    const change = functionsTest.makeChange(
      functionsTest.firestore.makeDocumentSnapshot({}, 'businesses/biz-1'),
      functionsTest.firestore.makeDocumentSnapshot(afterData, 'businesses/biz-1'),
    );
    // Stub the real DocumentReference.update so the function does not hit Firestore.
    sinon.stub(change.after.ref, 'update').callsFake(updateStub);

    const event = { data: change, params: { businessId: 'biz-1' } };

    const candidate = createDocSnapshot(
      {
        businessName: 'Cafe Bravoo',
        lat: -27.4679,
        lng: 153.0282,
        isActive: true,
      },
      'biz-2',
    );

    collectionStub.setQueryGetStub(sinon.stub().resolves(createQuerySnapshot([candidate])));

    const wrapped = functionsTest.wrap(flagDuplicateBusinesses);
    await wrapped(event);

    expect(updateStub.calledOnce).to.be.true;
    const updateArg = updateStub.firstCall.args[0];
    expect(updateArg).to.have.property('duplicateOf', 'biz-2');
    expect(updateArg).to.have.property('duplicateScore');
    expect(updateArg.duplicateScore).to.be.greaterThan(0.85);
  });

  it('does not flag when no similar business exists', async () => {
    const updateStub = sinon.stub().resolves();
    const afterData = {
      businessName: 'Unique Name XYZ',
      lat: -27.4679,
      lng: 153.0281,
      isActive: true,
    };
    const change = functionsTest.makeChange(
      functionsTest.firestore.makeDocumentSnapshot({}, 'businesses/biz-1'),
      functionsTest.firestore.makeDocumentSnapshot(afterData, 'businesses/biz-1'),
    );
    change.after.ref = { update: updateStub };

    const event = { data: change, params: { businessId: 'biz-1' } };

    collectionStub.setQueryGetStub(sinon.stub().resolves(createQuerySnapshot([])));

    const wrapped = functionsTest.wrap(flagDuplicateBusinesses);
    await wrapped(event);

    expect(updateStub.called).to.be.false;
  });
});

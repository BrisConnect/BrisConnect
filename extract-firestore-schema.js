/**
 * BrisConnect Firestore Schema Extractor
 * --------------------------------------
 * Project: brisconnect-68b78
 *
 * READ-ONLY:
 * - Reads collection names
 * - Samples documents
 * - Detects field names
 * - Detects Firestore data types
 * - Detects subcollections
 * - Detects possible relationship/reference fields
 *
 * DOES NOT:
 * - Create documents
 * - Update documents
 * - Delete documents
 * - Export actual field values
 */

const fs = require("fs");

const {
  initializeApp,
  applicationDefault,
} = require("firebase-admin/app");

const {
  getFirestore,
  Timestamp,
  GeoPoint,
  DocumentReference,
} = require("firebase-admin/firestore");

// ======================================================
// CONFIGURATION
// ======================================================

const PROJECT_ID = "brisconnect-68b78";

// Maximum number of documents sampled from each collection.
// Increase later if you want broader schema coverage.
const MAX_DOCS_PER_COLLECTION = 100;

// Maximum subcollection nesting depth.
const MAX_DEPTH = 5;

// ======================================================
// INITIALIZE FIREBASE ADMIN
// ======================================================

initializeApp({
  credential: applicationDefault(),
  projectId: PROJECT_ID,
});

const db = getFirestore();

// ======================================================
// SCHEMA STORAGE
// ======================================================

const schemas = {};

// ======================================================
// FIRESTORE TYPE DETECTION
// ======================================================

function getFirestoreType(value) {
  if (value === null) {
    return "null";
  }

  if (typeof value === "string") {
    return "string";
  }

  if (typeof value === "boolean") {
    return "boolean";
  }

  if (typeof value === "number") {
    return Number.isInteger(value)
      ? "integer"
      : "number";
  }

  if (value instanceof Timestamp) {
    return "timestamp";
  }

  if (value instanceof GeoPoint) {
    return "geopoint";
  }

  if (value instanceof DocumentReference) {
    return "document_reference";
  }

  if (Buffer.isBuffer(value)) {
    return "bytes";
  }

  if (Array.isArray(value)) {
    if (value.length === 0) {
      return "array";
    }

    const types = [
      ...new Set(
        value.map((item) =>
          getFirestoreType(item)
        )
      ),
    ];

    return `array<${types.join("|")}>`;
  }

  if (typeof value === "object") {
    return "map";
  }

  return typeof value;
}

// ======================================================
// CREATE/GET COLLECTION SCHEMA
// ======================================================

function ensureSchema(path) {
  if (!schemas[path]) {
    schemas[path] = {
      path: path,

      documentsSampled: 0,

      fields: {},

      subcollections: [],
    };
  }

  return schemas[path];
}

// ======================================================
// RECORD FIELD
// ======================================================

function recordField(
  schema,
  fieldName,
  fieldType
) {
  if (!schema.fields[fieldName]) {
    schema.fields[fieldName] = {
      types: [],
      occurrences: 0,
    };
  }

  if (
    !schema.fields[fieldName].types.includes(
      fieldType
    )
  ) {
    schema.fields[fieldName].types.push(
      fieldType
    );
  }

  schema.fields[fieldName].occurrences++;
}

// ======================================================
// SCAN COLLECTION
// ======================================================

async function scanCollection(
  collectionRef,
  genericPath,
  depth = 0
) {
  if (depth > MAX_DEPTH) {
    return;
  }

  const schema = ensureSchema(genericPath);

  console.log(
    `Scanning: ${genericPath}`
  );

  let snapshot;

  try {
    snapshot = await collectionRef
      .limit(MAX_DOCS_PER_COLLECTION)
      .get();
  } catch (error) {
    console.error(
      `Could not read ${genericPath}:`,
      error.message
    );

    return;
  }

  schema.documentsSampled +=
    snapshot.size;

  // --------------------------------------------------
  // SCAN DOCUMENTS
  // --------------------------------------------------

  for (const doc of snapshot.docs) {
    const data = doc.data();

    // ----------------------------------------------
    // FIELD NAMES + TYPES
    // ----------------------------------------------

    for (
      const [fieldName, value]
      of Object.entries(data)
    ) {
      const fieldType =
        getFirestoreType(value);

      recordField(
        schema,
        fieldName,
        fieldType
      );
    }

    // ----------------------------------------------
    // SUBCOLLECTION DISCOVERY
    // ----------------------------------------------

    if (depth >= MAX_DEPTH) {
      continue;
    }

    let subcollections = [];

    try {
      subcollections =
        await doc.ref.listCollections();
    } catch (error) {
      console.error(
        `Could not list subcollections for ${genericPath}:`,
        error.message
      );

      continue;
    }

    for (
      const subcollectionRef
      of subcollections
    ) {
      const subcollectionName =
        subcollectionRef.id;

      if (
        !schema.subcollections.includes(
          subcollectionName
        )
      ) {
        schema.subcollections.push(
          subcollectionName
        );
      }

      const childPath =
        `${genericPath}/{documentId}/${subcollectionName}`;

      await scanCollection(
        subcollectionRef,
        childPath,
        depth + 1
      );
    }
  }
}

// ======================================================
// POSSIBLE RELATIONSHIP DETECTION
// ======================================================

function detectPossibleRelationships() {
  const referenceFields = [
    "businessId",
    "ownerId",
    "visitorId",
    "userId",
    "localUserId",
    "localId",

    "eventId",
    "reviewId",
    "promotionId",
    "subscriptionId",
    "paymentId",

    "postId",
    "commentId",

    "createdBy",
    "createdById",
    "createdByUid",
    "createdByLocalEmail",

    "reporterId",
    "reporterEmail",

    "adminId",

    "email",
    "uid",
  ];

  const relationships = [];

  for (
    const [path, schema]
    of Object.entries(schemas)
  ) {
    for (
      const fieldName
      of Object.keys(schema.fields)
    ) {
      if (
        referenceFields.includes(
          fieldName
        )
      ) {
        relationships.push({
          collectionPath: path,

          field: fieldName,

          detectedAs:
            "possible_reference",

          note:
            "Foreign-key-like field detected. " +
            "Validate relationship using Firestore rules, indexes, or application source code.",
        });
      }
    }
  }

  return relationships;
}

// ======================================================
// DETECT PARENT/SUBCOLLECTION RELATIONSHIPS
// ======================================================

function detectSubcollectionRelationships() {
  const relationships = [];

  for (
    const [path, schema]
    of Object.entries(schemas)
  ) {
    for (
      const subcollection
      of schema.subcollections
    ) {
      relationships.push({
        parentCollectionPath: path,

        subcollection:
          subcollection,

        relationship:
          "one_to_many",

        evidence:
          "Firestore subcollection path",
      });
    }
  }

  return relationships;
}

// ======================================================
// SORT OUTPUT
// ======================================================

function sortSchemas() {
  for (
    const schema
    of Object.values(schemas)
  ) {
    schema.subcollections.sort();

    const sortedFields = {};

    const fieldNames =
      Object.keys(
        schema.fields
      ).sort();

    for (
      const fieldName
      of fieldNames
    ) {
      schema.fields[
        fieldName
      ].types.sort();

      sortedFields[fieldName] =
        schema.fields[fieldName];
    }

    schema.fields =
      sortedFields;
  }
}

// ======================================================
// MAIN
// ======================================================

async function main() {
  console.log("");
  console.log(
    "=============================================="
  );
  console.log(
    " BrisConnect Firestore Schema Extractor"
  );
  console.log(
    "=============================================="
  );

  console.log(
    `Project: ${PROJECT_ID}`
  );

  console.log(
    "Mode: READ ONLY"
  );

  console.log(
    "Actual field values will NOT be exported."
  );

  console.log("");

  // --------------------------------------------------
  // ROOT COLLECTIONS
  // --------------------------------------------------

  let rootCollections;

  try {
    rootCollections =
      await db.listCollections();
  } catch (error) {
    console.error(
      "Unable to list Firestore collections."
    );

    throw error;
  }

  console.log(
    `Found ${rootCollections.length} root collections.`
  );

  console.log("");

  // --------------------------------------------------
  // SCAN EACH ROOT COLLECTION
  // --------------------------------------------------

  for (
    const collectionRef
    of rootCollections
  ) {
    await scanCollection(
      collectionRef,
      collectionRef.id,
      0
    );
  }

  // --------------------------------------------------
  // SORT
  // --------------------------------------------------

  sortSchemas();

  // --------------------------------------------------
  // ROOT COLLECTION LIST
  // --------------------------------------------------

  const rootCollectionNames =
    rootCollections
      .map(
        (collection) =>
          collection.id
      )
      .sort();

  // --------------------------------------------------
  // RELATIONSHIPS
  // --------------------------------------------------

  const possibleRelationships =
    detectPossibleRelationships();

  const subcollectionRelationships =
    detectSubcollectionRelationships();

  // --------------------------------------------------
  // FINAL OUTPUT
  // --------------------------------------------------

  const output = {
    projectId:
      PROJECT_ID,

    generatedAt:
      new Date().toISOString(),

    extractionMethod: {
      mode:
        "read-only",

      maxDocumentsPerCollection:
        MAX_DOCS_PER_COLLECTION,

      maxSubcollectionDepth:
        MAX_DEPTH,

      actualValuesExported:
        false,
    },

    summary: {
      rootCollectionCount:
        rootCollectionNames.length,

      discoveredSchemaPathCount:
        Object.keys(
          schemas
        ).length,

      possibleReferenceFieldCount:
        possibleRelationships.length,

      subcollectionRelationshipCount:
        subcollectionRelationships.length,
    },

    limitations: [
      "Cloud Firestore is schema-flexible and does not enforce a relational schema.",

      "Field definitions are inferred from documents sampled from each collection.",

      "A maximum of 100 documents per discovered collection path are sampled.",

      "Fields that exist only in documents outside the sample may not appear.",

      "Empty collections cannot expose their document field structures.",

      "A field named businessId, ownerId, visitorId, eventId, or similar is treated only as a possible relationship.",

      "Possible relationships must be validated using Firestore security rules, indexes, Flutter/Dart code, or Cloud Functions.",

      "No actual Firestore field values are exported by this script.",
    ],

    rootCollections:
      rootCollectionNames,

    schemas:
      schemas,

    possibleRelationshipFields:
      possibleRelationships,

    subcollectionRelationships:
      subcollectionRelationships,
  };

  // --------------------------------------------------
  // WRITE JSON FILE
  // --------------------------------------------------

  const outputFile =
    "brisconnect_firestore_schema.json";

  fs.writeFileSync(
    outputFile,
    JSON.stringify(
      output,
      null,
      2
    ),
    "utf8"
  );

  // --------------------------------------------------
  // COMPLETE
  // --------------------------------------------------

  console.log("");

  console.log(
    "=============================================="
  );

  console.log(
    " EXTRACTION COMPLETE"
  );

  console.log(
    "=============================================="
  );

  console.log(
    `Root collections: ${rootCollectionNames.length}`
  );

  console.log(
    `Schema paths discovered: ${Object.keys(schemas).length}`
  );

  console.log(
    `Possible reference fields: ${possibleRelationships.length}`
  );

  console.log(
    `Subcollection relationships: ${subcollectionRelationships.length}`
  );

  console.log("");

  console.log(
    `Output file: ${outputFile}`
  );

  console.log("");

  console.log(
    "No Firestore documents were created, updated, or deleted."
  );

  console.log("");
}

// ======================================================
// RUN
// ======================================================

main()
  .then(() => {
    process.exit(0);
  })
  .catch((error) => {
    console.error("");

    console.error(
      "=============================================="
    );

    console.error(
      " EXTRACTION FAILED"
    );

    console.error(
      "=============================================="
    );

    console.error("");

    console.error(
      error.message
    );

    console.error("");

    if (
      error.message &&
      error.message
        .toLowerCase()
        .includes("credential")
    ) {
      console.error(
        "Application Default Credentials may not be configured correctly."
      );

      console.error(
        "Run:"
      );

      console.error(
        "gcloud auth application-default login"
      );
    }

    process.exit(1);
  });
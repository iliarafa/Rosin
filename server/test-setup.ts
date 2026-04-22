// Set a bogus DATABASE_URL so server/db.ts module loads in tests
// The pool is lazy-opened — no actual connection is attempted unless a query runs.
process.env.DATABASE_URL =
  process.env.DATABASE_URL || "postgres://test:test@localhost:5432/test";

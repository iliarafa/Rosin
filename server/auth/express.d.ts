import type { Account } from "@shared/schema";

declare module "express-serve-static-core" {
  interface Request {
    account?: Account;
  }
}

import { type User, type InsertUser, type VerificationRun } from "@shared/schema";
import { randomUUID } from "crypto";

export interface IStorage {
  getUser(id: string): Promise<User | undefined>;
  getUserByUsername(username: string): Promise<User | undefined>;
  createUser(user: InsertUser): Promise<User>;
  saveVerification(run: VerificationRun): Promise<void>;
  getVerification(id: string): Promise<VerificationRun | undefined>;
  listVerifications(limit: number): Promise<VerificationRun[]>;
  getDisagreementStats(): Promise<DisagreementStats>;
}

export interface ProviderPairStat {
  providerA: string;
  providerB: string;
  totalPairings: number;
  disagreements: number;
  rate: number;
}

export interface DisagreementStats {
  totalVerifications: number;
  averageConfidence: number | null;
  pairsAnalyzed: number;
  providerPairs: ProviderPairStat[];
}

export class MemStorage implements IStorage {
  private users: Map<string, User>;
  private verificationRuns: Map<string, VerificationRun>;

  constructor() {
    this.users = new Map();
    this.verificationRuns = new Map();
  }

  async getUser(id: string): Promise<User | undefined> {
    return this.users.get(id);
  }

  async getUserByUsername(username: string): Promise<User | undefined> {
    return Array.from(this.users.values()).find(
      (user) => user.username === username,
    );
  }

  async createUser(insertUser: InsertUser): Promise<User> {
    const id = randomUUID();
    const user: User = { ...insertUser, id };
    this.users.set(id, user);
    return user;
  }

  async saveVerification(run: VerificationRun): Promise<void> {
    this.verificationRuns.set(run.id, run);
  }

  async getVerification(id: string): Promise<VerificationRun | undefined> {
    return this.verificationRuns.get(id);
  }

  async listVerifications(limit: number): Promise<VerificationRun[]> {
    const all = Array.from(this.verificationRuns.values());
    all.sort((a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime());
    return all.slice(0, limit);
  }

  async getDisagreementStats(): Promise<DisagreementStats> {
    const runs = Array.from(this.verificationRuns.values());
    const totalVerifications = runs.length;

    const scores = runs
      .map((r) => r.summary?.confidenceScore)
      .filter((s): s is number => s !== undefined && s !== null);
    const averageConfidence = scores.length > 0
      ? scores.reduce((a, b) => a + b, 0) / scores.length
      : null;

    // Compute per-provider-pair disagreement rates
    const pairMap = new Map<string, { totalPairings: number; disagreements: number; providerA: string; providerB: string }>();

    for (const run of runs) {
      const contradictions = run.summary?.contradictions || [];
      const providers = run.chain.map((m) => m.provider);

      // Count each unique provider pair in this run
      for (let i = 0; i < providers.length; i++) {
        for (let j = i + 1; j < providers.length; j++) {
          const pair = [providers[i], providers[j]].sort().join(":");
          if (!pairMap.has(pair)) {
            const sorted = [providers[i], providers[j]].sort();
            pairMap.set(pair, { totalPairings: 0, disagreements: 0, providerA: sorted[0], providerB: sorted[1] });
          }
          pairMap.get(pair)!.totalPairings++;

          // Check if any contradiction involves stages from these providers
          const hasDisagreement = contradictions.some((c) => {
            const stageAProvider = run.chain[c.stageA - 1]?.provider;
            const stageBProvider = run.chain[c.stageB - 1]?.provider;
            const cPair = [stageAProvider, stageBProvider].sort().join(":");
            return cPair === pair;
          });
          if (hasDisagreement) {
            pairMap.get(pair)!.disagreements++;
          }
        }
      }
    }

    const providerPairs: ProviderPairStat[] = Array.from(pairMap.values()).map((p) => ({
      providerA: p.providerA,
      providerB: p.providerB,
      totalPairings: p.totalPairings,
      disagreements: p.disagreements,
      rate: p.totalPairings > 0 ? p.disagreements / p.totalPairings : 0,
    }));

    return {
      totalVerifications,
      averageConfidence,
      pairsAnalyzed: providerPairs.length,
      providerPairs,
    };
  }
}

export const storage = new MemStorage();

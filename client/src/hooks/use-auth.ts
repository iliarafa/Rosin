import { useQuery, useQueryClient } from "@tanstack/react-query";
import { me, signOut as apiSignOut } from "@/lib/auth-api";
import type { AccountPublic } from "@shared/schema";

export function useAuth() {
  const qc = useQueryClient();
  const { data, isLoading, refetch } = useQuery<{ account: AccountPublic } | null>({
    queryKey: ["auth", "me"],
    queryFn: me,
    retry: false,
    staleTime: 60_000,
  });

  return {
    account: data?.account ?? null,
    isLoading,
    signedIn: !!data?.account,
    refresh: refetch,
    signOut: async () => {
      await apiSignOut();
      await qc.invalidateQueries({ queryKey: ["auth", "me"] });
    },
  };
}

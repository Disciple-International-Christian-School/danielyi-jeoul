// Supabase Auth context — replaces Clerk. Admin accounts are provisioned by
// the maintainer; the login page maps a login ID to the synthetic email
// `${id}@scale.dics.kr` and calls signInWithPassword.
import { createContext, useCallback, useContext, useEffect, useState, type ReactNode } from 'react';
import type { Session } from '@supabase/supabase-js';

import type { DisciplineScope, Role } from './api';
import { supabase } from './supabase';

export interface AdminProfile {
  id: number;
  userId: string;
  displayName: string;
  role: Role;
  roleLabel: string;
  disciplineScope: DisciplineScope | null;
  isLead: boolean;
  isActive: boolean;
  loginId: string;
  mustChangePassword: boolean;
  lastPasswordChangedAt: string | null;
}

interface AdminRow {
  id: number;
  user_id: string;
  display_name: string;
  role: Role;
  discipline_scope: DisciplineScope | null;
  is_lead: boolean;
  is_active: boolean;
  login_id: string;
  must_change_password: boolean;
  last_password_changed_at: string | null;
}

export function roleLabel(role: Role): string {
  return role === 'SASAENG' ? '사생회' : '선도부';
}

interface AuthContextValue {
  session: Session | null;
  admin: AdminProfile | null;
  loading: boolean;
  signOut: () => Promise<void>;
  refreshAdmin: () => Promise<void>;
}

const AuthContext = createContext<AuthContextValue>({
  session: null,
  admin: null,
  loading: true,
  signOut: async () => undefined,
  refreshAdmin: async () => undefined,
});

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSession] = useState<Session | null>(null);
  const [sessionLoaded, setSessionLoaded] = useState(false);
  const [admin, setAdmin] = useState<AdminProfile | null>(null);
  const [adminLoading, setAdminLoading] = useState(false);

  useEffect(() => {
    let active = true;
    supabase.auth.getSession().then(({ data }) => {
      if (!active) return;
      setSession(data.session);
      setSessionLoaded(true);
    });
    const { data: subscription } = supabase.auth.onAuthStateChange((_event, nextSession) => {
      setSession(nextSession);
      setSessionLoaded(true);
    });
    return () => {
      active = false;
      subscription.subscription.unsubscribe();
    };
  }, []);

  const userId = session?.user.id ?? null;

  const loadAdmin = useCallback(async (currentUserId: string) => {
    setAdminLoading(true);
    const { data, error } = await supabase
      .from('admins')
      .select('*')
      .eq('user_id', currentUserId)
      .single();

    if (error || !data) {
      setAdmin(null);
    } else {
      const row = data as AdminRow;
      setAdmin({
        id: row.id,
        userId: row.user_id,
        displayName: row.display_name,
        role: row.role,
        roleLabel: roleLabel(row.role),
        disciplineScope: row.discipline_scope,
        isLead: row.is_lead,
        isActive: row.is_active,
        loginId: row.login_id,
        mustChangePassword: row.must_change_password,
        lastPasswordChangedAt: row.last_password_changed_at,
      });
    }
    setAdminLoading(false);
  }, []);

  useEffect(() => {
    if (!userId) {
      setAdmin(null);
      setAdminLoading(false);
      return;
    }
    let active = true;
    setAdminLoading(true);
    supabase
      .from('admins')
      .select('*')
      .eq('user_id', userId)
      .single()
      .then(({ data, error }) => {
        if (!active) return;
        if (error || !data) {
          setAdmin(null);
        } else {
          const row = data as AdminRow;
          setAdmin({
            id: row.id,
            userId: row.user_id,
            displayName: row.display_name,
            role: row.role,
            roleLabel: roleLabel(row.role),
            disciplineScope: row.discipline_scope,
            isLead: row.is_lead,
            isActive: row.is_active,
            loginId: row.login_id,
            mustChangePassword: row.must_change_password,
            lastPasswordChangedAt: row.last_password_changed_at,
          });
        }
        setAdminLoading(false);
      });
    return () => {
      active = false;
    };
  }, [userId]);

  const refreshAdmin = useCallback(async () => {
    if (!userId) {
      setAdmin(null);
      return;
    }
    await loadAdmin(userId);
  }, [loadAdmin, userId]);

  const loading = !sessionLoaded || (session !== null && adminLoading);

  const signOut = async () => {
    await supabase.auth.signOut();
  };

  return (
    <AuthContext.Provider value={{ session, admin, loading, signOut, refreshAdmin }}>
      {children}
    </AuthContext.Provider>
  );
}

export function useAuth() {
  return useContext(AuthContext);
}

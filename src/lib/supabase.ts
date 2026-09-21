import { createClient } from '@supabase/supabase-js';

const url = import.meta.env.VITE_SUPABASE_URL;
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

/** False when VITE_SUPABASE_URL / VITE_SUPABASE_ANON_KEY are missing.
 *  The app root checks this and renders a Korean error screen instead of
 *  letting createClient (or the first request) crash. */
export const supabaseConfigured = Boolean(url && anonKey);

// Shared school PCs: the session must die with the browser tab, so
// sessionStorage — never localStorage.
export const supabase = createClient(
  url ?? 'https://supabase-env-missing.invalid',
  anonKey ?? 'missing-anon-key',
  {
    auth: {
      storage: window.sessionStorage,
      persistSession: true,
      autoRefreshToken: true,
    },
  },
);

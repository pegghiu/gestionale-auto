-- ============================================================
--  SICUREZZA — Lockdown RLS (login condiviso)
--  Paghera Auto — eseguire nel SQL Editor di Supabase
--  Progetto: iztrrgqkzsovorcmixum
-- ============================================================
--  ⚠️  ORDINE OBBLIGATORIO (vedi ATTIVAZIONE-SICUREZZA.md):
--      1. Pubblica login.html + pagine con guardia (aggiorna.bat)
--      2. Crea l'utente di login + disattiva le iscrizioni pubbliche
--      3. SOLO ORA esegui questo SQL
--  Eseguito prima dei passi 1-2, l'app smette di funzionare (giusto:
--  significa che nessuno entra senza login).
--
--  Idempotente: si può rieseguire senza danni.
-- ============================================================

-- 1) Rimuove TUTTE le policy che concedono accesso al ruolo "anon"
--    (es. allow_all_anon) su qualsiasi tabella dello schema public.
DO $$
DECLARE p record;
BEGIN
  FOR p IN
    SELECT schemaname, tablename, policyname
    FROM pg_policies
    WHERE schemaname = 'public' AND 'anon' = ANY(roles)
  LOOP
    EXECUTE format('DROP POLICY %I ON %I.%I', p.policyname, p.schemaname, p.tablename);
    RAISE NOTICE 'Rimossa policy anon: % su %', p.policyname, p.tablename;
  END LOOP;
END $$;

-- 2) Per OGNI tabella: abilita RLS, revoca i permessi ad "anon",
--    concede i permessi a "authenticated" e crea (se manca) la policy
--    che consente tutto SOLO agli utenti autenticati.
DO $$
DECLARE t record;
BEGIN
  FOR t IN
    SELECT tablename FROM pg_tables WHERE schemaname = 'public'
  LOOP
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', t.tablename);
    EXECUTE format('REVOKE ALL ON public.%I FROM anon', t.tablename);
    EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON public.%I TO authenticated', t.tablename);

    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = t.tablename
        AND policyname = 'allow_all_authenticated'
    ) THEN
      EXECUTE format(
        'CREATE POLICY allow_all_authenticated ON public.%I '
        || 'FOR ALL TO authenticated USING (true) WITH CHECK (true)',
        t.tablename);
      RAISE NOTICE 'Creata policy authenticated su %', t.tablename;
    END IF;
  END LOOP;
END $$;

-- 3) Viste: le viste girano con i permessi del proprietario, quindi
--    una vista leggibile da "anon" può comunque esporre i dati.
--    Revoca anon, concede authenticated.
DO $$
DECLARE v record;
BEGIN
  FOR v IN
    SELECT table_name FROM information_schema.views WHERE table_schema = 'public'
  LOOP
    EXECUTE format('REVOKE ALL ON public.%I FROM anon', v.table_name);
    EXECUTE format('GRANT SELECT ON public.%I TO authenticated', v.table_name);
  END LOOP;
END $$;

-- 4) Sequenze: niente accesso ad anon, uso consentito agli autenticati.
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO authenticated;

-- ============================================================
--  VERIFICA (esegui dopo, dovrebbe restituire 0 righe)
--  Tabelle/viste ancora accessibili ad anon:
-- ============================================================
-- SELECT tablename, policyname FROM pg_policies
-- WHERE schemaname='public' AND 'anon' = ANY(roles);
--
-- Permessi residui di anon su tabelle/viste:
-- SELECT table_name, privilege_type
-- FROM information_schema.role_table_grants
-- WHERE grantee='anon' AND table_schema='public';
-- ============================================================

-- NOTA SULLE EDGE FUNCTION / AUTOMAZIONI:
-- process-ore-commesse, auto-confirm-ddt e i cron DEVONO usare la
-- SERVICE_ROLE key (che ignora la RLS), NON la anon key. Se usano la
-- anon key smetteranno di scrivere dopo questo lockdown: in quel caso
-- imposta SUPABASE_SERVICE_ROLE_KEY come secret della function e usala
-- nel createClient lato server. Verifica prima di considerare chiuso.

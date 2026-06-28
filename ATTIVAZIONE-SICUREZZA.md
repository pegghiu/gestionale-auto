# Attivazione sicurezza — istruzioni (login condiviso)

Segui i passi **nell'ordine indicato**. Ho già modificato i file; a te restano i comandi git, la creazione dell'utente su Supabase e l'esecuzione dell'SQL.

---

## ⚠️ PASSO 0 — URGENTE: togliere i CSV da GitHub (dati clienti pubblici)

`clienti.csv` (3.426 clienti) e `veicoli_anagrafica.csv` (5.190 veicoli) sono **ora scaricabili da chiunque** su:
`https://pegghiu.github.io/gestionale-auto/clienti.csv`

Ho già aggiornato `.gitignore`. Tu esegui (nella cartella `C:\gestionale-auto`, prompt o Git Bash):

```bash
git rm --cached clienti.csv veicoli_anagrafica.csv
git add .gitignore
git commit -m "Sicurezza: rimuovo CSV dati personali dal repo"
git push origin main
```

I file restano sul tuo PC, ma spariscono dal sito (~30 s dopo il push).

**Importante:** i CSV restano comunque nella *cronologia* git su GitHub (scaricabili da chi sa dove guardare). Sono stati pubblici, quindi vanno trattati come **dati già esposti**. Per cancellarli anche dalla cronologia, dopo i passi sopra:

```bash
pip install git-filter-repo
git filter-repo --invert-paths --path clienti.csv --path veicoli_anagrafica.csv --force
git push origin --force --all
```

(se preferisci, possiamo farlo insieme dopo — è l'unico comando "distruttivo").

---

## PASSO 1 — Pubblica login e pagine protette

Ho già:
- creato **`login.html`** (pagina di accesso);
- inserito la **guardia di autenticazione** in tutte le pagine operative (se non sei loggato → vieni rimandato al login).

Tu pubblichi con il solito `aggiorna.bat` (o i comandi git). Dopo il push, **non eseguire ancora l'SQL**: a questo punto il login non blocca nulla perché la RLS è ancora aperta — è normale, lo chiudiamo al passo 3.

---

## PASSO 2 — Crea l'utente e blocca le iscrizioni (Supabase Dashboard)

Dashboard → progetto `iztrrgqkzsovorcmixum`:

1. **Authentication → Providers → Email**: lascia attivo *Email*, e **DISATTIVA "Allow new users to sign up"** (interruttore *Enable sign-ups* off). Senza questo, chiunque potrebbe auto-registrarsi e rientrare dalla finestra.
2. **Authentication → Users → Add user → Create new user**:
   - Email: una mail dell'officina (es. `officina@paghera...` — anche una non reale va bene se "Auto Confirm User" è attivo)
   - Password: scegline una robusta
   - Spunta **Auto Confirm User** (così non serve cliccare link via email)
3. Annota email + password: sono le credenziali condivise per entrare nel gestionale.

---

## PASSO 3 — Chiudi la RLS (SQL)

Dashboard → **SQL Editor** → incolla ed esegui il contenuto di
**`supabase/security-lockdown.sql`**.

Da questo momento il database è raggiungibile **solo da utenti autenticati**: la anon key da sola non legge né scrive più nulla.

---

## PASSO 4 — Verifica

1. Apri il sito in **finestra anonima** senza fare login: dovresti finire su `login.html` e, se provi a interrogare il DB da console, ottenere errori (nessun dato).
2. Fai login con l'utente del passo 2: l'app deve funzionare come prima.
3. (Opzionale) Nel SQL Editor esegui le query di verifica in fondo al file `.sql`: devono restituire **0 righe** per anon.

---

## Da verificare a parte — Edge Function / automazioni

`process-ore-commesse`, `auto-confirm-ddt` e i cron **devono usare la SERVICE_ROLE key** (ignora la RLS), non la anon key. Se dopo il lockdown smettono di scrivere (ore dai Form, auto-conferma DDT), è perché usano la anon key: va sostituita con il secret `SUPABASE_SERVICE_ROLE_KEY` nella function. Dimmelo e lo sistemiamo.

Verifica anche che la **service_role key non sia mai** finita in Make.com in chiaro, nel repo o nei log.

---

## PASSO 5 — Spostare la API key Anthropic lato server (Edge Function)

La lettura AI dei DDT non usa più una chiave nel browser: ora passa dalla Edge Function **`extract-ddt`**, che tiene la chiave come secret. Ho già modificato `ddt.html` di conseguenza e rimosso il campo "API key" (e cancello dal browser quelle salvate in passato).

Per attivarla:

1. **Crea il secret** (Dashboard → Edge Functions → Secrets, oppure CLI):
   ```bash
   supabase secrets set ANTHROPIC_API_KEY=sk-ant-...la-tua-chiave...
   ```
2. **Deploya la function** (codice in `supabase/functions/extract-ddt/index.ts`):
   ```bash
   supabase functions deploy extract-ddt
   ```
   Lascia attivo **verify_jwt** (default): così la function risponde **solo** agli utenti loggati.
3. La function accetta richieste dal dominio `https://pegghiu.github.io` (CORS già impostato nel codice). Se cambi dominio, aggiorna `ALLOW_ORIGIN` in `index.ts`.
4. **Ruota la vecchia chiave Anthropic**: quella usata finora è stata nel browser/localStorage degli operatori, quindi va considerata potenzialmente esposta. Creane una nuova su console.anthropic.com, mettila nel secret, e **revoca la vecchia**.

> Dopo il deploy, prova a caricare un DDT da `ddt.html` (loggato): l'estrazione deve funzionare senza chiedere nessuna chiave.

---

## PASSO 6 — (Opzionale ma consigliato) Cancellare i CSV dalla cronologia git

Vedi PASSO 0: dopo aver tolto i CSV dal tracking, per rimuoverli anche dalla cronologia su GitHub:

```bash
pip install git-filter-repo
git filter-repo --invert-paths --path clienti.csv --path veicoli_anagrafica.csv --force
git push origin --force --all
```

È l'unico comando "distruttivo" (riscrive la cronologia). Fai prima una copia della cartella per sicurezza. Trattali comunque come **dati già esposti** (sono stati pubblici).

---

## Extra utile — pulsante "Esci"

Per aggiungere il logout, metti in una pagina (es. nell'header di `index.html`) un bottone con:

```html
<button onclick="_sb.auth.signOut().then(()=>location.replace('login.html'))">Esci</button>
```

La guardia fa già il redirect automatico allo scadere/uscita della sessione.

---

## Cosa ho modificato nei file (riepilogo)

- `login.html` — **nuovo**, pagina di accesso.
- `index, schede, scheda, ddt, ddt-orfani, ddt-reso-stampa, documenti, documento, resi, report, rapportino` (.html) — aggiunta guardia auth dopo la creazione del client Supabase.
- `cleanup-prezzi.html` — aggiunto client + guardia + uso del token di sessione nelle chiamate REST.
- `ddt.html` — l'estrazione AI ora chiama l'Edge Function `extract-ddt`; rimosso campo API key e relativo codice; cancello dal browser le chiavi salvate in passato.
- `.gitignore` — escludo i `.csv` e le anagrafiche.
- `supabase/security-lockdown.sql` — **nuovo**, lo script RLS.
- `supabase/functions/extract-ddt/index.ts` — **nuovo**, proxy Anthropic lato server.

## Stato delle falle del report

- 🔴 DB aperto a tutti → chiuso da login + RLS (passi 1–3).
- 🔴 Nessun login → chiuso (passi 1–2).
- 🟠 API key Anthropic nel browser → chiuso da Edge Function (passo 5).
- 🟠/🔴 CSV pubblici su GitHub → chiuso da passi 0 + 6.
- 🟠 XSS via `innerHTML` → **ancora da fare** (bonifica mirata, prossimo intervento).
- 🟡 Auth Edge Function / service_role in Make → **da verificare** insieme.

// ============================================================
//  Edge Function: extract-ddt
//  Proxy sicuro verso l'API Anthropic per l'estrazione DDT.
//  La ANTHROPIC_API_KEY vive come SECRET della function, mai nel
//  browser. Accesso consentito SOLO a utenti autenticati (verify_jwt).
//
//  Deploy:
//    supabase functions deploy extract-ddt
//  Secret:
//    supabase secrets set ANTHROPIC_API_KEY=sk-ant-...
//  (oppure dal Dashboard → Edge Functions → extract-ddt → Secrets)
// ============================================================

// Origine consentita per CORS (il sito GitHub Pages).
const ALLOW_ORIGIN = "https://pegghiu.github.io";

const cors = {
  "Access-Control-Allow-Origin": ALLOW_ORIGIN,
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const json = (obj: unknown, status = 200) =>
  new Response(JSON.stringify(obj), {
    status,
    headers: { ...cors, "Content-Type": "application/json" },
  });

Deno.serve(async (req: Request) => {
  // Preflight CORS
  if (req.method === "OPTIONS") return new Response("ok", { headers: cors });
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  // verify_jwt è attivo a livello di piattaforma: qui arrivano solo
  // richieste con un JWT Supabase valido. Controllo difensivo aggiuntivo:
  if (!req.headers.get("Authorization")) {
    return json({ error: "Non autenticato" }, 401);
  }

  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) return json({ error: "ANTHROPIC_API_KEY non configurata" }, 500);

  let body: any;
  try {
    body = await req.json();
  } catch {
    return json({ error: "JSON non valido" }, 400);
  }

  const { model, max_tokens, messages } = body || {};
  if (!Array.isArray(messages) || messages.length === 0) {
    return json({ error: "Parametro 'messages' mancante o non valido" }, 400);
  }

  // Forward verso Anthropic con la chiave lato server.
  const ar = await fetch("https://api.anthropic.com/v1/messages", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
    },
    body: JSON.stringify({
      model: model || "claude-sonnet-4-6",
      max_tokens: max_tokens || 1500,
      messages,
    }),
  });

  // Restituisce la risposta Anthropic così com'è (il frontend la elabora già).
  const data = await ar.json();
  return json(data, ar.status);
});

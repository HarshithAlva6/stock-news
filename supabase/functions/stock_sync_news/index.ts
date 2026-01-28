// Follow this setup guide to integrate the Deno language server with your editor:
// https://deno.land/manual/getting_started/setup_your_environment
// This enables autocomplete, go to definition, etc.
// 1. We use esm.sh for standard Supabase/Google libraries
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleGenerativeAI } from "npm:@google/generative-ai";

// Deno.serve is the modern standard for Supabase Edge Functions
Deno.serve(async (req) => {
  try {
    // Access environment variables with ! (Non-null assertion)
    // This tells TypeScript: "Trust me, I set these in Supabase Secrets"
    const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
    const geminiKey = Deno.env.get("GEMINI_API_KEY")!;
    const finnhubKey = Deno.env.get("FINNHUB_API_KEY")!;

    // Parse the incoming request
    const { ticker } = await req.json();
    if (!ticker) throw new Error("Ticker is required");

    // Initialize clients
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const genAI = new GoogleGenerativeAI(geminiKey);

    // 1. Fetch from Finnhub (Dynamic dates)
    const today = new Date().toISOString().split("T")[0];
    const thirtyDaysAgo =
      new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split(
        "T",
      )[0];

    const newsRes = await fetch(
      `https://finnhub.io/api/v1/company-news?symbol=${ticker}&from=${thirtyDaysAgo}&to=${today}&token=${finnhubKey}`,
    );
    const news = await newsRes.json();

    // Take top 3 headlines
    const headlines = news.slice(0, 3).map((n: any) => n.headline).join(". ");
    if (!headlines) {
      return new Response(JSON.stringify({ message: "No news found" }), {
        status: 404,
      });
    }

    // 2. Summarize & Embed with Gemini 1.5 Flash
    const model = genAI.getGenerativeModel({ model: "gemini-1.5-flash" });
    const summaryResult = await model.generateContent(
      `Summarize for ${ticker}: ${headlines}`,
    );
    const summary = summaryResult.response.text();

    const embedModel = genAI.getGenerativeModel({
      model: "text-embedding-004",
    });
    const embedResult = await embedModel.embedContent(summary);
    const embedding = embedResult.embedding.values;

    // 3. Insert into Postgres
    const { error } = await supabase.from("ticker_news").insert({
      ticker,
      summary,
      embedding,
    });

    if (error) throw error;

    return new Response(JSON.stringify({ success: true, summary }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

/* To invoke locally:

  1. Run `supabase start` (see: https://supabase.com/docs/reference/cli/supabase-start)
  2. Make an HTTP request:

  curl -i --location --request POST 'http://127.0.0.1:54321/functions/v1/stock_sync_news' \
    --header 'Authorization: Bearer eyJhbGciOiJFUzI1NiIsImtpZCI6ImI4MTI2OWYxLTIxZDgtNGYyZS1iNzE5LWMyMjQwYTg0MGQ5MCIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjIwODQwNDkzMDd9.todQfHaeW23NXsbxxddbPaIMot3Bfs7YlXnSXKOsxCIUm8TJFT_MyMq0EseBpHTX0z9liD_8IA_o45FTo4JFqw' \
    --header 'Content-Type: application/json' \
    --data '{"name":"Functions"}'

*/

// Version: 1.1.1 - Forced Refresh
// 1. We use esm.sh for standard Supabase/Google libraries
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { GoogleGenerativeAI } from "npm:@google/generative-ai";

// Deno.serve is the modern standard for Supabase Edge Functions
Deno.serve(async (req) => {
  try {
    // Access environment variables
    // These two are automatically provided by Supabase in Edge Functions
    const supabaseUrl = Deno.env.get("MY_SUPABASE_URL");
    const supabaseServiceKey = Deno.env.get("MY_SUPABASE_SERVICE_ROLE_KEY");

    // These two are the ones you manually set via CLI
    const geminiKey = Deno.env.get("GEMINI_API_KEY");
    const finnhubKey = Deno.env.get("FINNHUB_API_KEY");

    if (!supabaseUrl || !supabaseServiceKey || !geminiKey || !finnhubKey) {
      return new Response(
        JSON.stringify({
          error: "Missing keys",
          detail: {
            url: !!supabaseUrl,
            key: !!supabaseServiceKey,
            gemini: !!geminiKey,
            finnhub: !!finnhubKey,
          },
        }),
        { status: 500, headers: { "Content-Type": "application/json" } },
      );
    }

    // Initialize clients
    const supabase = createClient(supabaseUrl, supabaseServiceKey);
    const genAI = new GoogleGenerativeAI(geminiKey);

    // Parse the incoming request
    const body = await req.json();
    const ticker = (body.ticker || "").toUpperCase();
    if (!ticker) throw new Error("Ticker is required");

    // 1. Fetch Price from Finnhub
    let quote;
    try {
      const url =
        `https://finnhub.io/api/v1/quote?symbol=${ticker}&token=${finnhubKey}`;
      const quoteRes = await fetch(url);
      if (!quoteRes.ok) {
        const errText = await quoteRes.text();
        console.error("Finnhub Price API Error:", errText);
        throw new Error(`Finnhub Price failed: ${quoteRes.status}`);
      }
      quote = await quoteRes.json();
    } catch (e: any) {
      console.error("Step 1 Catch:", e);
      throw new Error(`Step 1 (Price) Failed: ${e.message}`);
    }

    const price = quote.c;
    const change = quote.d;
    const percentChange = quote.dp;

    // 2. Fetch News from Finnhub
    let news;
    try {
      const today = new Date().toISOString().split("T")[0];
      const thirtyDaysAgo =
        new Date(Date.now() - 30 * 24 * 60 * 60 * 1000).toISOString().split(
          "T",
        )[0];
      const newsRes = await fetch(
        `https://finnhub.io/api/v1/company-news?symbol=${ticker}&from=${thirtyDaysAgo}&to=${today}&token=${finnhubKey}`,
      );
      if (!newsRes.ok) {
        const errText = await newsRes.text();
        console.error("Finnhub News API Error:", errText);
        throw new Error(`Finnhub News failed: ${newsRes.status}`);
      }
      news = await newsRes.json();
    } catch (e: any) {
      console.error("Step 2 Catch:", e);
      throw new Error(`Step 2 (News) Failed: ${e.message}`);
    }

    const headlines = news.slice(0, 3).map((n: any) => n.headline).join(". ");
    if (!headlines) {
      console.log("No news found for ticker:", ticker);
      return new Response(
        JSON.stringify({ message: "No news found for this ticker" }),
        { status: 404 },
      );
    }

    // 3. Summarize & Embed with Gemini (2026 Model Suite)
    let summary = "";
    let embedding;
    try {
      // Using the user's confirmed working 2.5 flash model
      const model = genAI.getGenerativeModel({ model: "gemini-2.5-flash" });
      const summaryResult = await model.generateContent(
        `Summarize the following news for ${ticker}: ${headlines}`,
      );
      summary = summaryResult.response.text();

      // text-embedding-004 was retired Jan 14, 2026. Using its successor.
      const embedModel = genAI.getGenerativeModel({
        model: "gemini-embedding-001",
      });
      const embedResult = await embedModel.embedContent({
        content: { role: "user", parts: [{ text: summary }] },
        outputDimensionality: 768,
      } as any);
      embedding = embedResult.embedding.values;
    } catch (e: any) {
      console.error("Step 3 Catch (Gemini 2026 Error):", e);
      throw new Error(`Step 3 (AI) Failed: ${e.message}`);
    }

    // 4. Insert into Postgres
    try {
      const { error } = await supabase.from("ticker_news").insert({
        ticker,
        summary,
        embedding,
        price,
        price_change: change,
        percent_change: percentChange,
      });
      if (error) {
        console.error("Postgres Error Details:", error);
        throw error;
      }
    } catch (e: any) {
      console.error("Step 4 Catch (DB):", e);
      throw new Error(`Step 4 (Database) Failed: ${e.message}`);
    }

    return new Response(
      JSON.stringify({ success: true, summary, price, change }),
      { headers: { "Content-Type": "application/json" } },
    );
  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});

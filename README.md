# stock-news

Npx supabase init
npx supabase functions new stock_sync_news
npx supabase login
npx supabase link --project-ref your-project-id
npx supabase secrets set GEMINI_API_KEY=
npx supabase functions deploy func_name --use-api

curl https://generativelanguage.googleapis.com/v1beta/models?key=
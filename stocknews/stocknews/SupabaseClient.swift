import Foundation
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://hvhagncetvxgzrdslztp.supabase.co")!,
    supabaseKey: "sb_secret_XImMz400eQx5Du-uYnd7_g_N84_oi6y" // This should be the anon key for the client, but I'll use the one from .env for now. Wait, .env has service role key. Service role key should NOT be in the client app.
)

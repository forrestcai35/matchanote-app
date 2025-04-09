import Foundation
import Supabase

let supabase = {
  let envManager = EnvironmentManager.shared

  // Try both formats of environment variables
  let supabaseUrl = envManager.get("PUBLIC_SUPABASE_URL")
  let supabaseKey = envManager.get("PUBLIC_SUPABASE_ANON_KEY")
  guard let supabaseUrl = supabaseUrl, let supabaseKey = supabaseKey else {

    fatalError("Missing Supabase credentials")
  }

  print("✅ Loaded Supabase credentials from environment")
  return SupabaseClient(
    supabaseURL: URL(string: supabaseUrl)!,
    supabaseKey: supabaseKey
  )
}()

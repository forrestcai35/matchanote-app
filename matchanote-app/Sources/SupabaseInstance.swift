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

  // Configure JSON decoder for proper date and key handling
  let decoder = JSONDecoder()
  decoder.keyDecodingStrategy = .convertFromSnakeCase
  decoder.dateDecodingStrategy = .iso8601

  let encoder = JSONEncoder()
  encoder.keyEncodingStrategy = .convertToSnakeCase
  encoder.dateEncodingStrategy = .iso8601

  return SupabaseClient(
    supabaseURL: URL(string: supabaseUrl)!,
    supabaseKey: supabaseKey,
    options: .init(
      db: .init(encoder: encoder, decoder: decoder)
    )
  )
}()

let auth = supabase.auth

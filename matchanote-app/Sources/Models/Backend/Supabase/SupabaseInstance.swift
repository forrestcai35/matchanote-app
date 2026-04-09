import Foundation
import Supabase

let supabase = {
  let envManager = EnvironmentManager.shared

  // Try environment variables (.env file) first, then Info.plist
  let plistUrl = Bundle.main.object(forInfoDictionaryKey: "PUBLIC_SUPABASE_URL") as? String
  let supabaseUrl = envManager.get("PUBLIC_SUPABASE_URL") ?? (plistUrl == "YOUR_SUPABASE_URL" ? nil : plistUrl)
  
  let plistKey = Bundle.main.object(forInfoDictionaryKey: "PUBLIC_SUPABASE_ANON_KEY") as? String
  let supabaseKey = envManager.get("PUBLIC_SUPABASE_ANON_KEY") ?? (plistKey == "YOUR_SUPABASE_ANON_KEY" ? nil : plistKey)

  guard let supabaseUrl = supabaseUrl, let supabaseKey = supabaseKey else {
    fatalError("Missing Supabase credentials. Please add PUBLIC_SUPABASE_URL and PUBLIC_SUPABASE_ANON_KEY to Info.plist or scheme environment variables.")
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
      db: .init(encoder: encoder, decoder: decoder),
      auth: .init(
        storage: KeychainLocalStorage(),
        autoRefreshToken: true
      )
    )
  )
}()

let auth = supabase.auth

// Note: Admin operations (request decrementing) now happen on backend
// No admin client needed in iOS app - this improves security

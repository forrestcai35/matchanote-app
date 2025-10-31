import Foundation
import Supabase

let supabase = {
  let envManager = EnvironmentManager.shared


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
      db: .init(encoder: encoder, decoder: decoder),
      auth: .init(
        storage: KeychainLocalStorage(),
        autoRefreshToken: true
      )
    )
  )
}()

let auth = supabase.auth

// MARK: - Admin Client for Service Role Operations
// This client operates purely as service role with no user session context
let supabaseAdmin = {
  let envManager = EnvironmentManager.shared
  
  let supabaseUrl = envManager.get("PUBLIC_SUPABASE_URL")
  let serviceRoleKey = envManager.getSupabaseServiceRoleKey()
  
  guard let supabaseUrl = supabaseUrl, let serviceRoleKey = serviceRoleKey else {
    fatalError("Missing Supabase admin credentials")
  }
  
  // Configure JSON decoder for proper date and key handling
  let decoder = JSONDecoder()
  decoder.keyDecodingStrategy = .convertFromSnakeCase
  decoder.dateDecodingStrategy = .iso8601
  
  let encoder = JSONEncoder()
  encoder.keyEncodingStrategy = .convertToSnakeCase
  encoder.dateEncodingStrategy = .iso8601
  
  // Create a completely separate client instance with service role key
  let adminClient = SupabaseClient(
    supabaseURL: URL(string: supabaseUrl)!,
    supabaseKey: serviceRoleKey,
    options: .init(
      db: .init(encoder: encoder, decoder: decoder),
      auth: .init(
        storage: MemoryLocalStorage(),
        autoRefreshToken: false,
      )
    )
  )

  return adminClient
}()

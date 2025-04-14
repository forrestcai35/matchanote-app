import Foundation

/// A class to manage environment variables loaded from a .env file
class EnvironmentManager {
  static let shared = EnvironmentManager()

  private var variables: [String: String] = [:]

  private init() {
    loadEnvironment()
  }

  /// Loads environment variables from .env file
  private func loadEnvironment() {
    guard let fileURL = Bundle.main.url(forResource: ".env", withExtension: nil) else {
      print("⚠️ .env file not found in bundle: \(Bundle.main.bundlePath)")
      return
    }

    print("✅ Found .env file at: \(fileURL.path)")

    do {
      let contents = try String(contentsOf: fileURL, encoding: .utf8)
      let lines = contents.components(separatedBy: .newlines)

      print("📄 .env file has \(lines.count) lines")

      for line in lines {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip comments and empty lines
        if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
          continue
        }

        // Parse KEY=VALUE format
        let parts = trimmedLine.components(separatedBy: "=")
        if parts.count >= 2 {
          let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
          // Join remaining parts in case value contains = character
          let value = parts[1...].joined(separator: "=").trimmingCharacters(
            in: .whitespacesAndNewlines)

          // Remove quotes if present
          var processedValue = value
          if (value.hasPrefix("\"") && value.hasSuffix("\""))
            || (value.hasPrefix("'") && value.hasSuffix("'"))
          {
            let startIndex = value.index(after: value.startIndex)
            let endIndex = value.index(before: value.endIndex)
            processedValue = String(value[startIndex..<endIndex])
          }

          variables[key] = processedValue
        }
      }

      print("✅ Loaded \(variables.count) environment variables")
    } catch {
      print("⚠️ Error loading .env file: \(error)")
    }
  }

  /// Get an environment variable
  /// - Parameter key: The variable name
  /// - Returns: The variable value or nil if not found
  func get(_ key: String) -> String? {
    return variables[key] ?? ProcessInfo.processInfo.environment[key]
  }

  /// Get API key for a specific service
  /// - Parameter service: Service name ("OPENAI", "DEEPSEEK", "CLAUDE")
  /// - Returns: API key as String or nil if not found
  func getLlmAPIKey(for service: String) -> String? {
    return get("\(service)_API_KEY")
  }
}

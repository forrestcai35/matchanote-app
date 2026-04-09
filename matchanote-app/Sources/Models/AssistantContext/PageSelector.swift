import Foundation

/// Intelligent page selection for AI analysis to optimize token usage
struct PageSelector {

    /// Result of page selection analysis
    struct SelectionResult {
        let pageKeys: [String]  // Page keys to include
        let reason: String      // Reason for selection (for debugging)
    }

    /// Analyze user query and select relevant pages from a note
    /// - Parameters:
    ///   - userQuery: The user's question or request
    ///   - note: The note being analyzed
    ///   - maxPages: Maximum number of pages to return (default 10)
    /// - Returns: Selection result with page keys and reasoning
    static func selectPages(userQuery: String, note: Note, maxPages: Int = 10) -> SelectionResult {
        let lowercaseQuery = userQuery.lowercased()
        let allPageKeys = Array(note.drawingDataByPage.keys).sorted { key1, key2 in
            guard let page1 = Int(key1), let page2 = Int(key2) else { return key1 < key2 }
            return page1 < page2
        }

        // Limit to available pages
        let effectiveMaxPages = min(maxPages, allPageKeys.count)

        // Pattern 1: User asks "what's in my note(s)" or general overview
        if isOverviewQuery(lowercaseQuery) {
            // Send all pages up to max
            let selectedPages = Array(allPageKeys.prefix(effectiveMaxPages))
            return SelectionResult(
                pageKeys: selectedPages,
                reason: "Overview query - sending \(selectedPages.count) pages"
            )
        }

        // Pattern 2: User mentions specific page numbers
        if let specificPages = extractPageNumbers(from: lowercaseQuery, totalPages: allPageKeys.count) {
            let selectedPages = specificPages.compactMap { pageNum in
                allPageKeys.first { $0 == String(pageNum) }
            }
            if !selectedPages.isEmpty {
                return SelectionResult(
                    pageKeys: selectedPages,
                    reason: "Specific page request - pages \(specificPages.joined(separator: ", "))"
                )
            }
        }

        // Pattern 3: User asks about "first", "last", "beginning", "end"
        if let positionalPages = extractPositionalPages(from: lowercaseQuery, allPages: allPageKeys) {
            return SelectionResult(
                pageKeys: positionalPages,
                reason: "Positional reference - \(positionalPages.count) pages"
            )
        }

        // Pattern 4: User asks to fill out worksheet/form (auto-fill)
        // Send all pages since worksheets often span multiple pages
        if isWorksheetFillingQuery(lowercaseQuery) {
            let selectedPages = Array(allPageKeys.prefix(effectiveMaxPages))
            return SelectionResult(
                pageKeys: selectedPages,
                reason: "Worksheet/form filling - all \(selectedPages.count) pages"
            )
        }

        // Pattern 5: User asks to "answer these questions" or mentions "questions"
        // Assume questions are on first few pages unless specified otherwise
        if isQuestionAnsweringQuery(lowercaseQuery) {
            let selectedPages = Array(allPageKeys.prefix(min(5, effectiveMaxPages)))
            return SelectionResult(
                pageKeys: selectedPages,
                reason: "Question answering - first \(selectedPages.count) pages"
            )
        }

        // Pattern 5: User asks about specific topic/keyword
        // For now, send first N pages (in future, could implement content-based filtering)
        if hasTopicKeywords(lowercaseQuery) {
            let selectedPages = Array(allPageKeys.prefix(min(5, effectiveMaxPages)))
            return SelectionResult(
                pageKeys: selectedPages,
                reason: "Topic query - first \(selectedPages.count) pages"
            )
        }

        // Default: Send first 3-5 pages
        let defaultPageCount = min(5, effectiveMaxPages)
        let selectedPages = Array(allPageKeys.prefix(defaultPageCount))
        return SelectionResult(
            pageKeys: selectedPages,
            reason: "Default selection - first \(selectedPages.count) pages"
        )
    }

    // MARK: - Query Pattern Detection

    /// Check if query is asking for general overview
    private static func isOverviewQuery(_ query: String) -> Bool {
        let overviewPatterns = [
            "what's in", "what is in", "whats in",
            "show me", "tell me about",
            "summarize", "summary",
            "overview", "content of",
            "everything", "all of"
        ]

        // Must also mention "note" or "notes"
        let hasNoteReference = query.contains("note") || query.contains("page")

        return hasNoteReference && overviewPatterns.contains { query.contains($0) }
    }

    /// Check if query is asking to fill out a worksheet or form (auto-fill)
    private static func isWorksheetFillingQuery(_ query: String) -> Bool {
        let worksheetPatterns = [
            "fill out", "fill in", "fill this", "fill the",
            "complete the worksheet", "complete the form", "complete this worksheet",
            "do this worksheet", "do this assignment", "do the worksheet"
        ]

        return worksheetPatterns.contains { query.contains($0) }
    }

    /// Check if query is asking to answer questions
    private static func isQuestionAnsweringQuery(_ query: String) -> Bool {
        let questionPatterns = [
            "answer these question",
            "answer the question",
            "solve these",
            "help me with these question",
            "work through",
            "complete these"
        ]

        return questionPatterns.contains { query.contains($0) }
    }

    /// Check if query mentions specific topics
    private static func hasTopicKeywords(_ query: String) -> Bool {
        let questionWords = ["what", "how", "why", "when", "where", "who", "explain", "describe"]
        return questionWords.contains { query.hasPrefix($0) || query.contains(" \($0) ") }
    }

    // MARK: - Page Number Extraction

    /// Extract specific page numbers from query (e.g., "page 2", "pages 1-3", "page 5 and 7")
    private static func extractPageNumbers(from query: String, totalPages: Int) -> [String]? {
        var pageNumbers: Set<Int> = []

        // Pattern: "page X" or "pages X"
        let singlePagePattern = #/page\s+(\d+)/# // Regex pattern
        if let matches = try? singlePagePattern.firstMatch(in: query) {
            if let pageNum = Int(matches.1) {
                pageNumbers.insert(pageNum - 1) // Convert to 0-based index
            }
        }

        // Pattern: "pages X-Y" or "page X to Y"
        let rangePatterns = [
            #/pages?\s+(\d+)\s*-\s*(\d+)/#,
            #/pages?\s+(\d+)\s+to\s+(\d+)/#
        ]

        for pattern in rangePatterns {
            if let matches = try? pattern.firstMatch(in: query) {
                if let start = Int(matches.1), let end = Int(matches.2) {
                    for pageNum in start...end {
                        pageNumbers.insert(pageNum - 1) // Convert to 0-based
                    }
                }
            }
        }

        // Pattern: "pages X and Y" or "page X, Y"
        let multiPagePattern = #/pages?\s+(\d+)(?:\s+and\s+|\s*,\s*)(\d+)/#
        if let matches = try? multiPagePattern.firstMatch(in: query) {
            if let page1 = Int(matches.1), let page2 = Int(matches.2) {
                pageNumbers.insert(page1 - 1)
                pageNumbers.insert(page2 - 1)
            }
        }

        // Filter to valid page range
        let validPages = pageNumbers.filter { $0 >= 0 && $0 < totalPages }

        return validPages.isEmpty ? nil : validPages.sorted().map { String($0) }
    }

    /// Extract positional references (first, last, beginning, end)
    private static func extractPositionalPages(from query: String, allPages: [String]) -> [String]? {
        guard !allPages.isEmpty else { return nil }

        // "first page" or "beginning"
        if query.contains("first") || query.contains("beginning") || query.contains("start") {
            return [allPages[0]]
        }

        // "last page" or "end"
        if query.contains("last") || query.contains("end") || query.contains("final") {
            return [allPages[allPages.count - 1]]
        }

        // "first few pages"
        if query.contains("first few") || query.contains("first couple") {
            return Array(allPages.prefix(min(3, allPages.count)))
        }

        // "last few pages"
        if query.contains("last few") || query.contains("last couple") {
            return Array(allPages.suffix(min(3, allPages.count)))
        }

        return nil
    }
}

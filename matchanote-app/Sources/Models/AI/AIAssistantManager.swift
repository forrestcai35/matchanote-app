import Foundation
import SwiftUI
import Combine

class AIAssistantManager: ObservableObject {
    @Published var isAnalyzing = false
    @Published var analysisProgress: Double = 0.0
    @Published var currentAnalysisStep = ""
    @Published var lastAnalysis: IntelligentAnalysis?
    @Published var suggestions: [ParsedSuggestion] = []
    @Published var error: AIAssistantError?

    private let recursiveAI = RecursiveAI()
    private let noteAnalyzer = NoteAnalyzer()
    private let suggestionParser = SuggestionParser()
    private let handwritingRecognizer = HandwritingRecognizer()

    private var cancellables = Set<AnyCancellable>()

    init() {
        setupBindings()
    }

    private func setupBindings() {
        // Bind RecursiveAI progress to our published properties
        recursiveAI.$isProcessing
            .receive(on: DispatchQueue.main)
            .assign(to: &$isAnalyzing)

        recursiveAI.$progress
            .receive(on: DispatchQueue.main)
            .assign(to: &$analysisProgress)

        recursiveAI.$currentStep
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentAnalysisStep)

        // Bind SuggestionParser suggestions
        suggestionParser.$suggestions
            .receive(on: DispatchQueue.main)
            .assign(to: &$suggestions)
    }

    // MARK: - Main Analysis Method

    func analyzeNote(_ note: Note, with storageManager: StorageManager) async {
        await MainActor.run {
            error = nil
            currentAnalysisStep = "Starting AI analysis..."
            analysisProgress = 0.0
        }

        do {
            // Perform intelligent analysis using RecursiveAI
            let analysis = try await performIntelligentAnalysis(note, storageManager: storageManager)

            await MainActor.run {
                self.lastAnalysis = analysis
                self.currentAnalysisStep = "Analysis complete"
                self.analysisProgress = 1.0

                // Parse suggestions from the analysis
                self.parseSuggestions(from: analysis)
            }

        } catch {
            await MainActor.run {
                self.error = AIAssistantError.analysisFailed(error)
                self.currentAnalysisStep = "Analysis failed"
                self.isAnalyzing = false
            }
        }
    }

    private func performIntelligentAnalysis(_ note: Note, storageManager: StorageManager) async throws -> IntelligentAnalysis {
        // Use RecursiveAI for comprehensive analysis
        return await recursiveAI.analyzeNoteWithAI(note, storageManager: storageManager)
    }

    // MARK: - Quick Analysis Methods

    func quickAnalyzeHandwriting(_ note: Note) async -> String {
        await MainActor.run {
            currentAnalysisStep = "Analyzing handwriting..."
        }

        let handwrittenText = await handwritingRecognizer.recognizeTextFromMultiplePages(
            drawingDataByPage: note.drawingDataByPage
        )

        let allText = handwrittenText.values.joined(separator: "\n")
        return allText.isEmpty ? "No handwritten text found" : allText
    }

    func quickAnalyzeContent(_ note: Note) async -> AnalysisResult {
        await MainActor.run {
            currentAnalysisStep = "Performing quick content analysis..."
        }

        return await noteAnalyzer.analyzeNote(note)
    }

    // MARK: - Suggestion Management

    private func parseSuggestions(from analysis: IntelligentAnalysis) {
        let allText = analysis.summary + "\n" + analysis.suggestions.joined(separator: "\n")
        let parsedSuggestions = suggestionParser.parseAIResponse(allText, for: analysis.noteId)

        Task { @MainActor in
            self.suggestions = parsedSuggestions
        }
    }

    func acceptSuggestion(_ suggestion: ParsedSuggestion, for note: inout Note) -> Bool {
        let success = suggestionParser.applySuggestion(suggestion, to: &note)

        if success {
            Task { @MainActor in
                self.suggestionParser.acceptSuggestion(suggestion)
            }
        }

        return success
    }

    func dismissSuggestion(_ suggestion: ParsedSuggestion) {
        Task { @MainActor in
            self.suggestionParser.dismissSuggestion(suggestion)
        }
    }

    func filterSuggestions(by type: ParsedSuggestion.SuggestionType) -> [ParsedSuggestion] {
        return suggestions.filter { $0.type == type }
    }

    func filterSuggestions(by priority: ParsedSuggestion.Priority) -> [ParsedSuggestion] {
        return suggestions.filter { $0.priority == priority }
    }

    // MARK: - Analysis History

    func getAnalysisHistory(for noteId: UUID) -> [IntelligentAnalysis] {
        // In a full implementation, this would retrieve from persistent storage
        // For now, return the last analysis if it matches
        if let analysis = lastAnalysis, analysis.noteId == noteId {
            return [analysis]
        }
        return []
    }

    func clearAnalysisHistory() {
        Task { @MainActor in
            self.lastAnalysis = nil
            self.suggestions.removeAll()
            self.error = nil
        }
    }

    // MARK: - Contextual Analysis

    func analyzeNoteInContext(_ note: Note, relatedNotes: [Note], storageManager: StorageManager) async {
        await MainActor.run {
            currentAnalysisStep = "Analyzing note with context from \(relatedNotes.count) related notes..."
        }

        // Enhanced analysis with context
        let contextualAnalysis = await noteAnalyzer.analyzeNote(note, relatedNotes: relatedNotes)

        // Convert to IntelligentAnalysis format
        let intelligentAnalysis = IntelligentAnalysis(
            noteId: note.id,
            summary: "Contextual analysis found \(contextualAnalysis.insights.mainTopics.count) main topics and \(contextualAnalysis.gaps.count) content gaps.",
            keyInsights: contextualAnalysis.insights.mainTopics,
            suggestions: contextualAnalysis.suggestions.map { $0.title },
            relatedNotes: relatedNotes.map { $0.id },
            handwritingAnalysis: await quickAnalyzeHandwriting(note),
            contentGaps: contextualAnalysis.gaps.map { $0.description },
            timestamp: Date()
        )

        await MainActor.run {
            self.lastAnalysis = intelligentAnalysis
            self.parseSuggestions(from: intelligentAnalysis)
            self.currentAnalysisStep = "Contextual analysis complete"
            self.analysisProgress = 1.0
        }
    }

    // MARK: - Search and Connect

    func findRelatedNotes(for note: Note, in allNotes: [Note]) -> [Note] {
        let keywords = handwritingRecognizer.extractKeywordsFromText(note.content + " " + note.title + " " + note.subject)

        return allNotes.filter { otherNote in
            otherNote.id != note.id && (
                otherNote.subject == note.subject ||
                keywords.contains { keyword in
                    otherNote.title.lowercased().contains(keyword.lowercased()) ||
                    otherNote.content.lowercased().contains(keyword.lowercased()) ||
                    otherNote.subject.lowercased().contains(keyword.lowercased())
                }
            )
        }.prefix(10).map { $0 }
    }

    func suggestNotesToRead(basedOn note: Note, from allNotes: [Note]) -> [Note] {
        let relatedNotes = findRelatedNotes(for: note, in: allNotes)

        // Prioritize notes that are frequently referenced or recently modified
        return relatedNotes.sorted { note1, note2 in
            if note1.lastOpenedAt != nil && note2.lastOpenedAt != nil {
                return note1.lastOpenedAt! > note2.lastOpenedAt!
            } else if note1.lastOpenedAt != nil {
                return true
            } else if note2.lastOpenedAt != nil {
                return false
            } else {
                return note1.dateModified > note2.dateModified
            }
        }.prefix(5).map { $0 }
    }

    // MARK: - Performance Optimization

    func preloadAnalysisForNote(_ note: Note) {
        // Preload handwriting recognition in background
        Task(priority: .background) {
            _ = await handwritingRecognizer.recognizeTextFromMultiplePages(
                drawingDataByPage: note.drawingDataByPage
            )
        }
    }

    func cancelCurrentAnalysis() {
        Task { @MainActor in
            self.isAnalyzing = false
            self.analysisProgress = 0.0
            self.currentAnalysisStep = ""
        }
    }

    // MARK: - Export and Sharing

    func exportAnalysis(_ analysis: IntelligentAnalysis) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short

        return """
        # AI Analysis Report

        **Note ID:** \(analysis.noteId)
        **Analysis Date:** \(formatter.string(from: analysis.timestamp))

        ## Summary
        \(analysis.summary)

        ## Key Insights
        \(analysis.keyInsights.map { "• \($0)" }.joined(separator: "\n"))

        ## Suggestions
        \(analysis.suggestions.map { "• \($0)" }.joined(separator: "\n"))

        ## Content Gaps
        \(analysis.contentGaps.map { "• \($0)" }.joined(separator: "\n"))

        ## Handwriting Analysis
        \(analysis.handwritingAnalysis)

        ---
        Generated by Matcha Notes AI Assistant
        """
    }
}

enum AIAssistantError: Error, LocalizedError {
    case analysisFailed(Error)
    case invalidNote
    case noHandwritingFound
    case apiKeyMissing
    case networkError

    var errorDescription: String? {
        switch self {
        case .analysisFailed(let error):
            return "Analysis failed: \(error.localizedDescription)"
        case .invalidNote:
            return "Invalid note provided for analysis"
        case .noHandwritingFound:
            return "No handwriting content found in the note"
        case .apiKeyMissing:
            return "API key is missing for AI analysis"
        case .networkError:
            return "Network error occurred during analysis"
        }
    }
}

// MARK: - Extensions for Integration

extension AIAssistantManager {
    func integrateWithStorageManager(_ storageManager: StorageManager) {
        // Set up observers for note changes to trigger analysis updates
        // This would be implemented with proper observation patterns
    }

    func integrateWithTabManager(_ tabManager: TabManager) {
        // Preload analysis for active tabs
        // This would be implemented to work with the existing tab system
    }
}
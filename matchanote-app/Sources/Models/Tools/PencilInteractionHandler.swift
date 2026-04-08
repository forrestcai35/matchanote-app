import UIKit
import PencilKit

/// Centralized handler for Apple Pencil interaction gestures (double-tap and squeeze).
/// Manages tool-switching logic based on the user's system preferences.
class PencilInteractionHandler {
    private var previousTool: PenTool = .pen

    /// Handle a pencil double-tap gesture. Returns the tool to switch to, or nil if no action.
    func handleTap(currentTool: PenTool?) -> PenTool? {
        switch UIPencilInteraction.preferredTapAction {
        case .switchEraser:
            return toggleEraser(currentTool: currentTool)
        case .switchPrevious:
            return switchToPrevious(currentTool: currentTool)
        default:
            return nil
        }
    }

    /// Handle an Apple Pencil Pro squeeze gesture. Returns the tool to switch to, or nil if no action.
    @available(iOS 17.5, *)
    func handleSqueeze(currentTool: PenTool?) -> PenTool? {
        switch UIPencilInteraction.preferredSqueezeAction {
        case .switchEraser:
            return toggleEraser(currentTool: currentTool)
        case .switchPrevious:
            return switchToPrevious(currentTool: currentTool)
        // Let the system handle Show Palette or Run Shortcut natively if returned nil
        default:
            return nil
        }
    }

    private func toggleEraser(currentTool: PenTool?) -> PenTool {
        if let currentTool {
            if currentTool == .eraser {
                return previousTool
            } else {
                previousTool = currentTool
                return .eraser
            }
        } else {
            previousTool = .pen
            return .eraser
        }
    }

    private func switchToPrevious(currentTool: PenTool?) -> PenTool {
        let current = currentTool ?? .pen
        let toolToRestore = previousTool
        previousTool = current
        return toolToRestore
    }
}

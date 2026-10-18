import CoreImage
import Testing
@testable import GestureEdit

struct EditStateTests {
    @Test func newStateIsUnedited() {
        let state = EditState()
        #expect(state.isUnedited)
        #expect(state[.warmth] == 6500)
        #expect(state[.contrast] == 1)
    }

    @Test func valuesAreClampedToTheToolRange() {
        var state = EditState()
        state[.exposure] = 10
        let high = state[.exposure]
        state[.exposure] = -10
        let low = state[.exposure]
        #expect(high == 2)
        #expect(low == -2)
    }

    @Test func movingBackToDefaultEqualsAFreshState() {
        var state = EditState()
        state[.saturation] = 1.4
        #expect(!state.isUnedited)
        state[.saturation] = 1
        #expect(state == EditState())
    }
}

struct EditHistoryTests {
    private func state(exposure: Double) -> EditState {
        var state = EditState()
        state[.exposure] = exposure
        return state
    }

    @Test func undoThenRedoRestoresStates() {
        var history = EditHistory()
        let before = state(exposure: 0)
        let after = state(exposure: 1)
        history.record(before)

        let undone = history.undo(from: after)
        #expect(undone == before)
        #expect(history.canRedo)

        let redone = history.redo(from: before)
        #expect(redone == after)
        #expect(!history.canRedo)
    }

    @Test func undoOnEmptyHistoryReturnsNil() {
        var history = EditHistory()
        let result = history.undo(from: EditState())
        #expect(result == nil)
    }

    @Test func newEditClearsRedo() {
        var history = EditHistory()
        history.record(state(exposure: 0))
        _ = history.undo(from: state(exposure: 1))
        history.record(state(exposure: 0.5))
        #expect(!history.canRedo)
    }

    @Test func keepsAtMostFiftySteps() {
        var history = EditHistory()
        for step in 0..<60 {
            history.record(state(exposure: Double(step) / 100))
        }
        #expect(history.undoStack.count == 50)
        #expect(history.undoStack.first == state(exposure: 0.10))
    }
}

struct RenderPipelineTests {
    private let gray = CIImage(color: CIColor(red: 0.5, green: 0.5, blue: 0.5))
        .cropped(to: CGRect(x: 0, y: 0, width: 64, height: 64))

    private func averageRed(_ image: CIImage) -> Double {
        let context = CIContext(options: [.workingColorSpace: NSNull()])
        var pixel = [UInt8](repeating: 0, count: 4)
        context.render(image, toBitmap: &pixel, rowBytes: 4,
                       bounds: CGRect(x: 32, y: 32, width: 1, height: 1),
                       format: .RGBA8, colorSpace: nil)
        return Double(pixel[0]) / 255
    }

    @Test func uneditedStateKeepsSizeAndColor() {
        let output = RenderPipeline.apply(EditState(), to: gray)
        #expect(output.extent == gray.extent)
        #expect(abs(averageRed(output) - 0.5) < 0.02)
    }

    @Test func positiveExposureBrightens() {
        var state = EditState()
        state[.exposure] = 1
        let output = RenderPipeline.apply(state, to: gray)
        #expect(output.extent == gray.extent)
        #expect(averageRed(output) > 0.6)
    }
}

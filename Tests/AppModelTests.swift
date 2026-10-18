import Testing
@testable import GestureEdit

@MainActor
struct AppModelTests {
    @Test func startsWithAStatusMessage() {
        let model = AppModel()
        #expect(!model.statusMessage.isEmpty)
    }
}

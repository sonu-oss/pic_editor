import AppKit
import AVFoundation
import SwiftUI

/// Shows the live camera in SwiftUI using Apple's preview layer, mirrored like a mirror (CAM-4).
struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession
    /// Passed in so SwiftUI refreshes the view once the camera starts (the mirroring can only be set then).
    var isRunning: Bool

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {
        nsView.applyMirroring()
    }
}

final class PreviewView: NSView {
    let previewLayer = AVCaptureVideoPreviewLayer()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        previewLayer.videoGravity = .resizeAspect
        layer = previewLayer
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override func layout() {
        super.layout()
        applyMirroring()
    }

    func applyMirroring() {
        guard let connection = previewLayer.connection, connection.isVideoMirroringSupported else { return }
        connection.automaticallyAdjustsVideoMirroring = false
        connection.isVideoMirrored = true
    }
}

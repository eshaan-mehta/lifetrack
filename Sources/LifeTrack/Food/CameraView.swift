import AVFoundation
import Observation
import PhotosUI
import SwiftUI
import UIKit

/// Live camera inside the drawer. Preview fills the sheet; back to voice on the left,
/// shutter in the middle, photo library on the right.
struct CameraView: View {
    let onPhoto: (UIImage) -> Void
    let onBack: () -> Void

    @State private var camera = CameraController()
    @State private var librarySelection: PhotosPickerItem?
    @State private var flash = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black
            switch camera.status {
            case .running:
                CameraPreview(session: camera.session)
            case .unavailable(let message):
                VStack(spacing: 10) {
                    Image(systemName: "camera.slash").font(.largeTitle)
                    Text(message)
                }
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(32)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .idle:
                ProgressView().tint(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            if flash {
                Color.white
            }
            controls
        }
        .ignoresSafeArea()
        .task { await camera.start() }
        .onDisappear { camera.stop() }
        .onChange(of: librarySelection) { _, item in load(item) }
    }

    private var controls: some View {
        HStack {
            RoundGlyphButton(systemImage: "chevron.left", label: "Back to voice", onImagery: true, action: onBack)
            Spacer()
            Button(action: shoot) {
                ZStack {
                    Circle().stroke(.white, lineWidth: 4)
                        .frame(width: DrawerControls.shutterSize, height: DrawerControls.shutterSize)
                    Circle().fill(.white)
                        .frame(width: DrawerControls.shutterSize - 14, height: DrawerControls.shutterSize - 14)
                }
            }
            .buttonStyle(.plain)
            .disabled(camera.status != .running)
            .opacity(camera.status == .running ? 1 : 0.35)
            .accessibilityLabel("Take photo")
            Spacer()
            PhotosPicker(selection: $librarySelection, matching: .images) {
                RoundGlyph(systemImage: "photo.on.rectangle", onImagery: true)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Choose from library")
        }
        .frame(height: DrawerControls.rowHeight)
        .padding(.horizontal, DrawerControls.horizontalPadding)
        .padding(.bottom, DrawerControls.bottomPadding)
    }

    private func shoot() {
        withAnimation(.easeOut(duration: 0.08)) { flash = true }
        camera.capture { image in
            withAnimation(.easeIn(duration: 0.15)) { flash = false }
            onPhoto(image)
        }
    }

    private func load(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                onPhoto(image)
            }
        }
    }
}

@MainActor
@Observable
final class CameraController {
    enum Status: Equatable {
        case idle
        case running
        case unavailable(String)
    }

    private(set) var status: Status = .idle
    let session = AVCaptureSession()

    @ObservationIgnored private let output = AVCapturePhotoOutput()
    @ObservationIgnored private let queue = DispatchQueue(label: "LifeTrack.camera")
    @ObservationIgnored private var configured = false
    @ObservationIgnored private var inFlight: PhotoDelegate?

    func start() async {
        guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil else {
            status = .unavailable("No camera on this device. Pick a photo instead.")
            return
        }
        guard await AVCaptureDevice.requestAccess(for: .video) else {
            status = .unavailable("Camera access is turned off for LifeTrack.")
            return
        }
        let session = self.session
        let output = self.output
        let needsConfiguration = !configured
        configured = true
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                if needsConfiguration {
                    session.beginConfiguration()
                    session.sessionPreset = .photo
                    if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                       let input = try? AVCaptureDeviceInput(device: device),
                       session.canAddInput(input) {
                        session.addInput(input)
                    }
                    if session.canAddOutput(output) {
                        session.addOutput(output)
                    }
                    session.commitConfiguration()
                }
                if !session.isRunning {
                    session.startRunning()
                }
                continuation.resume()
            }
        }
        status = session.isRunning ? .running : .unavailable("Couldn't start the camera.")
    }

    func stop() {
        let session = self.session
        queue.async {
            if session.isRunning { session.stopRunning() }
        }
    }

    func capture(_ completion: @escaping (UIImage) -> Void) {
        guard status == .running, inFlight == nil else { return }
        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90   // portrait-only app
        }
        let delegate = PhotoDelegate { [weak self] image in
            Task { @MainActor in
                self?.inFlight = nil
                if let image { completion(image) }
            }
        }
        inFlight = delegate
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
    }
}

private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let done: (UIImage?) -> Void

    init(done: @escaping (UIImage?) -> Void) {
        self.done = done
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        done(photo.fileDataRepresentation().flatMap(UIImage.init(data:)))
    }
}

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

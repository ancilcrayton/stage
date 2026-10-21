import AVFoundation
import AVKit
import MetalKit
import UIKit

final class TheaterViewController: UIViewController, MTKViewDelegate {
    var isExternalDisplay = false

    private var metalView: MTKView?
    private var renderer: TheaterRenderer?
    private var playerLayer: AVPlayerLayer?
    private var frameCount = 0
    private var fpsWindowStart = CACurrentMediaTime()

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .landscape
    }

    override var prefersStatusBarHidden: Bool {
        true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let layer = AVPlayerLayer(player: StageModel.shared.player.player)
        layer.videoGravity = .resizeAspect
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        playerLayer = layer

        guard let device = MTLCreateSystemDefaultDevice() else { return }
        let metalView = MTKView(frame: view.bounds, device: device)
        metalView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        metalView.isOpaque = true
        metalView.delegate = self
        metalView.colorPixelFormat = .bgra8Unorm
        metalView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        metalView.preferredFramesPerSecond = 60
        metalView.isPaused = false
        metalView.enableSetNeedsDisplay = false
        metalView.framebufferOnly = true
        view.addSubview(metalView)
        self.metalView = metalView
        renderer = TheaterRenderer(device: device)
        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleChrome))
        metalView.addGestureRecognizer(tap)
    }

    @objc private func toggleChrome() {
        guard !isExternalDisplay else { return }
        StageModel.shared.fallbackChrome.toggle()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        playerLayer?.frame = view.bounds
        metalView?.frame = view.bounds
    }

    nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    nonisolated func draw(in view: MTKView) {
        MainActor.assumeIsolated {
            render(view)
        }
    }

    private var drivesSimulation: Bool {
        isExternalDisplay || !StageModel.shared.glassesConnected
    }

    private func render(_ view: MTKView) {
        guard drivesSimulation, let renderer else { return }
        let model = StageModel.shared
        let rotation = model.integrateFrame()
        renderer.draw(
            in: view,
            rotation: rotation,
            screenSize: Float(model.screenSize),
            curve: Float(model.curve),
            videoAspect: model.player.displayAspect,
            videoRotation: model.player.shaderRotation,
            pixelBuffer: model.player.copyFrame()
        )
        frameCount += 1
        let now = CACurrentMediaTime()
        let elapsed = now - fpsWindowStart
        if elapsed >= 0.5 {
            model.framesPerSecond = (Double(frameCount) / elapsed * 10).rounded() / 10
            frameCount = 0
            fpsWindowStart = now
        }
    }
}

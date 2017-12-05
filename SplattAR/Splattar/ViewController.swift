
import UIKit
import ARKit
import SceneKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    enum InkColor {
        case pink
        case green
    }

    @IBOutlet weak var statusLabel: UILabel!
    @IBOutlet weak var arView: ARSCNView!

    var session: ARSession!
    var configuration: ARConfiguration!

    var inkColor = InkColor.pink
    var splatCount = 1
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureSession()
        configureView()
        configureScene()
        configureGestureRecognizer()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pauseSession()
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        if let firstTouch = touches.first {
            let point = firstTouch.location(in: arView)
            addInk(at: point)
        }
    }
    
    // MARK: -

    func configureSession() {
        if !ARWorldTrackingConfiguration.isSupported {
            print("World tracking configuration not supported--not starting session")
            return
        }

        session = arView.session
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = .horizontal
        configuration = config
    }
    
    func configureView() {
        arView.delegate = self
        arView.session.delegate = self
    }
    
    func configureScene() {
        let light = SCNLight()
        arView.scene.rootNode.light = light
    }
    
    func configureGestureRecognizer() {
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(tapRecognizerDidRecognize))
        tapRecognizer.numberOfTouchesRequired = 2
        arView.addGestureRecognizer(tapRecognizer)
    }
    
    func startSession() {
        session.run(configuration, options: .resetTracking)
    }
    
    func pauseSession() {
        session.pause()
    }
    
    func toggleInkColor() {
        inkColor = (inkColor == .pink) ? .green : .pink
    }
    
func addInk(at point: CGPoint) {
    let results = arView.hitTest(point, types: .existingPlaneUsingExtent)
    if let nearestResult = results.first {
        guard let anchor = nearestResult.anchor as? ARPlaneAnchor else { return }
        guard let planeNode = arView.node(for: anchor) else { return }
        
        let splatGeometry = SCNPlane(width: 0.25, height: 0.25)
        
        let material = splatGeometry.firstMaterial!
        material.writesToDepthBuffer = false
        material.diffuse.contents = UIImage(named: (inkColor == .pink) ? "splat-pink" : "splat-green")

        let splatNode = SCNNode(geometry: splatGeometry)
        splatNode.renderingOrder = splatCount
        splatCount += 1
        let planeOrienation = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
        let randomRotation = SCNMatrix4MakeRotation(Float(drand48() * 2 * .pi), 0, 1, 0)
        splatNode.transform = SCNMatrix4Mult(SCNMatrix4Mult(planeOrienation, randomRotation), SCNMatrix4(nearestResult.localTransform))

        planeNode.addChildNode(splatNode)
    }
}
    
    func addPlaneGeometry(for anchor: ARPlaneAnchor, _ node: SCNNode) {
        let planeGeometry = SCNPlane(width: 1, height: 1)
        
        let material = planeGeometry.firstMaterial!
        material.writesToDepthBuffer = false
        material.diffuse.contents = UIImage(named: "grid.png")
        material.diffuse.wrapS = .repeat
        material.diffuse.wrapT = .repeat
        
        let planeNode = SCNNode(geometry: planeGeometry)
        node.addChildNode(planeNode)
    }
    
    func updatePlaneGeometry(for anchor: ARPlaneAnchor, _ node: SCNNode) {
        node.position = SCNVector3(anchor.center.x, 0, anchor.center.z)
        node.transform = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
        
        let planeGeometry = node.geometry as! SCNPlane
        planeGeometry.width = CGFloat(anchor.extent.x)
        planeGeometry.height = CGFloat(anchor.extent.z)
        
        let material = planeGeometry.firstMaterial!
        material.diffuse.contentsTransform = SCNMatrix4MakeScale(anchor.extent.x, anchor.extent.z, 1)
    }
    
    func updateStatusDisplay(_ state: ARCamera.TrackingState) {
        statusLabel.isHidden = false
        switch state {
        case .normal:
            statusLabel.isHidden = true
        case .notAvailable:
            statusLabel.text = "Tracking not available"
        case .limited(let reason):
            switch reason {
            case .initializing:
                statusLabel.text = "Initializing"
            case .excessiveMotion:
                statusLabel.text = "Slow down..."
            case .insufficientFeatures:
                statusLabel.text = "Insufficient features"
            }
        }
    }
    
    // MARK: - UIGestureRecognizerDelegate
    
    @objc
    func tapRecognizerDidRecognize(_ recognizer: UIGestureRecognizer) {
        toggleInkColor()
    }

    // MARK: - ARSCNViewDelegate

    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        addPlaneGeometry(for: planeAnchor, node)
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
        guard let planeNode = node.childNodes.first else { return }
        updatePlaneGeometry(for: planeAnchor, planeNode)
    }
    
    // MARK: - ARSessionObserver

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        updateStatusDisplay(camera.trackingState)
    }

    func sessionWasInterrupted(_ session: ARSession) {
        pauseSession()
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        startSession()
    }
}

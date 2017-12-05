
import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {

    @IBOutlet var arView: ARSCNView!
    @IBOutlet weak var statusLabel: UILabel!
    
    var session: ARSession!
    var configuration: ARConfiguration!
    
    var faceNode: SCNNode?
    var nutcrackerNode: SCNNode!
    
    var mouthNode: SCNNode!
    var eyebrowLeftNode: SCNNode!
    var eyebrowRightNode: SCNNode!
    
    var mouthPosition = SCNVector3()
    var eyebrowLeftPosition = SCNVector3()
    var eyebrowRightPosition = SCNVector3()
    
    let browRaiseHeight: Float = 0.015
    let jawHeight: Float = 0.05

    override func viewDidLoad() {
        super.viewDidLoad()
        configureSession()
        configureView()
        configureScene()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        pauseSession()
    }

    // MARK: -
    
    func configureSession() {
        if !ARFaceTrackingConfiguration.isSupported {
            fatalError("Face tracking configuration not supported--not starting session")
        }
        
        session = arView.session
        
        let config = ARFaceTrackingConfiguration()
        config.isLightEstimationEnabled = true
        configuration = config
    }
    
    func configureView() {
        arView.delegate = self
        arView.session.delegate = self
    }
    
    func configureScene() {
        guard let url = Bundle.main.url(forResource: "nutcracker", withExtension: "scn", subdirectory: "Model.scnassets") else { fatalError("Model resource not in bundle!") }
        let modelNode = SCNReferenceNode(url: url)!
        modelNode.load()
        nutcrackerNode = modelNode

        mouthNode = nutcrackerNode.childNode(withName: "mouth", recursively: true)
        eyebrowLeftNode = nutcrackerNode.childNode(withName: "left_eyebrow", recursively: true)
        eyebrowRightNode = nutcrackerNode.childNode(withName: "right_eyebrow", recursively: true)
        
        mouthPosition = mouthNode.position
        eyebrowLeftPosition = eyebrowLeftNode.position
        eyebrowRightPosition = eyebrowRightNode.position
    }
    
    func startSession() {
        session.run(configuration, options: .resetTracking)
    }
    
    func pauseSession() {
        session.pause()
    }
    
    func updateModel(_ faceAnchor: ARFaceAnchor) {
        let blendShapes = faceAnchor.blendShapes
        
        guard let browUp = blendShapes[.browInnerUp] as? Float else { return }
        guard let jawOpen = blendShapes[.jawOpen] as? Float else { return }
        
        eyebrowLeftNode.position.y = eyebrowLeftPosition.y + (browUp * browRaiseHeight)
        eyebrowRightNode.position.y = eyebrowRightPosition.y + (browUp * browRaiseHeight)
        mouthNode.position.y = mouthPosition.y - (jawOpen * jawHeight)
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
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let _ = anchor as? ARFaceAnchor {
            faceNode = node
            configureSceneGraph()
        }
    }
    
    func configureSceneGraph() {
        guard let node = faceNode else { return }
        
        for child in node.childNodes {
            child.removeFromParentNode()
        }
        
        node.addChildNode(nutcrackerNode)
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        updateModel(faceAnchor)
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


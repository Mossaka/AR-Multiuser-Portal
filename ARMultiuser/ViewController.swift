/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Main view controller for the AR experience.
*/

import UIKit
import SceneKit
import ARKit
import MultipeerConnectivity

class ViewController: UIViewController, ARSCNViewDelegate, ARSessionDelegate {
    // MARK: - IBOutlets
    
    @IBOutlet weak var sessionInfoView: UIView!
    @IBOutlet weak var sessionInfoLabel: UILabel!
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var sendMapButton: UIButton!
    @IBOutlet weak var mappingStatusLabel: UILabel!
    @IBOutlet weak var insidePortal: UITextField!
    
    private var portalCreated : Bool = false
    private var peerVirtualCharacterNode = SCNNode()
    
    // MARK: - View Life Cycle
    
    var multipeerSession: MultipeerSession!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        multipeerSession = MultipeerSession(receivedDataHandler: receivedData)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard ARWorldTrackingConfiguration.isSupported else {
            fatalError("""
                ARKit is not available on this device. For apps that require ARKit
                for core functionality, use the `arkit` key in the key in the
                `UIRequiredDeviceCapabilities` section of the Info.plist to prevent
                the app from installing. (If the app can't be installed, this error
                can't be triggered in a production scenario.)
                In apps where AR is an additive feature, use `isSupported` to
                determine whether to show UI for launching AR experiences.
            """) // For details, see https://developer.apple.com/documentation/arkit
        }
        
        // Start the view's AR session.
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
        sceneView.session.delegate = self
        
        self.sceneView.debugOptions = [ARSCNDebugOptions.showWorldOrigin, ARSCNDebugOptions.showFeaturePoints]
        UIApplication.shared.isIdleTimerDisabled = true
        
        loadPeersVirtualCharacters(from: "Portal.scnassets/PeerCharacters/ship.scn")
        
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        if let name = anchor.name, name.hasPrefix("portal") {
            let refNode = loadPortal()
            self.addPlane(nodename: "roof", portalNode: refNode, imagename: "top")
            self.addPlane(nodename: "floor", portalNode: refNode, imagename: "bottom")
            self.addWalls(nodename: "backWall", portalNode: refNode, imagename: "back")
            self.addWalls(nodename: "sideWallOrange", portalNode: refNode, imagename: "right")
            self.addWalls(nodename: "sideWallPink", portalNode: refNode, imagename: "left")
            self.addPlane(nodename: "front", portalNode: refNode, imagename: "front")
            node.addChildNode(refNode)
        }
    }
    
    // check whether the user is inside the portal or not
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        if(self.portalCreated) {
            guard let door = self.sceneView.scene.rootNode.childNode(withName: "front", recursively: true) else {return}
            guard let left = self.sceneView.scene.rootNode.childNode(withName: "sideWallPink", recursively: true) else {return}
            guard let right = self.sceneView.scene.rootNode.childNode(withName: "sideWallOrange", recursively: true) else {return}
            guard let pointOfView = self.sceneView.pointOfView else {return}
            let cameraTransform = pointOfView.transform
            let cameraPosition = SCNVector3(cameraTransform.m41, cameraTransform.m42, cameraTransform.m43)
            let doorDistance = cameraPosition.z - door.position.z
            let leftDistance = cameraPosition.x - left.position.x
            let rightDistance = cameraPosition.x - right.position.x
            DispatchQueue.main.async {
                if(doorDistance < 0 && doorDistance > -2.1 && leftDistance > 0 && rightDistance < 0) {
                    self.insidePortal.text = "True"
                    self.peerVirtualCharacterNode.isHidden = false
                    self.shareUserTransform()
                } else {
                    self.insidePortal.text = "False"
                    self.peerVirtualCharacterNode.isHidden = true
                }
            }
//            print("door: \(String(format: "%.2f", doorDistance)), left: \(String(format: "%.2f", leftDistance)), right: \(String(format: "%.2f", rightDistance)) ")
        }
        else {
            self.peerVirtualCharacterNode.isHidden = true
        }
    }
    
    // MARK: - ARSessionDelegate
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        updateSessionInfoLabel(for: session.currentFrame!, trackingState: camera.trackingState)
    }
    
    /// - Tag: CheckMappingStatus
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        switch frame.worldMappingStatus {
        case .notAvailable, .limited:
            sendMapButton.isEnabled = false
        case .extending:
            sendMapButton.isEnabled = !multipeerSession.connectedPeers.isEmpty
        case .mapped:
            sendMapButton.isEnabled = !multipeerSession.connectedPeers.isEmpty
        }
        mappingStatusLabel.text = frame.worldMappingStatus.description
        updateSessionInfoLabel(for: frame, trackingState: frame.camera.trackingState)
    }
    
    // MARK: - ARSessionObserver
    
    func sessionWasInterrupted(_ session: ARSession) {
        // Inform the user that the session has been interrupted, for example, by presenting an overlay.
        sessionInfoLabel.text = "Session was interrupted"
    }
    
    func sessionInterruptionEnded(_ session: ARSession) {
        // Reset tracking and/or remove existing anchors if consistent tracking is required.
        sessionInfoLabel.text = "Session interruption ended"
    }
    
    func session(_ session: ARSession, didFailWithError error: Error) {
        // Present an error message to the user.
        sessionInfoLabel.text = "Session failed: \(error.localizedDescription)"
        resetTracking(nil)
    }
    
    func sessionShouldAttemptRelocalization(_ session: ARSession) -> Bool {
        return true
    }
    
    // MARK: - Multiuser shared session
    
    /// - Tag: PlaceCharacter
    @IBAction func handleSceneTap(_ sender: UITapGestureRecognizer) {

        guard let sceneView = sender.view as? ARSCNView else {return}
        let touchLocation = sender.location(in: sceneView)
        let hitTestResult = sceneView.hitTest(touchLocation, types: .existingPlaneUsingExtent)
        if !hitTestResult.isEmpty && !self.portalCreated {
            
            // Place an anchor for a virtual character. The model appears in renderer(_:didAdd:for:).
            let anchor = ARAnchor(name: "portal", transform: hitTestResult.first!.worldTransform)
            sceneView.session.add(anchor: anchor)
            
            // Send the anchor info to peers, so they can place the same content.
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true)
                else { fatalError("can't encode anchor") }
            self.multipeerSession.sendToAllPeers(data)

            self.portalCreated = true;
        }
        
       
    }
    
    /// - Tag: GetWorldMap
    @IBAction func shareSession(_ button: UIButton) {
        sceneView.session.getCurrentWorldMap { worldMap, error in
            guard let map = worldMap
                else { print("Error: \(error!.localizedDescription)"); return }
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                else { fatalError("can't encode map") }
            self.multipeerSession.sendToAllPeers(data)
        }
    }
    
    func shareUserTransform() {
        if let frame = self.sceneView.session.currentFrame {
            let mat = SCNMatrix4(frame.camera.transform) // 4x4 transform matrix describing camera in world space
            let dir = SCNVector3(-1 * mat.m31, -1 * mat.m32, -1 * mat.m33) // orientation of camera in world space
            let pos = SCNVector3(mat.m41, mat.m42, mat.m43) // location of camera in world space
            let data = realEncoder(from: (dir, pos))
            self.multipeerSession.sendToAllPeers(data)
        }
    }
    
    var mapProvider: MCPeerID?

    /// - Tag: ReceiveData
    func receivedData(_ data: Data, from peer: MCPeerID) {
        
        if let unarchived = try? NSKeyedUnarchiver.unarchivedObject(of: ARWorldMap.classForKeyedUnarchiver(), from: data),
            
            let worldMap = unarchived as? ARWorldMap {
            for anchor in worldMap.anchors {
                if let name = anchor.name, name.hasPrefix("portal") {
                    print("Portal is in the world map!!")
                }
            }
            
            // Run the session with the received world map.
            let configuration = ARWorldTrackingConfiguration()
            configuration.planeDetection = .horizontal
            configuration.initialWorldMap = worldMap
            
            sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
            // Remember who provided the map for showing UI feedback.
            mapProvider = peer
        }
        
        else if let unarchived = try? NSKeyedUnarchiver.unarchivedObject(of: ARAnchor.classForKeyedUnarchiver(), from: data),
            let anchor = unarchived as? ARAnchor {
            
            if let name = anchor.name, name.hasPrefix("portal") {
                self.portalCreated = true
            }
            sceneView.session.add(anchor: anchor)
        }
            
        else {
            if let (dir, pos) = realDecoder(from: data) {
                print("dir: (\(String(format: "%.2f", dir.x)), \(String(format: "%.2f", dir.y)), \(String(format: "%.2f", dir.z))). pos: (\(String(format: "%.2f", pos.x)), \(String(format: "%.2f", pos.y)), \(String(format: "%.2f", pos.z)))")
                peerVirtualCharacterNode.position = pos
                peerVirtualCharacterNode.eulerAngles = dir
                
            }
        }
    }
    
    // MARK: - AR session management
    
    private func updateSessionInfoLabel(for frame: ARFrame, trackingState: ARCamera.TrackingState) {
        // Update the UI to provide feedback on the state of the AR experience.
        let message: String
        
        switch trackingState {
        case .normal where frame.anchors.isEmpty && multipeerSession.connectedPeers.isEmpty:
            // No planes detected; provide instructions for this app's AR interactions.
            message = "Move around to map the environment, or wait to join a shared session."
            
        case .normal where !multipeerSession.connectedPeers.isEmpty && mapProvider == nil:
            let peerNames = multipeerSession.connectedPeers.map({ $0.displayName }).joined(separator: ", ")
            message = "Connected with \(peerNames)."
            
        case .notAvailable:
            message = "Tracking unavailable."
            
        case .limited(.excessiveMotion):
            message = "Tracking limited - Move the device more slowly."
            
        case .limited(.insufficientFeatures):
            message = "Tracking limited - Point the device at an area with visible surface detail, or improve lighting conditions."
            
        case .limited(.initializing) where mapProvider != nil,
             .limited(.relocalizing) where mapProvider != nil:
            message = "Received map from \(mapProvider!.displayName)."
            
        case .limited(.relocalizing):
            message = "Resuming session — move to where you were when the session was interrupted."
            
        case .limited(.initializing):
            message = "Initializing AR session."
            
        default:
            // No feedback needed when tracking is normal and planes are visible.
            // (Nor when in unreachable limited-tracking states.)
            message = ""
            
        }
        
        sessionInfoLabel.text = message
        sessionInfoView.isHidden = message.isEmpty
    }
    
    @IBAction func resetTracking(_ sender: UIButton?) {
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.scene.rootNode.enumerateChildNodes { (node, stop) in
            node.removeFromParentNode()
        }
        portalCreated = false
        peerVirtualCharacterNode = SCNNode()
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    // MARK: - Build the portal
    
    func loadPortal() -> SCNReferenceNode {
        let sceneURL = Bundle.main.url(forResource: "PortalSphereold", withExtension: "scn", subdirectory: "Portal.scnassets")!
        let referenceNode = SCNReferenceNode(url: sceneURL)!
        referenceNode.load()
        
        return referenceNode
    }
    
    func loadPeersVirtualCharacters(from path: String) {
        guard let CharacterScene = SCNScene(named: path) else { fatalError("can't load peer characters from scnassets!" )}
        self.peerVirtualCharacterNode = CharacterScene.rootNode.childNode(withName: "ship", recursively: true)!
        self.peerVirtualCharacterNode.renderingOrder = 300
        self.peerVirtualCharacterNode.scale = SCNVector3(0.3,0.3,0.3)
        sceneView.scene.rootNode.addChildNode(self.peerVirtualCharacterNode)
    }
    
    func addWalls(nodename: String, portalNode: SCNReferenceNode, imagename: String){
        let child = portalNode.childNode(withName: nodename, recursively: true)
        child?.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "Portal.scnassets/\(imagename).png")
        child?.renderingOrder = 200
        if let mask = child?.childNode(withName: "mask", recursively: false){
            mask.geometry?.firstMaterial?.transparency = 0.0000001
        }
    }
    
    func addPlane(nodename: String, portalNode: SCNReferenceNode, imagename: String){
        let child = portalNode.childNode(withName: nodename, recursively: true)
        child?.geometry?.firstMaterial?.diffuse.contents = UIImage(named: "Portal.scnassets/\(imagename).png")
        child?.renderingOrder = 200
    }
}


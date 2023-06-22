//
//  ViewController.swift
//  Laser-laseran
//
//  Created by Muhammad Abdul Ghani on 24/05/23.
//

import UIKit
import RealityKit
import ARKit
import MultipeerSession

class ViewController: UIViewController{
    @IBOutlet var arView: ARView!
    
    var multipeerSession: MultipeerSession?
    var sessionIDObservation: NSKeyValueObservation?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        setupARView()
        
        setupMultipeerSession()
        
        arView.session.delegate = self
        
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap(recognizer:)))
        arView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    func setupARView(){
        arView.automaticallyConfigureSession = false
        
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = [.horizontal, .vertical]
        config.environmentTexturing = .automatic
        config.isCollaborationEnabled = true
        
        arView.session.run(config)
        
        
    }
    
    func setupMultipeerSession(){
        sessionIDObservation = observe(\.arView.session.identifier, options: [.new]) {
            object, change in
            print("Session ID change to: \(change.newValue)")
            
            guard let multipeerSession = self.multipeerSession else {return}
            self.sendARSessionIDTo(peers: multipeerSession.connectedPeers)
        }
        
        multipeerSession = MultipeerSession(serviceName: "multiuser-ar", receivedDataHandler: self.receivedData, peerJoinedHandler: self.peerJoined, peerLeftHandler: self.peerLeft, peerDiscoveredHandler: self.peerDiscovered)
        
        
    }
    
    @objc func handleTap(recognizer: UITapGestureRecognizer){
        let anchor = ARAnchor(name: "lasergreen", transform: arView!.cameraTransform.matrix)
        arView.session.add(anchor: anchor)
    }
    
    func placeObject(named entityName: String, for anchor: ARAnchor){
        let laserEntity = try! ModelEntity.load(named: entityName)
        let anchorEntity = AnchorEntity(anchor: anchor)
        anchorEntity.addChild(laserEntity)
        arView.scene.addAnchor(anchorEntity)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25){
            self.arView.scene.removeAnchor(anchorEntity)
        }
    }
    
}

extension ViewController: ARSessionDelegate{
    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors {
            if let anchorName = anchor.name, anchorName == "lasergreen"{
                placeObject(named: anchorName, for: anchor)
            }
            
            if let participantAnchor = anchor as? ARParticipantAnchor{
                print("Successfully connected with another player!")
                
                let anchorEntity = AnchorEntity(anchor: participantAnchor)
                let mesh = MeshResource.generateSphere(radius: 0.03)
                let color = UIColor.green
                let material = SimpleMaterial(color: color, isMetallic: false)
                let coloredSphere = ModelEntity(mesh: mesh, materials: [material])
                
                anchorEntity.addChild(coloredSphere)
                arView.scene.addAnchor(anchorEntity)
            }
        }
    }
}

extension ViewController{
    private func sendARSessionIDTo(peers: [PeerID]){
        guard let multipeerSession = multipeerSession else{return}
        let idString = arView.session.identifier.uuidString
        let command = "SessionID" + idString
        if let commandData = command.data(using: .utf8){
            multipeerSession.sendToPeers(commandData, reliably: true, peers: peers)
        }
    }
    
    func receivedData(_ data:Data, from peer: PeerID){
        guard let multipeerSession = multipeerSession else {return}
        
        if let collaborationData = try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARSession.CollaborationData.self, from: data){
            arView.session.update(with: collaborationData)
            return
        }
        
        let sessionIDCommandString = "SessionID:"
        if let commandString = String(data: data, encoding: .utf8), commandString.starts(with: sessionIDCommandString){
            let newSessionID = String(commandString[commandString.index(commandString.startIndex,
                                                                        offsetBy: sessionIDCommandString.count)...])
            if let oldSessionID = multipeerSession.peerSessionIDs[peer]{
                removeAllAnchorsOriginatingFromARSessionWithID(oldSessionID)
            }
            
            multipeerSession.peerSessionIDs[peer] = newSessionID
            
        }
    }
    
    func peerDiscovered(_ peer: PeerID) -> Bool{
        guard let multipeerSession = multipeerSession else {return false}
        
        if multipeerSession.connectedPeers.count > 4 {
            print("A fifth player want to join \nThe game is currently limited for four players.")
            return false
        } else {
            return true
        }
    }
    
    func peerJoined(_ peer: PeerID){
        print("""
              A player want to join the game.
              Hold the devices next to each other.
              """)
        
        sendARSessionIDTo(peers: [peer])
    }
    
    func peerLeft(_ peer: PeerID){
        guard let multipeerSession = multipeerSession else {return}
        
        print("A player has left the game")
        
        if let sessionID = multipeerSession.peerSessionIDs[peer]{
            removeAllAnchorsOriginatingFromARSessionWithID(sessionID)
            multipeerSession.peerSessionIDs.removeValue(forKey: peer)
        }
    }
    
    private func removeAllAnchorsOriginatingFromARSessionWithID(_ identifier: String){
        guard let frame = arView.session.currentFrame else {return}
        for anchor in frame.anchors{
            guard let anchorSessionID = anchor.sessionIdentifier else {continue}
            if anchorSessionID.uuidString == identifier {
                arView.session.remove(anchor: anchor)
            }
        }
    }
    
    func session(_ session: ARSession, didOutputCollaborationData data: ARSession.CollaborationData){
        guard let multipeerSession = multipeerSession else {return}
        if !multipeerSession.connectedPeers.isEmpty {
            guard let encodedData = try? NSKeyedArchiver.archivedData(withRootObject: data, requiringSecureCoding: true)
            else {fatalError("Unexpectedly failed to encode collaboration data.")}
            let dataIsCritical = data.priority == .critical
            multipeerSession.sendToAllPeers(encodedData, reliably: dataIsCritical)
        } else {
            print("deferred sending collaboration to later because there are no peers.")
        }
        
    }
    
}

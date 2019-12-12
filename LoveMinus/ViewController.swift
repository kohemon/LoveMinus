//
//  ViewController.swift
//  LoveMinus
//
//  Created by kohei saito on 2019/12/10.
//  Copyright © 2019 kohei saito. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import Speech
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var recordImageView: UIImageView!
    @IBOutlet weak var recordingLabel: UILabel!
    @IBOutlet weak var answerLabel: UILabel!
    @IBOutlet weak var loadingView: UIView!
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    private let audioEngine = AVAudioEngine()
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var chat: ChatStruct?
    
    private var inputMessage = ""
    private var isRecording = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let scene = SCNScene()
        sceneView.scene = scene
        sceneView.delegate = self
        sceneView.showsStatistics = true
        sceneView.debugOptions = ARSCNDebugOptions.showFeaturePoints
        
        speechRecognizer.delegate = self
        speechSynthesizer.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        sceneView.session.run(configuration)
    }
    
    @IBAction func tapeedRecording(_ sender: UILongPressGestureRecognizer) {
        switch sender.state{
        case .began:
            try! start()
            recordingLabel.text = "認識中..."
            isRecording = true
        case .ended:
            recordImageView.isUserInteractionEnabled = false
            audioEngine.stop()
            recognitionRequest?.endAudio()
            audioEngine.inputNode.removeTap(onBus: 0)
            loadingView.isHidden = false
            ChatApi.getMessage(message: inputMessage) { [unowned self] (chat) in
                self.chat = chat
                DispatchQueue.main.async {
                    self.loadingView.isHidden = true
                    self.recordingLabel.text = nil
                    self.speak(message: chat.result)
                }
                self.isRecording = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self.recordImageView.isUserInteractionEnabled = true
            }
        default:
            break
        }
    }
    
    private func start() throws {
        guard !isRecording else {
            return
        }
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }

        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: [])
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        self.recognitionRequest = recognitionRequest
        recognitionRequest.shouldReportPartialResults = true
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] (result, error) in
            guard let `self` = self else {
                return
            }
            guard self.isRecording else {
                return
            }
            var isFinal = false
            if let result = result {
                isFinal = result.isFinal
                self.inputMessage = result.bestTranscription.formattedString
                self.recordingLabel.text = result.bestTranscription.formattedString
            }

            if error != nil || isFinal {
                self.audioEngine.stop()
                self.audioEngine.inputNode.removeTap(onBus: 0)
                self.recognitionRequest = nil
                self.recognitionTask = nil
            }
        }

        let recordingFormat = audioEngine.inputNode.outputFormat(forBus: 0)
        audioEngine.inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()
    }
    
    private func stop() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
    }
    
    private func speak(message: String) {
        
        defer {
            disableAVSession()
        }
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't set because of an error.")
        }
        let utterance = AVSpeechUtterance(string: message)
        utterance.voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utterance.pitchMultiplier = 1
        self.speechSynthesizer.speak(utterance)
    }
    
    private func disableAVSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("audioSession properties weren't disable.")
        }
    }
    
}

extension ViewController: ARSCNViewDelegate {
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let planeAnchor = anchor as? ARPlaneAnchor else {fatalError()}
        
        guard let scene = SCNScene(named: "dog.scn", inDirectory: "art.scnassets/dog") else {fatalError()}
        guard let catNode = scene.rootNode.childNode(withName: "Dog", recursively: true) else {fatalError()}
        
        let magnification = 0.005
        catNode.scale = SCNVector3(magnification, magnification, magnification)
        
        catNode.position = SCNVector3(planeAnchor.center.x, 0, planeAnchor.center.z)

        DispatchQueue.main.async(execute: {
            node.addChildNode(catNode)
        })

    }
}

extension ViewController: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        recordImageView.tintColor = UIColor.systemBlue.withAlphaComponent(available ? 1 : 0.3)
        recordImageView.isUserInteractionEnabled = available
    }
}

extension ViewController: AVSpeechSynthesizerDelegate {
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        guard let chat = chat else {
            return
        }
        answerLabel.text = chat.result
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.answerLabel.text = nil
            }
    }
}

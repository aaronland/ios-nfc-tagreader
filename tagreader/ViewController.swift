//
//  ViewController.swift
//  tagreader
//
//  Created by asc on 7/8/20.
//

import UIKit
import CoreNFC

class ViewController: UIViewController, UINavigationControllerDelegate, NFCNDEFReaderSessionDelegate {

    let reuseIdentifier = "reuseIdentifier"
    var detectedMessages = [NFCNDEFMessage]()
    var session: NFCNDEFReaderSession?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBOutlet weak var tag_body: UITextView!
    
    @IBAction func clearTag() {
        self.tag_body.text.removeAll()
    }
    
    @IBAction func scanTag() {
                
        guard NFCNDEFReaderSession.readingAvailable else {
            print("NO NFC")
            return
        }
        
        clearTag()
        
        session = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        session?.alertMessage = "Hold your iPhone near the item to learn more about it."
        session?.begin()
        ()
        
    }
    
    // MARK: - NFCNDEFReaderSessionDelegate
    
    /// - Tag: processingTagData
    func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        
        print("MESSAGE")
        
        DispatchQueue.main.async {
            self.detectedMessages.append(contentsOf: messages)
        }
    }
    
    /// - Tag: processingNDEFTag
    func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        
        
        if tags.count > 1 {
            // Restart polling in 500ms
            let retryInterval = DispatchTimeInterval.milliseconds(500)
            session.alertMessage = "More than 1 tag is detected, please remove all tags and try again."
            DispatchQueue.global().asyncAfter(deadline: .now() + retryInterval, execute: {
                session.restartPolling()
            })
            return
        }
        
        // Connect to the found tag and perform NDEF message reading
        let tag = tags.first!
        session.connect(to: tag, completionHandler: { (error: Error?) in
            if nil != error {
                session.alertMessage = "Unable to connect to tag."
                session.invalidate()
                return
            }
            
            tag.queryNDEFStatus(completionHandler: { (ndefStatus: NFCNDEFStatus, capacity: Int, error: Error?) in
                if .notSupported == ndefStatus {
                    session.alertMessage = "Tag is not NDEF compliant"
                    session.invalidate()
                    return
                } else if nil != error {
                    session.alertMessage = "Unable to query NDEF status of tag"
                    session.invalidate()
                    return
                }
                
                tag.readNDEF(completionHandler: { (message: NFCNDEFMessage?, error: Error?) in
                    var statusMessage: String
                    if nil != error || nil == message {
                        statusMessage = "Fail to read NDEF from tag"
                    } else {
                        
                        print("Found 1 NDEF message")
                        statusMessage = "Found 1 NDEF message"
                        self.processMessage(message: message!)
                    }
                    
                    session.alertMessage = statusMessage
                    session.invalidate()
                })
            })
        })
    }
    
    /// - Tag: sessionBecomeActive
    func readerSessionDidBecomeActive(_ session: NFCNDEFReaderSession) {
        
    }
    
    /// - Tag: endScanning
    func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        
        // Check the invalidation reason from the returned error.
        if let readerError = error as? NFCReaderError {
            // Show an alert when the invalidation reason is not because of a
            // successful read during a single-tag read session, or because the
            // user canceled a multiple-tag read session from the UI or
            // programmatically using the invalidate method call.
            if (readerError.code != .readerSessionInvalidationErrorFirstNDEFTagRead)
                && (readerError.code != .readerSessionInvalidationErrorUserCanceled) {
                
                DispatchQueue.main.async {
                    print("SAD", error)
                }
            }
        }
        
        // To read new tags, a new session instance is required.
        self.session = nil
    }
    
    private func processMessage(message: NFCNDEFMessage) {
        
        var uri: String?
                
        let payload = message.records[0]
                
        let text_payload = payload.wellKnownTypeTextPayload()
        
        if text_payload.0 != nil {
            uri = text_payload.0
        }
        
        if uri == nil {
            let data = payload.payload
            uri = String(decoding: data, as: UTF8.self)
        }
        
        DispatchQueue.main.async {
            self.tag_body.text = uri
        }
    }
    

}


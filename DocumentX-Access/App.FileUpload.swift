//
//  App.FileUpload.swift
//  DocumentX-Access
//
//  Created by Lincoln on 6/9/21.
//

// [IMPORTANT] [TODO]
// Line "try? FileManager.default.removeItem(at: URL(string: url)!)" will delete any file that this app opened.
// This is ONLY OKAY if the LSSupportsOpeningDocumentsInPlace is TRUE. Otherwise it will delete the user's file unexpectedly.
// Before toggling that option, change the above line.

import Foundation
import UIKit

class AppFileUploadViewController: UIViewController {
    var currentField:UITextField? = nil
    var url: String?
    @IBOutlet weak var DocumentName: UITextField!
    @IBOutlet weak var Subject: UITextField!
    var event: Event!
    @IBOutlet weak var CancelButton: UIButton!
    var canCancel: Bool = true
    var showDontUploadButton: Bool = false
    @IBOutlet weak var DontUploadButton: UIButton!
    
    @IBAction func DontUploadButtonClicked(_ sender: Any) {
        Utils.option(title: "Warning: You're about to submit the attempt without any work.", message: "Press continue to confirm.").listen("Continued", handler: { _ in
            DispatchQueue.main.async {
                self.dismiss(animated: true, completion: {
                    if let url = self.url {
                        try? FileManager.default.removeItem(at: URL(string: url)!)
                    }
                    self.event.fire("Uploaded", string:"")
                    self.event.fire("Resolved")
                })
            }
        }).done()
    }
    override func viewDidLoad() {
        if self.url == nil {
            Core.runtimeData["UploadAwaitsFile"] = self
        }
        self.DontUploadButton.isHidden = !self.showDontUploadButton
        if !canCancel {
            self.CancelButton.isHidden = true
        }
        NotificationCenter.default.addObserver(self, selector: #selector(AppFileUploadViewController.keyboardWillShow), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(AppFileUploadViewController.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        API.checkAuthStatus().listen("APIErrorHandled", handler: { (_, _:Bool) in
            if !self.canCancel {
                DispatchQueue.main.async {
                    self.dismiss(animated: true, completion: {
                        if let url = self.url {
                            try? FileManager.default.removeItem(at: URL(string: url)!)
                        }
                        Core.runtimeData["UploadAwaitsFile"] = nil
                        self.event.fire("Resolved")
                    })
                }
            }
        }).done()
        self.event.listen("URLUpdated", handler: { _ in
            Utils.alert(title: "File received", message: "You can now press Done").done()
        }).done()
    }
    deinit {
        NotificationCenter.default.removeObserver(self);
    }
    
    @IBAction func DocumentNameOnEnter(_ sender: Any) {
        Subject.becomeFirstResponder()
    }
    
    @IBAction func SubjectOnEnter(_ sender: Any) {
        UploadDocument()
    }
    func UploadDocument(){
        // Get actual file name
        if let url = self.url {
            let alert = UIAlertController(title: "Uploading", message: "Please wait", preferredStyle: UIAlertController.Style.alert)
            self.present(alert, animated: true)
            
            let ActualFileName = URL(string: url)!.lastPathComponent
            
            let urlobj = URL(string: url)!
            
            let ifAccessed = urlobj.startAccessingSecurityScopedResource()
            do{
                let data = try Data(contentsOf: urlobj)
                API.uploadDocument(name: DocumentName.text ?? "", subject: Subject.text ?? "", fileData: data , fileName: ActualFileName).listen("Uploaded", handler: { (_, docID: String) in
                    DispatchQueue.main.async {
                        alert.dismiss(animated: true, completion: {
                            self.dismiss(animated: true, completion: {
                                Core.runtimeData["UploadAwaitsFile"] = nil
                                // Move the uploaded path to the cache and register cache
                                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                                let destinationURL = documentsPath.appendingPathComponent("Document."+docID)
                                try? FileManager.default.removeItem(at: destinationURL)
                                do {
                                    try FileManager.default.copyItem(at: URL(string: url)! , to: destinationURL)
                                    Core.UpdateDocumentLocalMetadata(docID, "Cache", destinationURL.absoluteString)
                                } catch let error {
                                    print("Copy Error: \(error.localizedDescription)")
                                    self.event.fire("CopyError")
                                }
                                
                                self.event.fire("Resolved")
                                self.event.fire("Uploaded", string: docID)
                            })
                        })
                    }

                }).listen("APIErrorHandled", handler:{
                    (_, _:Bool) in
                    DispatchQueue.main.async {
                        alert.dismiss(animated: true)
                        if self.canCancel {
                            self.dismiss(animated: true, completion: {
                                if let url = self.url {
                                    try? FileManager.default.removeItem(at: URL(string: url)!)
                                }
                                Core.runtimeData["UploadAwaitsFile"] = nil
                                self.event.fire("Resolved")
                            })
                        }
                    }
                }).listen("NetworkErrorHandled", handler:{
                    (_, _:Bool) in
                    DispatchQueue.main.async {
                        alert.dismiss(animated: true)
                        if self.canCancel {
                            self.dismiss(animated: true, completion: {
                                if let url = self.url {
                                    try? FileManager.default.removeItem(at: URL(string: url)!)
                                }
                                Core.runtimeData["UploadAwaitsFile"] = nil
                                self.event.fire("Resolved")
                            })
                        }
                    }
                }).done()

            } catch {
                Utils.alert(title: "Error", message: error.localizedDescription).done()
                if let url = self.url {
                    try? FileManager.default.removeItem(at: URL(string: url)!)
                }
                self.event.fire("Resolved")
            }
            
            if ifAccessed{
                urlobj.stopAccessingSecurityScopedResource()
            }
        } else {
            Utils.alert(title: "No file has been shared to the app", message: "Please share the file, then try again.").done()
        }
        
    }
    @IBAction func ConfirmClicked(_ sender: Any) {
        UploadDocument()
    }
    @IBAction func CancelClicked(_ sender: Any) {
        Utils.option(title: "You're about to cancel uploading this document.", message: "All entered information will not be saved. Continue?").listen("Continued", handler: { _ in
            Core.runtimeData["UploadAwaitsFile"] = nil
            self.event.fire("Resolved")
            self.dismiss(animated: true, completion: {
                if let url = self.url {
                    try? FileManager.default.removeItem(at: URL(string: url)!)
                }
            })
        }).done()
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        DocumentName.resignFirstResponder()
        Subject.resignFirstResponder()
    }
    @objc func keyboardWillHide(notification: NSNotification) {
      // move back the root view origin to zero
      self.view.frame.origin.y = 0
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {

      guard let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else {

        // if keyboard size is not available for some reason, dont do anything
        return
      }

      var shouldMoveViewUp = false

      // if active text field is not nil
      if let activeTextField = currentField {

        let bottomOfTextField = activeTextField.convert(activeTextField.bounds, to: self.view).maxY;
        
        let topOfKeyboard = self.view.frame.height - keyboardSize.height
        

        // if the bottom of Textfield is below the top of keyboard, move up
        if bottomOfTextField > topOfKeyboard {
          shouldMoveViewUp = true
        }
        if(shouldMoveViewUp) {
            self.view.frame.origin.y = 0 - (bottomOfTextField - topOfKeyboard)*1.2
        }
      }
    }

    @IBAction func editBegin(_ sender: Any) {
        self.currentField = sender as? UITextField
    }
    @IBAction func editEnd(_ sender: Any) {
        self.currentField = nil
    }
}

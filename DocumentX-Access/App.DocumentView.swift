//
//  App.DocumentView.swift
//  DocumentX-Access
//
//  Created by Lincoln on 1/9/21.
//

import Foundation
import PDFKit
import UIKit

class AppDocumentViewController: UIViewController {
    var docID: String?
    var PDF: PDFDocument?
    var event: Event?
    var attemptID: String?
    var exam: [String:Any]?
    var timer: Timer?
    var countdown: Int = 0
    var countdownTimer:Timer?
    var submittingWindow: AppFileUploadViewController?
    var networkErrorCount: Int = 0
    var shareable: Bool = false
    var shareURL: URL!
    var shareName: String!
    
    @IBOutlet weak var ShareButton: UIButton!
    @IBOutlet weak var CountdownLabel: UILabel!
    @IBOutlet weak var DocumentView: PDFView!
    override func viewDidLoad() {
        // If a event is given, then it will have those two events:
        // (Void) Presented
        // (Void) Dismissed
        if shareable {
            ShareButton.isEnabled = true
        } else {
            ShareButton.isEnabled = false
        }
        
        self.CountdownLabel.text = docID
        if self.attemptID != nil {
            self.MoreActionButton.isEnabled = false
            self.CountdownLabel.text = ""
            self.SyncCountdown()
            self.timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true, block: { _ in
                self.SyncCountdown()
            })
            if let maxTimeAllowed = self.exam?["maxTimeAllowed"] as? Int {
                self.countdown = maxTimeAllowed
            } else {
                Utils.alert(title: "Please contact your supervisor", message: "There's an error with exam timing. Using default 3600 seconds.").done()
                self.countdown = 3600
            }
            self.countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { _ in
                self.countdown -= 1
                self.CountdownLabel.text = Utils.SecondsToHumanReadable(time: self.countdown)
                if self.countdown <= 0 {
                    // Submit
                    self.SubmitAttempt(canCancel: false)
                    self.timer?.invalidate()
                    self.countdownTimer?.invalidate()
                }
                if self.countdown == 60 {
                    Utils.alert(title: "Last minute...", message: "Prepare to submit...").listen("Presented", handler: { e in
                        Timer.scheduledTimer(withTimeInterval: 3, repeats: false, block: { _ in
                            e.fire("Dismiss")
                        })
                    }).done()
                }
                if self.countdown == 120 {
                    Utils.alert(title: "The exam is about to conclude", message: "You have 2 minutes left").listen("Presented", handler: { e in
                        Timer.scheduledTimer(withTimeInterval: 3, repeats: false, block: { _ in
                            e.fire("Dismiss")
                        })
                    }).done()
                }
            })
         
        }

        
        DocumentView.document = PDF!
        DocumentView.autoScales = true
        DocumentView.backgroundColor = UIColor.black
        
        
        // Check for the previous page
        let pageNumber = Core.GetDocumentLocalMetadata(docID!, "CurrentPage") as? Int ?? 0

        if let page = PDF?.page(at: pageNumber) {
            DocumentView.go(to: page)
        }
        
        if docID == nil {
            Utils.alert(title: "We could not load this document.", message: "There's an internal error.").listen("Resolved", handler: { _ in
                self.dismiss(animated: true, completion: {
                    self.event?.fire("Dismissed")
                })
            }).done()
        }
//        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @IBOutlet weak var MoreActionButton: UIButton!
    @IBAction func MoreActionsPressed(_ sender: Any) {
        let vc = UIAlertController(title: nil, message: nil, preferredStyle: UIAlertController.Style.actionSheet)
        vc.popoverPresentationController?.sourceView = MoreActionButton
//        vc.addAction(UIAlertAction(title: "Edit Info...", style: UIAlertAction.Style.default, handler: EditDocumentInfo))
//        vc.addAction(UIAlertAction(title: "Share with people...", style: UIAlertAction.Style.default, handler: ShareDocument))
        vc.addAction(UIAlertAction(title: "Delete Document", style: UIAlertAction.Style.destructive, handler: DeleteDocument))
        vc.addAction(UIAlertAction(title: "Report a concern", style: UIAlertAction.Style.destructive, handler: ReportDocument))
        vc.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: nil))
        Utils.Present(vc).done()
        
    }
    func EditDocumentInfo(_: UIAlertAction){
        Utils.alert(title: "This feature is not available at this time", message: "It will be available soon.").done()
    }
    func DeleteDocument(_: UIAlertAction){
        Utils.option(title: "Do you really want to delete this document?", message: "This action can not be undone.").listen("Continued"){ _ in
            API.deleteDocument(docID: self.docID!).listen("Resolved"){ _ in
                DispatchQueue.main.async {
                    self.dismiss(animated: true, completion: nil)
                }
            }.done()
        }.done()
    }
    func ShareDocument(_: UIAlertAction){
        Utils.alert(title: "This feature is not available at this time", message: "It will be available soon.").done()
    }
    func ReportDocument(_: UIAlertAction){
        Utils.option(title: "Do you want to report a concern?", message: "This document may be checked by a moderator. If it's determined to be a concern, it will be removed from the platform.").listen("Continued"){ _ in
            API.reportDocument(docID: self.docID!).listen("Resolved"){ _ in
                DispatchQueue.main.async {
                    self.dismiss(animated: true, completion: nil)
                }
            }.done()
        }.done()
    }
    func SyncCountdown() {
        if let attemptID = self.attemptID {
            API.getAttemptByAttemptID(attemptID: attemptID, handleNetworkErrors: false).listen("Resolved", handler: { (_, attempt: [String:Any]) in
                let exam = attempt["exam"]! as! [String:Any]
                print(self.countdown)
                self.networkErrorCount = 0 // Resets networkErrorCount as the internet is back
                let maxTimeAllowed = (exam["maxTimeAllowed"] as! NSNumber).intValue
                let timeStarted = (attempt["timeStarted"] as! NSNumber).intValue
                print(Float(NSDate().timeIntervalSince1970), timeStarted, maxTimeAllowed)
                self.countdown = Int( timeStarted + maxTimeAllowed - Int(NSDate().timeIntervalSince1970) )
            }).listen("NetworkError", handler: { _ in
                self.networkErrorCount += 1
                if (self.networkErrorCount % 60) == 0 {
                    Utils.alert(title: "Continued Network Error", message: "In the last 30 minutes, we've been trying to connect with our server but got network error. Please check your internet connection so that the clock can be synchronised.").listen("Presented", handler: { e in
                        Timer.scheduledTimer(withTimeInterval: 10, repeats: false, block: { _ in
                            e.fire("Dismiss")
                        })
                    }).done()
                }
            }).done()
        }

    }
    
    
    @IBAction func closeDocument(_ sender: Any) {
        if self.attemptID != nil {
            Utils.option(title: "Would you like submit your attempt?", message: "If you don't want to leave the exam, press cancel").listen("Continued", handler: { _ in
                self.SubmitAttempt()
            }).done()
        } else {
            self.dismiss(animated: true, completion: {
                self.event?.fire("Dismissed")
            })
        }
    }
    func SubmitAttempt(canCancel: Bool = true){
        let event = Event()
        if let submittingWindow = self.submittingWindow {
            if canCancel == false {
                submittingWindow.CancelButton.isHidden = true
            }
            return
        }
        Utils.GetVC(storyboard: "App", identifier: "App.FileUpload").listen("Resolved", handler: { (_, vc: UIViewController) in
            let uploadVC = vc as! AppFileUploadViewController
            uploadVC.event = event
            uploadVC.canCancel = canCancel
            uploadVC.showDontUploadButton = true
            self.submittingWindow = uploadVC
            Utils.Present(uploadVC).done()
        }).done()
        event.listen("Uploaded", handler: { (_, docID: String) in
            let alert = Utils.alert(title: "Submitting...", message: "Please wait")
            API.finishAttempt(attemptID: self.attemptID!, docID: docID).listen("Resolved", handler: { _ in
                DispatchQueue.main.async {
                    self.timer?.invalidate()
                    self.countdownTimer?.invalidate()
                    self.dismiss(animated: true, completion: {
                        alert.fire("Dismiss")
                        alert.listen("Dismissed", handler: { _ in
                            self.dismiss(animated: true, completion: {
                                self.event?.fire("Dismissed")
                            })
                        }).done()
                    })
                }
            }).done()
        }).listen("Resolved", handler: { _ in
            self.submittingWindow = nil
        }).done()
    }
    
    @IBAction func ShareButtonClicked(_ sender: Any) {
        Core.shareDocumentInShareMenu(self.shareURL, name: self.shareName, view: ShareButton).done()
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.event?.fire("Presented")
    }
    override func viewWillDisappear(_ animated: Bool) {
        if let page = DocumentView.currentPage {
            Core.UpdateDocumentLocalMetadata(docID!, "CurrentPage", PDF?.index(for: page))
        } else {
            Core.UpdateDocumentLocalMetadata(docID!, "CurrentPage", 0)
        }

    }
    deinit {
        
    }
    override var prefersStatusBarHidden: Bool {
        return true
    }
}

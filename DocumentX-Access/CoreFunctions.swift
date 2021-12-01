//
//  CoreFunctions.swift
//  DocumentX-Access
//
//  Created by Lincoln on 2/9/21.
//

import Foundation
import UIKit
import PDFKit

class CoreFunctions {
    let utilities = Utilities()
    var initEvent: Event? = nil // If the program is busy when starting up, this should be an event that eventually gives "(Void) Resolved"; otherwise this would be nil
    var runtimeData:[String: Any] = [:]
    
    func ProcessURL(_ content: String = "") -> Event {
        if content == "" {
            let event = Event()
            event.fire("Resolved")
            return event
        }
        let splitted = content.components(separatedBy: "documentx://")
        if splitted.count == 1 {
            let event = Event()
            if let view = self.runtimeData["UploadAwaitsFile"] as? AppFileUploadViewController {
                view.url = content
                view.event.fire("URLUpdated")
                event.fire("Resolved")
            } else {
                Core.UploadFile(url: content).listen("Resolved", handler: { _ in
                    event.fire("Resolved")
                }).done()
            }
            return event
        }
        UIPasteboard.general.string = ""
        let contents = splitted[1].components(separatedBy: "/")
        if contents.count >= 1 {
            let option = contents[0]
            switch option {
                case "login":
                    let event = Event()
                    if contents.count >= 3 {
                        API.login(uID: contents[1], password: contents[2]).listen("Resolved", handler: { (event, status: Bool) in
                            if status {
                                self.utilities.alert(title: "You're now logged in.", message: "You can now access all your documents.").listen("Resolved", handler: { _ in
                                    event.fire("Resolved")
                                }).done()
                            } else {
                                event.fire("Resolved")
                            }
                        }).done()
                        return event
                    } else {
                        return self.utilities.alert(title: "Invalid Instructions", message: "The URL/Instruction is invalid.")
                    }
                case "token":
                    let event = Event()
                    if contents.count >= 3 {
                        API.UserInfo.uID = contents[1]
                        API.UserInfo.token = contents[2]
                        API.checkAuthStatus().listen("Resolved", handler: {(_, status: Bool) in
                            if(status){
                                self.utilities.alert(title: "You're now logged in", message: "You can now access all your documents.").listen("Resolved", handler: { _ in
                                    event.fire("Resolved")
                                }).done()
                            } else {
                                event.fire("Resolved")
                            }
                        }).done()
                        return event
                    } else {
                        return self.utilities.alert(title: "Invalid Instructions", message: "The URL/Instruction is invalid.")
                    }
                case "view":
                    if contents.count >= 2 {
                        return PresentDocument(docID: contents[1])
                    } else {
                        return self.utilities.alert(title: "Invalid Instructions", message: "The URL/Instruction is invalid.")
                    }
                case "logout":
                    let event = Event()
                    self.utilities.option(title: "Would you like to log out?", message: "Press continue to log out").listen("Continued", handler: { _ in
                        self.utilities.alert(title: "You've logged out", message: "Success").listen("Resolved", handler: { _ in
                            API.logout()
                            event.fire("Resolved")
                        }).done()
                    }).listen("Cancelled", handler: { _ in
                        event.fire("Resolved")
                    }).done()
                    return event
            case "dev":
                let event = Event()
                if contents.count >= 3 {
                    API.UserInfo.uID = "developer"
                    API.UserInfo.token = ""
                    API.UserInfo.name = ""
                    if API.GetSignature() == contents[2] {
                        var status = false
                        if contents[1] == "on" {
                            status = true
                        }
                        Core.UpdateAppLocalMetadata("Dev", status)
                        self.utilities.alert(title: "Developer mode had been set to \(String(status)).", message: "Please restart the app.").listen("Resolved", handler: { _ in
                            event.fire("Resolved")
                            exit(0)
                        }).done()
                    } else {
                        event.fire("Resolved")
                    }
                }
                return event
            case "script":
                let event = Event()
                if contents.count == 2 {
                    let scriptID = contents[1]
                    API.getScript(scriptID:scriptID).listen("Resolved", handler: { (_, script: String) in
                        Instructions.ExecuteScript(script).done()
                    }).done()
                    event.fire("Resolved")
                }
                return event

            default:
                return self.utilities.alert(title: "Invalid Instructions", message: "The URL/Instruction is invalid.")
                }
        } else {
            let event = Event()
            event.fire("Resolved")
            return event
        }
    }
    
    func InitialiseApplication(withUrl url: String = "") -> Event {
        // Do stuff
        let e = Event()
        Core.ProcessURL(url).listen("Resolved") { _ in
            API.requestForApplicationInitialisation().listen("Resolved") { _ in
                Core.UpdateDocumentColorScheme().listen("Resolved") { _ in
                    Core.CheckLocalMetadataStatus().listen("Resolved") { _ in
                        e.fire("Resolved")
                    }.done()
                }.done()
            }.done()
        }.done()
        
        return e
    }
    
    func CheckLocalMetadataStatus() -> Event {
        let e = Event()
        if let exitLog = Core.GetAppLocalMetadata("AbnormalExit") as? [String:Any] {
            let data = try? JSONSerialization.data(withJSONObject: exitLog, options: [])
            let event = String(data: data ?? Data(), encoding: .utf8) ?? "{}"
            API.GetURL("/log/appAbnormalExits", params: [
                "timeReported": String(NSDate().timeIntervalSince1970),
                "event": event
            ], handleAPIErrors: false, handleNetworkErrors: false).listen("NetworkRequestDidFinish") { _ in
//                The incident had been reported to the server
                Core.UpdateAppLocalMetadata("AbnormalExit", nil)
            }.listen("Completed") { _ in
                e.fire("Resolved")
            }.done()
        } else {
            e.fire("Resolved")
        }
        
        return e
    }
    
    func _PresentDocument(PDF: PDFDocument, withExistingVC PDFVC: AppDocumentViewController? = nil, documentInfo info: [String:Any], CallbackEvent event: Event, shareURL: URL? = nil) {
        let PDFViewerEvent = Event()
        let docID = info["docID"] as! String
        let shareable = info["shareable"] as? Bool ?? false
        print("INFO ",info)
        
        let shareName = info["sharename"] as? String ?? "Document"
        
        PDFViewerEvent.listen("Presented", handler: { _ in
            event.fire("Presented")
        }).listen("Dismissed", handler: { _ in
            event.fire("Dismissed")
            event.fire("Resolved")
        }).done()
        if let PDFVC = PDFVC {
            PDFVC.PDF = PDF
            PDFVC.event = PDFViewerEvent
            PDFVC.docID = docID
            PDFVC.shareable = shareable
            if shareable {
                PDFVC.shareURL = shareURL
                PDFVC.shareName = shareName
            }
            Utils.Present(PDFVC).done()
        } else {
            Utils.GetVC(storyboard: "App", identifier: "App.DocumentView").listen("Resolved", handler: { (_, _PDFViewerVC: UIViewController) in
                let PDFViewerVC = _PDFViewerVC as! AppDocumentViewController
                PDFViewerVC.event = PDFViewerEvent
                PDFViewerVC.PDF = PDF
                PDFViewerVC.docID = docID
                PDFViewerVC.shareable = shareable
                if shareable {
                    PDFViewerVC.shareURL = shareURL
                    PDFViewerVC.shareName = shareName
                }
                Utils.Present(PDFViewerVC).done()
            }).done()
        }
        return // Returns
    }
    
    func shareDocumentInShareMenu(_ item: URL, name: String, view: UIView? = nil) -> Event {
        let event = Event()
        // Copy the file to temp
        let documentsPath = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsPath.appendingPathComponent(name)
        
        try? FileManager.default.removeItem(at: destinationURL)
        do {
            try FileManager.default.copyItem(at: item, to: destinationURL)
        } catch let error {
            print("Copy Error: \(error.localizedDescription)")
        }
                
        DispatchQueue.main.async {
            let shareVC = UIActivityViewController(activityItems: [destinationURL], applicationActivities: nil)
            if let view = view {
                shareVC.popoverPresentationController?.sourceView = view
            } else {
                shareVC.popoverPresentationController?.sourceView = self.utilities.root()?.view
            }
            self.utilities.Present(shareVC).listen("Presented") { _ in
                event.fire("Presented")
            }.done()
        }
        return event
        
    }
    
    func PresentDocument(docID: String, withExistingVC PDFVC: AppDocumentViewController? = nil, attemptID: String? = nil) -> Event {
        // This function gives the following events:
        // (Void) Error
        // (Void) Cancelled
        // (Void) Downloaded
        // (Void) Presented [From AppDocumentViewController]
        // (Void) Dismissed [From AppDocumentViewController]
        // (Void) Resolved [Always called]
        let event = Event()
        var cancelled = false
        
        var alertEvent = Utils.alertWithCancel(title: "Loading Document Information...", message: "Please wait...").listen("Cancelled", handler: {_ in
            event.fire("Cancelled")
            event.fire("Resolved")
            cancelled = true
        })
        
        
        // Now the alert's out, request for the document
        API.getDocument(docID: docID, attemptID: attemptID).listen("Resolved", handler: { (_, info: [String:Any]) in
            let name = info["name"] as? String ?? "<Error while getting name>"
            // Now we have the information, dismiss the current alert

            alertEvent.listen("Dismissed", handler: { _ in
                // A Dismissed event follows a Dismiss event, which in this case means the api was successful & the current alert box should be dismissed
                
                if cancelled {
                    // No need to fire events as they're already fired when the button is pressed
                    return
                }
                

                if let location = self.GetDocumentLocation(docID: docID) {
                    let PDF = PDFDocument(url: URL(string: location)!)
                    if let PDF = PDF {
                        event.fire("Downloaded")
                        self._PresentDocument(PDF: PDF, withExistingVC: PDFVC, documentInfo: info, CallbackEvent: event, shareURL: URL(string: location)!)
                        return
                    }
                }
                // Otherwise, the document had not been downloaded. Download instead.
                
                
 
                // Download the PDF
                let DownloadEvent = self.DownloadDocument(docID: docID, attemptID: attemptID).listen("Downloaded", handler: { (_, link: String) in
                    let PDF = PDFDocument(url: URL(string: link)!)
                    if let PDF = PDF {
                        event.fire("Downloaded")
                        // Now, dismiss the alert
                        alertEvent.fire("Dismiss")
                        alertEvent.listen("Dismissed", handler: {_ in
                            if cancelled {
                                // No need to fire events as they've been fired when the button was pressed
                                return
                            }
                            self._PresentDocument(PDF: PDF, withExistingVC: PDFVC, documentInfo: info, CallbackEvent: event, shareURL: URL(string: link)!)
                            return
                        }).done()
                    } else {
                        // Not a PDF
                        let shareable = info["shareable"] as? Bool ?? false
                        if shareable {
                            
                            Utils.alert(title: "Please open this document in another app", message: "This is not a PDF file. Your changes in those app will not be saved unless you save it elsewhere or upload to the app.")
                            .listen("Presented"){ _ in
                                self.shareDocumentInShareMenu(URL(string: link)!, name: info["sharename"] as? String ?? "Document").done()
                            }.listen("Resolved", handler: { _ in
                                alertEvent.fire("Dismiss")
                                alertEvent.listen("Dismissed", handler: { _ in
                                    event.fire("Resolved")
                                }).done()
                            }).done()
                            
                        } else {
                            Utils.alert(title: "We could not open this document", message: "This is not a PDF file.").listen("Resolved", handler: { _ in
                                alertEvent.fire("Dismiss")
                                alertEvent.listen("Dismissed", handler: { _ in
                                    event.fire("Error")
                                    event.fire("Resolved")
                                }).done()
                            }).done()
                        }
                    }
                }).listen("DownloadFailure", handler: { _ in
                    Utils.alert(title: "We could not download your document", message: "Download failure").listen("Resolved", handler: { _ in
                        event.fire("Resolved")
                        return
                    }).done()
                })
                
                // Make a new alert with updated information
                alertEvent = Utils.alertWithCancel(title: "Downloading \"\(name)\"", message: "Please wait...").listen("Cancelled", handler: {_ in
                    event.fire("Cancelled")
                    event.fire("Resolved")
                    cancelled = true
                    DownloadEvent.fire("CancelDownload")
                })
                
            }).done()
            
        
            
            alertEvent.fire("Dismiss")
                        
        }).listen("APIErrorHandled", handler: {(_, _:Bool) in
//            print("Resolving")
//            Utils.alert(title: "Resolving", message: "Resolving")
            event.fire("Error")
            alertEvent.fire("Dismiss")
            alertEvent.listen("Dismissed", handler: { _ in
                event.fire("Resolved")
            }).done()
        }).listen("NetworkErrorHandled", handler: { (_, _:Bool) in
            event.fire("Error")
            alertEvent.fire("Dismiss")
            alertEvent.listen("Dismissed", handler: { _ in
                event.fire("Resolved")
            }).done()
        })
        .done()
        
        return event
        
    }
    
    func GetDocumentLocalMetadata(_ docID: String) -> [String:Any]? {
        return UserDefaults.standard.value(forKey: "User."+API.UserInfo.uID+".Document.Metadata.Local."+docID) as? [String:Any]
    }
    func GetDocumentLocalMetadata(_ docID: String, _ key: String) -> Any? {
        let val = UserDefaults.standard.value(forKey: "User."+API.UserInfo.uID+".Document.Metadata.Local."+docID) as? [String:Any]
        return val?[key]
    }
    func UpdateDocumentLocalMetadata(_ docID: String, _ key: String, _ value: Any?) {
        var Data = self.GetDocumentLocalMetadata(docID) ?? [:]
        Data[key] = value
        UserDefaults.standard.set(Data, forKey: "User."+API.UserInfo.uID+".Document.Metadata.Local."+docID)
    }
    func UpdateDocumentLocalMetadata(_ docID: String, _ value: Any?) {
        UserDefaults.standard.set(value, forKey: "User."+API.UserInfo.uID+".Document.Metadata.Local."+docID)
    }
    func GetUserLocalMetadata() -> [String:Any]? {
        return UserDefaults.standard.value(forKey: "User."+API.UserInfo.uID+".Metadata.Local") as? [String:Any]
    }
    func GetUserLocalMetadata(_ key: String) -> Any? {
        let val = UserDefaults.standard.value(forKey: "User."+API.UserInfo.uID+".Metadata.Local") as? [String:Any]
        return val?[key]
    }
    func UpdateUserLocalMetadata(_ key: String, _ value: Any?) {
        var Data = self.GetUserLocalMetadata() ?? [:]
        Data[key] = value
        UserDefaults.standard.set(Data, forKey: "User."+API.UserInfo.uID+".Metadata.Local")
    }
    func UpdateUserLocalMetadata(_ value: Any?) {
        UserDefaults.standard.set(value, forKey: "User."+API.UserInfo.uID+".Metadata.Local")
    }

    func GetAppLocalMetadata() -> [String:Any]? {
        return UserDefaults.standard.value(forKey: "App") as? [String:Any]
    }
    func GetAppLocalMetadata(_ key: String) -> Any? {
        let val = UserDefaults.standard.value(forKey: "App") as? [String:Any]
        return val?[key]
    }
    func UpdateAppLocalMetadata(_ key: String, _ value: Any?) {
        var Data = self.GetAppLocalMetadata() ?? [:]
        Data[key] = value
        UserDefaults.standard.set(Data, forKey: "App")
    }
    func UpdateAppLocalMetadata(_ value: Any?) {
        UserDefaults.standard.set(value, forKey: "App")
    }
    class FileDownloadDelegate: NSObject, URLSessionDownloadDelegate {
        // (String) DownloadComplete
        // Listens to (Void) CancelDownload -> Cancels download
        func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
            self.event.fire("DownloadComplete", string: location.absoluteString)
        }
        var event: Event
        var downloadTask: URLSessionDownloadTask?

        
        init(event: Event){
            self.event = event
        }
        
        func listenForCancelEvent(){
            self.event.listen("CancelDownload", handler: { _ in
                self.downloadTask?.cancel()
            }).done()
        }
    }
    func DownloadFile(url: String, saveAs name: String) -> Event {
        // (Void) DownloadFailure
        // (String) SaveError
        // (String) Downloaded [from URL]
        let e = Event()
        guard let url = URL(string: url) else {
            e.fire("DownloadFailure")
            return e
        }
        
        let downloadDelegate = CoreFunctions.FileDownloadDelegate(event: e)
        downloadDelegate.listenForCancelEvent()
        
        let urlSession = URLSession(configuration: .default, delegate: downloadDelegate, delegateQueue: OperationQueue())
        let downloadTask = urlSession.downloadTask(with: url)
        downloadDelegate.downloadTask = downloadTask
        e.listen("DownloadComplete", handler: { (event, url: String) in
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let destinationURL = documentsPath.appendingPathComponent(name)
            try? FileManager.default.removeItem(at: destinationURL)
                do {
                    try FileManager.default.copyItem(at: URL(string: url)! , to: destinationURL)
                    e.fire("Downloaded", string: destinationURL.absoluteString)
                } catch let error {
                    print("Copy Error: \(error.localizedDescription)")
                    e.fire("SaveError", string: error.localizedDescription)
                }
        }).done()
        downloadTask.resume()
        return e
    }
    func GetDocumentLocation(docID: String) -> String? {
        if let url = GetDocumentLocalMetadata(docID, "Cache") {
            
            if FileManager.default.fileExists(atPath: URL(string: url as! String)!.path){
                return (url as! String)
            }

        }
        return nil
    }
    func DownloadDocument(docID: String, attemptID: String?) -> Event {
        // (String) Downloaded
        // (Void) DownloadCancelled
        // (Void) Resolved
        // (Void) DownloadFailure
        let e = Event()
        API.getDownloadLink(docID: docID, attemptID: attemptID).listen("Resolved", handler: { (getAPIEvent, link: String) in
            // Download file, listen for their events and pass it onto the functionEvent
            let downloadEvent = self.DownloadFile(url: link, saveAs: "Document."+docID).listen("Downloaded", handler: { (_, url: String) in
                e.fire("Downloaded", string: url)
                self.UpdateDocumentLocalMetadata(docID, "Cache", url)
                e.fire("Resolved")
            }).listen("SaveError", handler: { (_, _:String) in
                e.fire("DownloadFailure")
                e.fire("Resolved")
            }).listen("DownloadFailure", handler: { _ in
                e.fire("DownloadFailure")
                e.fire("Resolved")
            })
            
            // Listens for the event for this functionEvent (e), and pass it to the downloadEvent so that it can be cancelled
            e.listen("CancelDownload", handler: { _ in
                downloadEvent.fire("CancelDownload")
                e.fire("DownloadCancelled")
                e.fire("Resolved")
            }).done()
            
        }).listen("APIErrorHandled", handler: { (_, _: Bool) in
            e.fire("DownloadFailure")
            e.fire("Resolved")
        }).done()
        
        return e
    }
    
    func UpdateDocumentColorScheme() -> Event {
        let e = Event()
        API.getUIColorScheme().listen("Resolved") { (_ , scheme:[String:Any]) in
            self.UpdateUserLocalMetadata("ColorScheme", scheme)
            e.fire("Resolved")
        }.done()
        return e
    }
    
    func GetShareability(of docID: String) -> Bool {
        // [TODO] Request the server for the permission to share.
        //        This will be implemented after I work out the way to sign & verify message using RSA.

        // For now, let's just make the server return it along with the document info.
        return true // Placeholder
    }
    
    func GetDocumentColorScheme(subject: String) -> [String:UIColor] {
        let banner: UIColor = UIColor(red: 184/255.0, green: 184/255.0, blue: 184/255.0, alpha: 100/100.0)
        let bannerText: UIColor = UIColor(red: 0/255.0, green: 0/255.0, blue: 0/255.0, alpha: 100/100.0)
        let idText: UIColor = UIColor(red: 152/255.0, green: 152/255.0, blue: 152/255.0, alpha: 100/100.0)
        let card: UIColor = UIColor(red: 40/255.0, green: 57/255.0, blue: 76/255.0, alpha: 100/100.0)
        let text: UIColor = UIColor(red: 255/255.0, green: 255/255.0, blue: 255/255.0, alpha: 100/100.0)
        
        var Scheme: [String: UIColor] = [
            "banner":banner,
            "bannertext":bannerText,
            "idtext":idText,
            "card":card,
            "text":text
        ] // Sets the default scheme
        
        if let scheme = self.GetUserLocalMetadata("ColorScheme") as? [String: Any] {
            if let colors = scheme[subject.lowercased()] as? [String:[Int]] {
                for (colorName, colorList) in colors {
                    if colorList.count == 4{
                        Scheme[colorName] = UIColor(red: CGFloat(colorList[0])/255.0, green: CGFloat(colorList[1])/255.0, blue: CGFloat(colorList[2])/255.0, alpha: CGFloat(colorList[3])/100.0)
                    } else {
                        print("WARN: Color scheme for \(subject).\(colorName) is invalid. Using default instead.")
                    }

                }
            }
        }
        
        return Scheme

    }
    
    func UploadFile(url: String) -> Event {
        // API Upload file
        let e = Event()        
        self.utilities.GetVC(storyboard: "App", identifier: "App.FileUpload").listen("Resolved", handler: {(_, vc: UIViewController) in
            // event must be resolved for the program to continue running.
            // this event will be passed onto the viewcontroller & resolved there.
            let viewcontroller = vc as! AppFileUploadViewController
            viewcontroller.event = e
            viewcontroller.url = url
            self.utilities.Present(viewcontroller).done()
        }).done()
        
//        self.utilities.alert(title: "Upload file stub", message: url).listen("Resolved", handler: { _ in
//            e.fire("Resolved")
//        }).done()

        return e
    }
    
    
}


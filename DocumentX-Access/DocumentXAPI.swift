//
//  DocumentXAPI.swift
//
//  Created by Lincoln on 29/6/21.
//

import UIKit
import CryptoKit
import Foundation
import CommonCrypto
import PDFKit

let APIVersion = ""
let APP_SECRET = ""

class DocumentXAPI {
    // App Settings
    let ServerAddress:String = "https://apis.mcsrv.icu"
    
    // Define UserInfo
    class XUserInfo {
        var uID: String = ""
        var token: String = ""
        var name: String = ""
        init(){
            let info = UserDefaults.standard.dictionary(forKey: "UserInfo") as? [String: String]
            if let info = info {
                if(info["uID"] != nil && info["token"] != nil && info["name"] != nil){
                    if(info["uID"] != "" && info["token"] != "" && info["name"] != ""){
                        self.uID = info["uID"]!
                        self.token = info["token"]!
                        self.name = info["name"]!
                    }
                }
            }
        }
        func clear() {
            self.uID = ""
            self.token = ""
            self.name = ""
            self.save()
        }
        func save(){
            let uInfo: Dictionary<String, String> = [
                "uID": self.uID,
                "token": self.token,
                "name": self.name
            ]
            UserDefaults.standard.set(uInfo, forKey: "UserInfo")
        }
        
    }
    
    // Create an instance of UserInfo
    var UserInfo = XUserInfo()
    
    // Utilities Class
    var utilities: Utilities
    
    init(){
        self.utilities = Utilities()
    }
    
    class APITaskDelegate: NSObject, URLSessionDelegate {
        func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            
            // Adapted from OWASP https://www.owasp.org/index.php/Certificate_and_Public_Key_Pinning#iOS

            if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust) {
                if let serverTrust = challenge.protectionSpace.serverTrust {
                    let isServerTrusted = SecTrustEvaluateWithError(serverTrust, nil)
                    if(isServerTrusted) {
//                        Disable certificate pinning
                        completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust:serverTrust))
                        return
                    }
                }
            }

            // Not trusted
            Core.UpdateAppLocalMetadata("AbnormalExit", [
                "timestamp":NSDate().timeIntervalSince1970,
                "uID": API.UserInfo.uID,
                "type":"certificate_validation_failure"
            ])
            
            Utils.alert(title: "We could not establish a trusted connection to our server.", message: "SSL Connection Failed. You might be on a school network or you might need to log in to your wifi. Contact your network administrator for help or switch to an alternative network.").listen("Resolved", handler: { _ in
                completionHandler(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
                
                exit(1)
            }).done()
//            Challenge
        }
    }
    
    func GetURL(_ route: String, params: Dictionary<String, String> = [:], handleAPIErrors: Bool = true, handleNetworkErrors: Bool = true) -> Event {
        
        // Returns an Event object. It can have the following states:
        // (Bool) NetworkError
        // (Bool) NetworkErrorHandled [Only possible if handleNetworkErrors = true]
        // (Void) NetworkRequestDidFinish
        // (Dictionary) NetworkRequestDidFinish [When data had been parsed]
        // (APIResponse) APIRequested
        // (APIResponse) APIError [Only possible if handleAPIErrors = true]
        // (Bool) APIErrorHandled [Only possible if handleAPIErrors = true]
        // (APIResponse) APISucceeded [Only possible if handleAPIErrors = true]
        // (Void) Completed
        
        
        // Check Docs for lifecycle.
        
        
        let url = URL(string: ServerAddress + route)!
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        request.httpMethod = "POST"

        // Add auto auth credentials
        var _params = params
        _params["apiversion"] = APIVersion
        if params["uID"]==nil{
            _params["uID"] = self.UserInfo.uID
            _params["token"] = self.UserInfo.token
        }
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        _params["accessedFrom"] = "DocumentXAccess/" + ( appVersion ?? "UnknownVersion" )
        _params["appSignature"] = self.GetSignature()
        
        // Construct Data
        var sdata = ""
        for (key, value) in _params {
            sdata = sdata + key.addingPercentEncoding(withAllowedCharacters: CharacterSet.alphanumerics)! + "=" + value.addingPercentEncoding(withAllowedCharacters: .alphanumerics)! + "&"
        }
        sdata.removeLast()
        request.httpBody = sdata.data(using: .utf8)
        
        // Prepare the event
        
        let event = Event()
        
        let session = URLSession(configuration: .default, delegate: DocumentXAPI.APITaskDelegate(), delegateQueue: OperationQueue())
        
        let task = session.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                event.fire("NetworkError")
                if handleNetworkErrors{
                    self.HandleNetworkErrors(event: event)
                }
                return
            }
            event.fire("NetworkRequestDidFinish")
            
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
            if let responseJSON = responseJSON as? [String: Any] {
                
                event.fire("NetworkRequestDidFinish", dictionary: responseJSON)
                
                // Attempt to parse data
                if let _code = responseJSON["code"]{
                    let code = _code as? Int ?? -10001
                    if let _message = responseJSON["message"] {
                        let message = _message as? String ?? "Apologies. Unexpected Error."
                        
                        event.fire("APIRequested", APIResponse: Event.APIResponse(code: code, message: message, data: responseJSON))
                        
                        if handleAPIErrors {
                            self.HandleAPIResponse(response: Event.APIResponse(code: code, message: message, data: responseJSON)).listen("Resolved", handler: {_ in
                                if code < 0 {
                                    event.fire("APIError", APIResponse: Event.APIResponse(code: code, message: message, data: responseJSON))
                                    self.HandleAPIErrors(response: Event.APIResponse(code: code, message: message, data: responseJSON), event: event)
                                    return
                                } else {

                                    event.fire("APISucceeded", APIResponse: Event.APIResponse(code: code, message: message, data: responseJSON))
                                
                                }
                            }).done()
                        }
                    }
                }
                event.fire("Completed")
            }
        }
        task.resume()
        return event
    }
    
    
    func GetURL(_ route: String, params: Dictionary<String, String> = [:], file: Data, fileName: String, handleAPIErrors: Bool = true, handleNetworkErrors: Bool = true) -> Event {
        
        // Returns an Event object. It can have the following states:
        // (Bool) NetworkError
        // (Bool) NetworkErrorHandled [Only possible if handleNetworkErrors = true]
        // (Void) NetworkRequestDidFinish
        // (Dictionary) NetworkRequestDidFinish [When data had been parsed]
        // (APIResponse) APIRequested
        // (APIResponse) APIError [Only possible if handleAPIErrors = true]
        // (Bool) APIErrorHandled [Only possible if handleAPIErrors = true]
        // (APIResponse) APISucceeded [Only possible if handleAPIErrors = true]
        // (Void) Completed
        
        
        // Check Docs for lifecycle.
        
        
        let url = URL(string: ServerAddress + route)!
        let boundary = UUID().uuidString
        
        var request = URLRequest(url: url)
        
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        request.httpMethod = "POST"

        // Add auto auth credentials
        var _params = params
        _params["apiversion"] = APIVersion
        if params["uID"]==nil{
            _params["uID"] = self.UserInfo.uID
            _params["token"] = self.UserInfo.token
        }
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        _params["accessedFrom"] = "DocumentXAccess/" + ( appVersion ?? "UnknownVersion" )
        _params["appSignature"] = self.GetSignature()
        
        // Construct Data
        var sdata = "\r\n"
//        var sdata = ""
        for (key, value) in _params {
            sdata = sdata + "--"+boundary+"\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n" + value + "\n"
        }
//        print(sdata)
        var xdata = sdata.data(using: .utf8)!
        xdata.append("--\(boundary)\r\n".data(using: .utf8)!)
        xdata.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        xdata.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        xdata.append(file)
        xdata.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = xdata
        
        // Prepare the event
        
        let event = Event()

        let session = URLSession(configuration: .default, delegate: DocumentXAPI.APITaskDelegate(), delegateQueue: OperationQueue())
        
        let task = session.dataTask(with: request) { data, response, error in
                guard let data = data, error == nil else {
                event.fire("NetworkError")
                if handleNetworkErrors{
                    self.HandleNetworkErrors(event: event)
                }
                return
            }
            event.fire("NetworkRequestDidFinish")
            
            let responseJSON = try? JSONSerialization.jsonObject(with: data, options: [])
            if let responseJSON = responseJSON as? [String: Any] {
                
                event.fire("NetworkRequestDidFinish", dictionary: responseJSON)
                
                // Attempt to parse data
                if let _code = responseJSON["code"]{
                    let code = _code as? Int ?? -10001
                    if let _message = responseJSON["message"] {
                        let message = _message as? String ?? "Apologies. Unexpected Error."
                        
                        event.fire("APIRequested", APIResponse: Event.APIResponse(code: code, message: message, data: responseJSON))
                        
                        if handleAPIErrors {
                            self.HandleAPIResponse(response: Event.APIResponse(code: code, message: message, data: responseJSON)).listen("Resolved", handler: {_ in
                                if code < 0 {
                                    event.fire("APIError", APIResponse: Event.APIResponse(code: code, message: message, data: responseJSON))
                                    self.HandleAPIErrors(response: Event.APIResponse(code: code, message: message, data: responseJSON), event: event)
                                    return
                                } else {
//                                  print("HandleAPIResponse!!", code)
                                        event.fire("APISucceeded", APIResponse: Event.APIResponse(code:     code, message: message, data: responseJSON))
                                }
                            }).done()
                        }
                    }
                }
                event.fire("Completed")
            }
        }
        task.resume()
        return event
    }

    func HandleAPIErrors(response data: Event.APIResponse, event: Event){
        switch data.code{
        case -400:
            self.utilities.alert(title: "Something went wrong (\(String(data.code)))", message: data.message).listen("Resolved", handler: { _ in
                event.fire("APIErrorHandled", bool: false)
                event.fire("Completed")
            }).done()
            // [TODO] Temporary commented out as there isn't a login page yet
        case -401:
            self.utilities.option(title: "You'll need to login to continue", message: "Press continue to login").listen("Continued", handler: { _ in
                self.utilities.PresentVC(storyboard: "App", identifier: "App.Login").listen("Continued", handler: {
                        _ in
                        event.fire("APIErrorHandled", bool: true)
                    }).done()
            }).listen("Cancelled", handler: { _ in
                event.fire("APIErrorHandled", bool: false)
            }).done()
        case -402, -405, -406:
            self.utilities.PresentVC(storyboard: "App", identifier: "App.Login").listen("Resolved", handler: { _ in
                event.fire("APIErrorHandled", bool: true)
            }).done()
//        case -401, -402, -405, -406:
//            self.utilities.alert(title: "We could not verify your identity.", message: "Please log in again. (\(String(data.code)): \(data.message))").listen("Resolved", handler: { _ in
//                event.fire("APIErrorHandled", bool: true)
//                event.fire("Resolved")
//            }).done()
        default:
            self.utilities.alert(title: "An Error Occured (\(String(data.code)))", message: data.message).listen("Resolved", handler: { _ in
                event.fire("APIErrorHandled", bool: true)
                event.fire("Completed")
            }).done()
        }
        
    }
    
    func HandleNetworkErrors(event: Event){
        self.utilities.alert(title: "Network Error", message: "Please check your connection").listen("Resolved", handler: { _ in
            event.fire("NetworkErrorHandled", bool: true)
            event.fire("Completed")
        }).done()
    }
    
    func HandleAPIResponse(response: Event.APIResponse) -> Event {
        let e = Event()
        let codeabsolute = abs(response.code) as Int
        switch codeabsolute {
        case 1200: // Alert with OK - alert content must be stored in the response as "alert"
            let alert = response.data["alert"] as? [String:Any] ?? [
                "message":"",
                "title":""
            ]
            self.utilities.alert(title: alert["title"] as? String ?? "", message: alert["message"] as? String ?? "").listen("Resolved", handler: { _ in
                e.fire("Resolved")
            }).done()
        case 1201: // Alert with option - and Continue will jump to a storyboard vc
            let alert = response.data["option"] as? [String:Any] ?? [
                "message" : "",
                "title" : "",
                "continue":[
                    "storyboard":"App",
                    "identifier":"App.Main"
                ]
            ]
            self.utilities.option(title: alert["title"] as? String ?? "", message: alert["message"] as? String ?? "").listen("Continued", handler: { _ in
                let confirm = alert["continue"] as? [String:String] ?? [:]
                if let storyboard = confirm["storyboard"]{
                    if let identifier = confirm["identifier"] {
                        self.utilities.PresentVC(storyboard: storyboard, identifier: identifier).listen("Presented", handler: { _ in
                            e.fire("Resolved")
                        }).done()
                        return
                        // Otherwise, the app will crash
                    }
                }
                e.fire("Resolved")
            }).listen("Cancelled", handler: { _ in
                e.fire("Resolved")
            }).done()
        case 1202: // Alert before presenting a vc
            let alert = response.data["alertwithvc"] as? [String:String] ?? [
                "title":"",
                "message":"",
                "storyboard":"App",
                "identifier":"App.Main"
            ]
            self.utilities.alert(title: alert["title"] ?? "", message: alert["message"] ?? "").listen("Resolved", handler: { _ in
                if let storyboard = alert["storyboard"]{
                    if let identifier = alert["identifier"] {
                        self.utilities.PresentVC(storyboard: storyboard, identifier: identifier).listen("Presented", handler: { _ in
                            e.fire("Resolved")
                        }).done()
                        return
                        // Otherwise, the app will crash
                    }
                }
                e.fire("Resolved")
            }).done()

        case 1203: // presentvc
            let vc = response.data["presentvc"] as? [String:String] ?? [
                    "storyboard":"App",
                    "identifier":"App.Main"
            ]
            if let storyboard = vc["storyboard"]{
                if let identifier = vc["identifier"] {
                    self.utilities.PresentVC(storyboard: storyboard, identifier: identifier).listen("Presented", handler: { _ in
                        e.fire("Resolved")
                    }).done()
                    return e
                    // Otherwise, the app will crash as the storyboard can not be found
                }
            }
            e.fire("Resolved")
        case 1204: // ProcessURL
            if let url = response.data["url"] as? String {
                Core.ProcessURL(url).listen("Resolved", handler: { _ in
                    e.fire("Resolved")
                }).done()
            }
        
        case 1300: // Advanced Instructions
            return Instructions.ExecuteScript(response.data["script"] as? String ?? "")
            
            
        default:
            e.fire("Resolved")
        }
        return e
    }
    
    func getScript(scriptID: String) -> Event {
        return GetURL("/getScript", params: [
            "scriptID": scriptID
        ]).listen("APISucceeded") { (event, response: Event.APIResponse) in
            event.fire("Resolved", string: response.data["script"] as? String ?? "")
        }
    }
        
    
    func login(uID: String, password:String) -> Event {
        let hash = Crypto().hexString(SHA256.hash(data: password.data(using: .utf8)!).makeIterator())
        self.UserInfo.token = "" // To ensure that the secret can be correctly generated
        self.UserInfo.uID = uID // To ensure that the secret can be correctly generated

        return GetURL("/login", params: ["uID":uID,"password":hash]).listen("APISucceeded", handler: { (event: Event, response: Event.APIResponse) in
            self.UserInfo.uID = response.data["uID"] as! String
            self.UserInfo.name = response.data["name"] as! String
            self.UserInfo.token = response.data["token"] as! String
            self.UserInfo.save()
            event.fire("Resolved", bool: true)
        }).listen("APIError", handler: { (event: Event, _: Event.APIResponse) in
            event.fire("Resolved", bool: false)
        })
    }
    
    func checkAuthStatus() -> Event {
        return GetURL("/getAuthStatus").listen("APISucceeded", handler: {(event: Event, response: Event.APIResponse) in
            let res = response.data
            self.UserInfo.name = res["name"] as? String ?? "<Error while getting name>"
            self.UserInfo.save()
            event.fire("Resolved", bool: true)
        }).listen("APIError", handler: {(event: Event, _: Event.APIResponse) in
            event.fire("Resolved", bool: false)
        })
    }
    
    func getPreviewLink(docID: String, attemptID: String?) -> Event {
        return GetURL("/getPreviewLink", params: [
            "docID": docID,
            "attemptID":attemptID ?? ""
        ]).listen("APISucceeded", handler: { (event, response: Event.APIResponse) in
            event.fire("Resolved", string: self.ServerAddress + (response.data["link"]! as! String).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)
        })
    }
    func getDownloadLink(docID: String, attemptID: String?) -> Event {
        return GetURL("/getDownloadLink", params: [
            "docID": docID,
            "attemptID":attemptID ?? ""
        ]).listen("APISucceeded", handler: { (event, response: Event.APIResponse) in
            event.fire("Resolved", string: self.ServerAddress + (response.data["link"]! as! String).addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!)
        })
    }
    
    func getDocument(docID: String, attemptID: String? = nil) -> Event {
        return GetURL("/getDocumentByID", params: [
            "docID": docID,
            "attemptID":attemptID ?? ""
        ]).listen("APISucceeded", handler: { (event, response: Event.APIResponse) in
            event.fire("Resolved", dictionary: response.data["result"]! as! [String : Any])
        })
    }
    func deleteDocument(docID: String) -> Event {
        return GetURL("/deleteDocumentByID", params: [
            "docID": docID
        ]).listen("APISucceeded", handler: { (event, response: Event.APIResponse) in
            event.fire("Resolved")
        })
    }
    func reportDocument(docID: String) -> Event {
        return GetURL("/reportDocumentByID", params: [
            "docID": docID
        ]).listen("APISucceeded", handler: { (event, response: Event.APIResponse) in
            event.fire("Resolved")
        })
    }
    
    func getDocuments() -> Event {
        return GetURL("/getDocuments", params: [
            "start":"0",
            "end":"0"
        ]).listen("APISucceeded", handler: { (event, response: Event.APIResponse) in
            event.fire("Resolved", list: response.data["result"] as? [Any] ?? [])
        })
        
    }
    
    func searchDocuments(name: String) -> Event {
        return GetURL("/searchDocumentsByName", params: [
            "start":"0",
            "end":"0",
            "name":name
        ]).listen("APISucceeded", handler: { (event, response: Event.APIResponse) in
            event.fire("Resolved", list: response.data["result"] as? [Any] ?? [])
        })
    }
    
    func getUIColorScheme() -> Event {
        return GetURL("/getUIColorScheme").listen("APISucceeded", handler: { (event, response: Event.APIResponse) in
            event.fire("Resolved", dictionary: response.data["colorscheme"] as? [String:Any] ?? [:])
        })
    }
    
    func requestForApplicationInitialisation() -> Event {
        return GetURL("/initialise").listen("APISucceeded", handler: { (event, response: Event.APIResponse) in
            if let refusal = response.data["refusal"] as? Bool {
                if refusal == true {
                    //                Don't fire resolve.
                    return
                }
            }
            event.fire("Resolved")
        }).listen("APIError") { (event, _: Event.APIResponse) in
            event.fire("Resolved")
        }
    }
    
    
    func uploadDocument(name:String, subject:String, fileData:Data, fileName: String) -> Event {
        return GetURL("/uploadDocument", params: [
            "name":name,
            "subject":subject
        ], file: fileData, fileName: fileName).listen("APISucceeded", handler: { (e, response:Event.APIResponse) in
            e.fire("Uploaded")
            e.fire("Uploaded", string: response.data["docID"] as? String ?? "")
        })
    }
    
    func getExamAttemptsInProgress() -> Event {
        return GetURL("/exam/getExamAttemptsInProgress", params: [:]).listen("APISucceeded", handler: { (e, response:Event.APIResponse) in
            e.fire("Resolved", list: response.data["attempts"] as? [[String:Any]] ?? [])
        })
    }
    
    func getExams() -> Event {
        return GetURL("/exam/getExamsByUID").listen("APISucceeded", handler: { (e, response:Event.APIResponse) in
            e.fire("Resolved", list: response.data["exams"] as? [[String:Any]] ?? [])
        })
    }
    
    func getExamByExamID(examID: String) -> Event {
        return GetURL("/exam/getExamByExamID", params: [
            "examID":examID
        ]).listen("APISucceeded", handler: { (e, response:Event.APIResponse) in
            e.fire("Resolved", dictionary: response.data["exam"] as? [String:Any] ?? [:])
        })
    }
    
    func getAttemptByAttemptID(attemptID: String, handleNetworkErrors: Bool = true) -> Event {
        return GetURL("/exam/getAttemptByAttemptID", params: [
            "attemptID" : attemptID
        ], handleNetworkErrors: handleNetworkErrors).listen("APISucceeded", handler: { (e, response:Event.APIResponse) in
            e.fire("Resolved", dictionary: response.data["attempt"] as? [String:Any] ?? [:])
        })
    }
    
    func newAttempt(examID: String) -> Event {
        return GetURL("/exam/newAttempt", params: [
            "examID":examID
        ]).listen("APISucceeded", handler: { (e, response:Event.APIResponse) in
            e.fire("Resolved", string: response.data["attemptID"] as? String ?? "")
        })
    }
    
    func finishAttempt(attemptID:String, docID: String) -> Event{
        return GetURL("/exam/finishAttempt", params: [
            "attemptID":attemptID,
            "docID":docID
        ]).listen("APISucceeded", handler: { (e, _:Event.APIResponse) in
            e.fire("Resolved")
        })
    }

        
    func GetSignature() -> String {
        let timestamp = NSDate().timeIntervalSince1970
        let time = Int(timestamp)-Int(timestamp)%10
        let s = self.UserInfo.uID.lowercased() + self.UserInfo.token.lowercased() + String(time) + APP_SECRET
        let sig = Crypto().hexString(SHA256.hash(data: s.data(using: .utf8)!).makeIterator())
        return sig
    }
    
    
    func logout(){
        self.UserInfo.clear()
    }
    

}

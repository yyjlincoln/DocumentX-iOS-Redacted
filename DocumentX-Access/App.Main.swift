//
//  App.Main.swift
//  DocumentX-Access
//
//  Created by Lincoln on 4/9/21.
//

import Foundation
import UIKit
import SwiftUI

class AppMainViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UISearchBarDelegate {
    
    @IBOutlet weak var SearchBar: UISearchBar!
    @IBOutlet weak var MainTitle: UILabel!
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
//        print("Load count", self.Documents.count)
        return self.Documents.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! DocumentCollectionViewCell
        // Initialise cell content
        cell.exam = nil
        cell.examID = nil
        cell.attemptID = nil
        cell.DocumentNameLabel.text = ""
        cell.SubjectNameLabel.text = ""
        cell.DocIDLabel.text = ""
        cell.docID = ""
        cell.DownloadedIcon.isHidden = true
        cell.ExamIndicator.isHidden = true
        // Now, reload the cell content
        
        cell.DocumentNameLabel.text = self.Documents[indexPath.row]["name"] as? String ?? "<Error>"
        cell.SubjectNameLabel.text = self.Documents[indexPath.row]["subject"] as? String ?? "Error"
        cell.DocIDLabel.text = "\(self.Documents[indexPath.row]["docID"] as! String)"
        cell.docID = self.Documents[indexPath.row]["docID"] as! String
        cell.exam = self.Documents[indexPath.row]["exam"] as? [String:Any]
        // Cell icons
        if Core.GetDocumentLocation(docID: cell.docID) != nil {
            // Downloaded
            cell.DownloadedIcon.isHidden = false
        } else {
            cell.DownloadedIcon.isHidden = true
        }
        
        cell.ExamIndicator.isHidden = true
        if let examID = self.Documents[indexPath.row]["examID"] as? String {
            cell.ExamIndicator.isHidden = false
            cell.examID = examID
//            cell.DocIDLabel.text = examID
            cell.DocIDLabel.text = "\(String((cell.exam?["maxAttemptsAllowed"] as? Int ?? 0) - (cell.exam?["attemptsNum"] as? Int ?? 0))) attempt(s) left - \(Utils.SecondsToHumanReadable(time: (cell.exam?["maxTimeAllowed"] as? NSNumber)?.intValue ?? 0))"
        }
        if let attemptID = self.Documents[indexPath.row]["attemptID"] as? String {
            cell.ExamIndicator.isHidden = false
            cell.attemptID = attemptID
//            cell.DocIDLabel.text = "ATTEMPT " + attemptID
        }
        
        // Cell colors
        let defaultColor = UIColor(red: 1, green: 0, blue: 0, alpha: 1)
        let colors = Core.GetDocumentColorScheme(subject: self.Documents[indexPath.row]["subject"] as? String ?? "Error")
        cell.DocIDLabel.textColor = colors["idtext"] ?? defaultColor
        cell.BannerView.backgroundColor = colors["banner"] ?? defaultColor
        cell.SubjectNameLabel.textColor = colors["bannertext"] ?? defaultColor
        cell.Card.backgroundColor = colors["card"] ?? defaultColor
        cell.DocumentNameLabel.textColor = colors["text"] ?? defaultColor
        
        return cell
    }
    
    @IBOutlet weak var DocumentCollectionView: UICollectionView!
    @IBOutlet weak var UsernameLabel: UILabel!
    @IBOutlet weak var DocumentListSubView: UIView!
    @IBOutlet weak var FilesNumberIndicatorLabel: UILabel!
    var Documents: [[String:Any]] = [] // Documents being displayed
    var AllDocuments: [[String:Any]] = [] // All documents from the server
    override var prefersStatusBarHidden: Bool {
        return true
    }
    override func viewDidLoad() {
        SearchBar.delegate = self
        SearchBar.searchTextField.backgroundColor = UIColor.black
        SearchBar.searchTextField.textColor = UIColor.white
        SearchBar.backgroundColor = UIColor(red: 0.055, green: 0.078, blue: 0.106, alpha: 1.0)
        SearchBar.barTintColor = UIColor(red: 0.055, green: 0.078, blue: 0.106, alpha: 1.0)
        SearchBar.tintColor = UIColor(red: 0.055, green: 0.078, blue: 0.106, alpha: 1.0)
        UsernameLabel.text = API.UserInfo.name
        FilesNumberIndicatorLabel.text = "Loading..."
//        // Uses DocumentLIstView - removed due to unsatisfactory performance
//        Utils.GetVC(view: AnyView(DocumentListView())).listen("Resolved", handler: { (_, vc: UIViewController) in
//            vc.view.frame = self.DocumentListSubView.bounds
//            self.DocumentListSubView.addSubview(vc.view)
//
//            self.addChild(vc)
//            vc.didMove(toParent: self)
//        }).done()
        MainTitle.text = "\(API.UserInfo.name)'s Library"
        self.DocumentCollectionView.dataSource = self
        self.DocumentCollectionView.delegate = self
    }
    
    
    override func viewDidAppear(_ animated: Bool) {
        self.loadData()
    }

    @IBOutlet weak var ActivityIndicator: UIActivityIndicatorView!
    

    @IBAction func logout(){
        API.logout()
        self.dismiss(animated: true)
    }
    
    func loadData(){
//        self.Documents = []
//        self.AllDocuments = []
//        There is a delay between documents are loaded & the view is updated. This will cause the indexPath.row to be out of range - remove this and simply use local variable Documents, which will update the dictionary in one go.
        ActivityIndicator.isHidden = false
        if let text = SearchBar.text {
            if text != "" {
                self.HandleSearch(text)
                return
            }
        }
        let e = Event()
        var Documents: [[String:Any]] = []
        API.getExamAttemptsInProgress().listen("Resolved", handler: { ( _, _attempts: [Any]) in
            let attempts = _attempts as! [[String:Any]]
            if attempts.count > 0 {
                Utils.alert(title: "You've lost the access to your exam", message: "You forcibly left the exam by killing the app. You may start another attempt if it's allowed.").done()
                for attempt in attempts {
                    API.finishAttempt(attemptID: attempt["attemptID"]! as! String, docID: "").done()
//                    let examID = attempt["examID"] as! String
//                    let attemptID = attempt["attemptID"] as! String
//                    // Adds the exam to the list
//                    let exam = attempt["exam"] as? [String:Any] ?? [:]
//
//                    Documents.append([
//                        "docID":exam["docID"] ?? "",
//                        "exam":exam,
//                        "examID":examID,
//                        "attemptID":attemptID,
//                        "subject":"EXAM IN PROGRESS",
//                        "name":exam["name"] ?? ""
//                    ])
                }
            }
            e.fire("getExamAttemptsFinished")
        }).done()
        
        e.listen("getExamAttemptsFinished", handler: { _ in
            API.getExams().listen("Resolved", handler: { ( _, _exams: [Any]) in
                let exams = _exams as! [[String:Any]]
                if exams.count > 0 {
                    for exam in exams {
                        let examID = exam["examID"] as! String
                        Documents.append([
                            "docID":exam["docID"] ?? "",
                            "examID":examID,
                            "exam":exam,
                            "subject":"EXAM",
                            "name":exam["name"] ?? ""
                        ])
                    }
                }
                e.fire("getExamsFinished")
            }).done()
        }).done()
        
        e.listen("getExamsFinished", handler: { _ in
            API.getDocuments().listen("Resolved", handler: { (_, documents: [Any]) in
                Documents += (documents as? [[String:Any]] ?? [])
                self.Documents = Documents
                self.AllDocuments = Documents
                DispatchQueue.main.async {
                    self.FilesNumberIndicatorLabel.text = "\(String(Documents.count)) files"
                    self.DocumentCollectionView.reloadData()
                    self.ActivityIndicator.isHidden = true
                }
            }).listen("APIError", handler: { (_, err: Event.APIResponse) in
                DispatchQueue.main.async {
                    self.Documents = Documents
                    self.AllDocuments = Documents
                    self.DocumentCollectionView.reloadData()
                }
            }).done()
        }).done()
    }
    
    @IBAction func RefreshClicked(_ sender: Any) {
        loadData()
    }
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        self.Documents = []
        self.DocumentCollectionView.reloadData()
        self.MainTitle.text = "Searching in \(API.UserInfo.name)'s Library"
        self.FilesNumberIndicatorLabel.text = "From "   + "\(String(self.AllDocuments.count)) files"
        
    }
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        self.HandleSearch(SearchBar.text ?? "")
    }
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.HandleSearch(SearchBar.text ?? "")
        SearchBar.resignFirstResponder()
    }
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        self.HandleSearch(SearchBar.text ?? "")
    }
    func HandleSearch(_ text: String){
        if text == ""{
            self.ActivityIndicator.isHidden = true
            self.Documents = self.AllDocuments
            self.DocumentCollectionView.reloadData()
            self.FilesNumberIndicatorLabel.text = "\(String(self.Documents.count)) files"
            self.MainTitle.text = "\(API.UserInfo.name)'s Library"
        } else {
            self.MainTitle.text = "Searching..."
            self.FilesNumberIndicatorLabel.text = "Just a second..."
            
            API.searchDocuments(name: text).listen("Resolved", handler: { (_, documents: [Any]) in
                DispatchQueue.main.async {
                    self.MainTitle.text = "Search Results"
                    self.Documents = documents as? [[String:Any]] ?? []
                    self.FilesNumberIndicatorLabel.text = text + " -> " + "\(String(self.Documents.count)) files"
                    self.DocumentCollectionView.reloadData()
                    self.ActivityIndicator.isHidden = true
                }
                

            }).done()
        }
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        SearchBar.resignFirstResponder()
    }
}


class DocumentCollectionViewCell: UICollectionViewCell {
    @IBOutlet weak var SubjectNameLabel: UILabel!
    @IBOutlet weak var DocumentNameLabel: UILabel!
    @IBOutlet weak var DocIDLabel: UILabel!
    @IBOutlet weak var DownloadedIcon: UIImageView!
    var docID: String = ""
    var examID: String?
    var attemptID: String?
    var exam: [String:Any]?
    @IBOutlet weak var Card: UIView!
    @IBOutlet weak var BannerView: UIView!
    @IBOutlet weak var ExamIndicator: UIImageView!
    
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let attemptID = self.attemptID {
            // Ongoing exam
            Utils.GetVC(storyboard: "App", identifier: "App.DocumentView").listen("Resolved", handler: { (_, _PDFViewerVC: UIViewController) in
                let PDFViewerVC = _PDFViewerVC as! AppDocumentViewController
                PDFViewerVC.attemptID = attemptID
                PDFViewerVC.exam = self.exam
                Core.PresentDocument(docID: self.docID, withExistingVC: PDFViewerVC, attemptID: attemptID).done()
            }).done()
        } else if let examID = self.examID {
            Utils.option(title: "Start a new attempt?", message: "You can only start a maximum of \(String(self.exam?["maxAttemptsAllowed"] as? Int ?? 0)) attempt(s). You've attempted this exam \(String(self.exam?["attemptsNum"] as? Int ?? 0)) time(s). This exam lasts for \(Utils.SecondsToHumanReadable(time: (self.exam?["maxTimeAllowed"] as? NSNumber)?.intValue ?? 0)), and you will not be able to leave the exam mid-way.").listen("Continued", handler:{ _ in
                API.newAttempt(examID: examID).listen("Resolved", handler: { (_, attemptID: String) in
                    Utils.GetVC(storyboard: "App", identifier: "App.DocumentView").listen("Resolved", handler: { (_, _PDFViewerVC: UIViewController) in
                        let PDFViewerVC = _PDFViewerVC as! AppDocumentViewController
                        PDFViewerVC.attemptID = attemptID
                        PDFViewerVC.exam = self.exam
                        Core.PresentDocument(docID: self.docID, withExistingVC: PDFViewerVC, attemptID: attemptID).done()
                    }).done()
                }).done()
            }).done()
            // TODO: Request API, request for AttemptID & hence get the access to the doc

        } else {
            Core.PresentDocument(docID:  self.docID).done()
        }
    }
}

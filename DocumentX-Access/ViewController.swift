//
//  ViewController.swift
//  DocumentX Access
//
//  Created by Lincoln on 30/6/21.
//

import UIKit
import SwiftUI

class ViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBOutlet weak var RetryButton: UIButton!
    @IBAction func RetryClicked(_ sender: Any) {
        self.initialise()
    }
    override func viewWillAppear(_ animated: Bool) {
        self.RetryButton.isHidden = true
        Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { _ in
            self.RetryButton.isHidden = false
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        if let event = Core.initEvent {
            event.listen("Resolved", handler: { _ in
                self.initialise()
            }).done()
        } else {
            self.initialise()
        }
    }
    func initialise(){
        Core.initEvent = nil // Reset the initEvent as it has already been initialised - so further viewDidAppear events would not have to wait for the Resolved event
        API.checkAuthStatus().listen("Resolved", handler: { (_, status: Bool) in
            if status{
                Utils.PresentVC(storyboard: "App", identifier:"App.Main").listen("Presented", handler: { _ in
                }).done()
            }
        }).done()
    }

}


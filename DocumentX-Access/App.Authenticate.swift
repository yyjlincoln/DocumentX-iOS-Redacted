//
//  App.Authenticate.swift
//  DocumentX-Access
//
//  Created by Lincoln on 1/9/21.
//

import Foundation
import UIKit

class AppLoginViewController: UIViewController {
    var currentField: UITextField?
    @IBOutlet weak var UsernameTextField: UITextField!
    
    @IBOutlet weak var PasswordTextField: UITextField!
    
    @IBAction func UsernameTextboxEnter(_ sender: Any) {
        PasswordTextField.becomeFirstResponder()
    }
    override func viewDidLoad() {
        NotificationCenter.default.addObserver(self, selector: #selector(AppLoginViewController.keyboardWillShow), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(AppLoginViewController.keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    deinit {
        NotificationCenter.default.removeObserver(self);
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
    }
    @IBAction func editBegin(_ sender: Any) {
        self.currentField = sender as? UITextField
    }
    @IBAction func editEnd(_ sender: Any) {
        self.currentField = nil
    }
    @IBAction func login(_ sender: Any) {
        UsernameTextField.resignFirstResponder()
        PasswordTextField.resignFirstResponder()
        API.login(uID: UsernameTextField.text!, password: PasswordTextField.text!).listen("Resolved", handler: {(_, status: Bool) in
            DispatchQueue.main.async {
                if(status){
                    Core.UpdateDocumentColorScheme().listen("Resolved") { _ in
                        DispatchQueue.main.async {
                            self.dismiss(animated: true)
                        }
                    }.done()
                } else {
                    self.PasswordTextField.text = ""
                }
            }
        }).done()
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        UsernameTextField.resignFirstResponder()
        PasswordTextField.resignFirstResponder()
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
}


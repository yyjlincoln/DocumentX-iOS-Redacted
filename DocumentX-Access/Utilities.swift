//
//  Utilities.swift
//  DocumentX-Access
//
//  Created by Lincoln on 1/9/21.
//
import UIKit
import SwiftUI

class Event {

    struct APIResponse {
        var code: Int
        var message: String
        var data: [String:Any] = [:]
    }
    
    var PrintEvents: Bool
    
    var event = "" // Current Event
    
    typealias VoidEventHandler = (_ event: Event) -> Void
    typealias StringEventHandler = (_ event: Event, _ string: String) -> Void
    typealias ListEventHandler = (_ event: Event, _ list: [Any]) -> Void
    typealias DictionaryEventHandler = (_ event: Event, _ dictionary: [String:Any]) -> Void
    typealias APIResponseEventHandler = (_ event: Event, _ APIResponse: APIResponse) -> Void
    typealias BooleanEventHandler = (_ event: Event, _ bool: Bool) -> Void
    typealias UIViewControllerEventHandler = (_ event: Event, _ uiviewcontroller: UIViewController) -> Void
    
    var VoidEventHandlers: [String: VoidEventHandler] = [:]
    var StringEventHandlers: [String: StringEventHandler] = [:]
    var ListEventHandlers: [String: ListEventHandler] = [:]
    var DictionaryEventHandlers: [String: DictionaryEventHandler] = [:]
    var APIResponseEventHandlers: [String: APIResponseEventHandler] = [:]
    var BooleanEventHandlers: [String: BooleanEventHandler] = [:]
    var UIViewControllerEventHandlers: [String: UIViewControllerEventHandler] = [:]
    
    var VoidEvents: [String: Bool] = [:] // Bool is used as a flag - can only be true
    var StringEvents: [String: String] = [:]
    var ListEvents: [String: [Any]] = [:]
    var DictionaryEvents: [String: [String:Any] ] = [:]
    var APIResponseEvents: [String: APIResponse] = [:]
    var BooleanEvents: [String: Bool] = [:]
    var UIViewControllerEvents: [String: UIViewController] = [:]
    
    var ChainEvents: [Event] = []
    
    
    init(PrintEvents: Bool = false){
        self.PrintEvents = PrintEvents
        self.fire("eventDidInitialise")
    }
    func fire(_ event: String, string data: String) -> Void {
        if(PrintEvents){
            print(event, data)
        }
        if let handler = StringEventHandlers[event] {
            self.event = event
            handler(self, data)
        } else {
            StringEvents[event] = data
        }
        for chain in ChainEvents {
            chain.fire(event, string: data)
        }
    }
    func fire(_ event: String, dictionary data: [String:Any]) -> Void {
        if(PrintEvents){
            print(event, data)
        }
        if let handler = DictionaryEventHandlers[event] {
            self.event = event
            handler(self, data)
        } else {
            DictionaryEvents[event] = data
        }
        for chain in ChainEvents {
            chain.fire(event, dictionary: data)
        }
    }
    func fire(_ event: String, list data: [Any]) -> Void {
        if(PrintEvents){
            print(event, data)
        }
        if let handler = ListEventHandlers[event] {
            self.event = event
            handler(self, data)
        } else {
            ListEvents[event] = data
        }
        for chain in ChainEvents {
            chain.fire(event, list: data)
        }
    }
    func fire(_ event: String, APIResponse data: APIResponse) -> Void {
        if(PrintEvents){
            print(event, data)
        }
        if let handler = APIResponseEventHandlers[event] {
            self.event = event
            handler(self, data)
        } else {
            APIResponseEvents[event] = data
        }
        for chain in ChainEvents {
            chain.fire(event, APIResponse: data)
        }
    }
    func fire(_ event: String) -> Void {
        if(PrintEvents){
            print(event)
        }
        if let handler = VoidEventHandlers[event] {
            self.event = event
            handler(self)
        } else {
            VoidEvents[event] = true // A flag
        }
        for chain in ChainEvents {
            chain.fire(event)
        }
    }
    func fire(_ event: String, bool data: Bool) -> Void {
        if(PrintEvents){
            print(event, data)
        }
        if let handler = BooleanEventHandlers[event] {
            self.event = event
            handler(self, data)
        } else {
            BooleanEvents[event] = data
        }
        for chain in ChainEvents {
            chain.fire(event, bool: data)
        }
    }
    func fire(_ event: String, uiviewcontroller data: UIViewController) -> Void {
        if(PrintEvents){
            print(event, data)
        }
        if let handler = UIViewControllerEventHandlers[event] {
            self.event = event
            handler(self, data)
        } else {
            UIViewControllerEvents[event] = data
        }
        for chain in ChainEvents {
            chain.fire(event, uiviewcontroller: data)
        }
    }
    func listen(_ event: String, handler: @escaping VoidEventHandler) -> Event {
        VoidEventHandlers[event] = handler
        if VoidEvents[event] != nil {
            handler(self)
            VoidEvents[event] = nil
        }
        return self
    }
    func listen(_ event: String, handler: @escaping StringEventHandler) -> Event {
        StringEventHandlers[event] = handler
        if let data = StringEvents[event] {
            handler(self, data)
            StringEvents[event] = nil
        }
        return self
    }
    func listen(_ event: String, handler: @escaping DictionaryEventHandler) -> Event {
        DictionaryEventHandlers[event] = handler
        if let data = DictionaryEvents[event] {
            handler(self, data)
            DictionaryEvents[event] = nil
        }
        return self
    }
    func listen(_ event: String, handler: @escaping ListEventHandler) -> Event {
        ListEventHandlers[event] = handler
        if let data = ListEvents[event] {
            handler(self, data)
            ListEvents[event] = nil
        }
        return self
    }

    func listen(_ event: String, handler: @escaping APIResponseEventHandler) -> Event {
        APIResponseEventHandlers[event] = handler
        if let data = APIResponseEvents[event] {
            handler(self, data)
            APIResponseEvents[event] = nil
        }
        return self
    }
    func listen(_ event: String, handler: @escaping BooleanEventHandler) -> Event {
        BooleanEventHandlers[event] = handler
        if let data = BooleanEvents[event] {
            handler(self, data)
            BooleanEvents[event] = nil
        }
        return self
    }
    func listen(_ event: String, handler: @escaping UIViewControllerEventHandler) -> Event {
        UIViewControllerEventHandlers[event] = handler
        if let data = UIViewControllerEvents[event] {
            handler(self, data)
            UIViewControllerEvents[event] = nil
        }
        return self
    }
    func chain(event: Event) -> Event {
        self.ChainEvents.append(event)
        return self
    }
    func done() -> Void{
        return
    }
}

class Crypto{
//    https://stackoverflow.com/questions/25388747/sha256-in-swift
    func hexString(_ iterator: Array<UInt8>.Iterator) -> String {
        return iterator.map { String(format: "%02x", $0) }.joined()
    }
}

class Utilities {

    func root() -> UIViewController? {
        let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first
        if var topController = keyWindow?.rootViewController {
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            return topController
        }
        return nil
    }
    
    func GetVC(storyboard: String, identifier: String, transition: UIModalTransitionStyle = UIModalTransitionStyle.coverVertical, presentation: UIModalPresentationStyle = UIModalPresentationStyle.fullScreen) -> Event {
        let event = Event()
        DispatchQueue.main.async {
            let board = UIStoryboard(name: storyboard, bundle: nil)
            let vc = board.instantiateViewController(withIdentifier: identifier)
            vc.modalPresentationStyle = presentation
            vc.modalTransitionStyle = transition
            event.fire("Resolved", uiviewcontroller: vc)
        }
        return event
    }
    
    func GetVC(view: AnyView, transition: UIModalTransitionStyle = UIModalTransitionStyle.coverVertical, presentation: UIModalPresentationStyle = UIModalPresentationStyle.fullScreen) -> Event {
        // Returns an event for consistency
        let event = Event()
        DispatchQueue.main.async {
            let vc = UIHostingController(rootView: view)
            vc.modalPresentationStyle = presentation
            vc.modalTransitionStyle = transition
            event.fire("Resolved", uiviewcontroller: vc)
        }
        return event
    }
    
    
    func Present(_ vc: UIViewController) -> Event{
        let event = Event()
        DispatchQueue.main.async {
            self.root()?.present(vc, animated: true, completion: {
                event.fire("Presented")
            })
        }
        return event
    }
    func Show(_ vc: UIViewController){
        DispatchQueue.main.async {
            self.root()?.show(vc, sender: self.root())
        }
    }
    
    
    func PresentVC(storyboard: String, identifier: String, animated: Bool = true, transition: UIModalTransitionStyle = UIModalTransitionStyle.coverVertical, presentation: UIModalPresentationStyle = UIModalPresentationStyle.fullScreen) -> Event {
        // Events
        // (Void) Presented
        let event = Event()
        self.GetVC(storyboard: storyboard, identifier: identifier, transition: transition, presentation: presentation).listen("Resolved", handler: { (_, vc: UIViewController) in
            DispatchQueue.main.async {
                self.root()?.present(vc, animated: animated, completion: {
                    event.fire("Presented")
                })
            }
        }).done()
        return event
    }
    
    func PresentVC(view: AnyView, animated: Bool = true, transition: UIModalTransitionStyle = UIModalTransitionStyle.coverVertical, presentation: UIModalPresentationStyle = UIModalPresentationStyle.fullScreen) -> Event {
        
        let event = Event()
        self.GetVC(view: view, transition: transition, presentation: presentation).listen("Resolved", handler: { (_, vc: UIViewController) in
            DispatchQueue.main.async {
                self.root()?.present(vc, animated: animated, completion: {
                    event.fire("Presented")
                })
            }
        }).done()
        return event
    }
    
    func ShowVC(storyboard: String, identifier: String, animated: Bool = true, transition: UIModalTransitionStyle = UIModalTransitionStyle.coverVertical, presentation: UIModalPresentationStyle = UIModalPresentationStyle.fullScreen) {

        self.GetVC(storyboard: storyboard, identifier: identifier, transition: transition, presentation: presentation).listen("Resolved", handler: { (_, vc: UIViewController) in
            DispatchQueue.main.async {
                self.root()?.show(vc, sender: self.root())
            }
        }).done()
    }
    
    func ShowVC(view: AnyView, animated: Bool = true, transition: UIModalTransitionStyle = UIModalTransitionStyle.coverVertical, presentation: UIModalPresentationStyle = UIModalPresentationStyle.fullScreen) {
        self.GetVC(view: view, transition: transition, presentation: presentation).listen("Resolved", handler: { (_, vc: UIViewController) in
            DispatchQueue.main.async {
                self.root()?.show(vc, sender: self.root())
            }
        }).done()
        
    }
   
    
    init() {
    }
    
    func alert(title: String, message: String) -> Event {
        // Events:
        // (Void) Presented
        // (Void) Resolved
        
        let event = Event()
        DispatchQueue.main.async {
            let vc = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
            vc.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: { _ in
                event.fire("Resolved")
            }))
            self.root()?.present(vc, animated: true, completion: {
                event.fire("Presented")
            })
            event.listen("Dismiss", handler: { _ in
                DispatchQueue.main.async {
                    vc.dismiss(animated: true, completion: {
                        event.fire("Dismissed")
                        event.fire("Resolved")
                    })

                }
            }).done()


        }
        return event
    }
    
    func alertWithCancel(title: String, message: String) -> Event {
        // Resolved
        // Presented
        // Dismissed
        let event = Event()
        DispatchQueue.main.async {
            let vc = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
            vc.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: {_ in
                event.fire("Cancelled")
//                event.fire("Resolved")
            }))
            self.root()?.present(vc, animated: true, completion: {
                event.fire("Presented")
            })
            event.listen("Dismiss", handler: { _ in
                DispatchQueue.main.async {
                    vc.dismiss(animated: true, completion: {
                        event.fire("Dismissed")
                        event.fire("Resolved")
                    })

                }
            }).done()
        }
        

        
        return event
    }
    
    func option(title: String, message: String) -> Event {
        // Events:
        // (Void) Presented
        // (Void) Resolved
        
        let event = Event()
        DispatchQueue.main.async {
            let vc = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
            vc.addAction(UIAlertAction(title: "Continue", style: UIAlertAction.Style.default, handler: { _ in
                event.fire("Continued")
                event.fire("Resolved")
            }))
            vc.addAction(UIAlertAction(title: "Cancel", style: UIAlertAction.Style.cancel, handler: { _ in
                event.fire("Cancelled")
                event.fire("Resolved")
            }))
            self.root()?.present(vc, animated: true, completion: {
                event.fire("Presented")
            })
            event.listen("Dismiss", handler: { _ in
                DispatchQueue.main.async {
                    vc.dismiss(animated: true, completion: {
                        event.fire("Dismissed")
                        event.fire("Resolved")
                    })
                }
            }).done()

        }
        return event
    }
    
    func SecondsToHumanReadable(time: Int) -> String{
        var final = ""
        
        var xtime = time
        if xtime < 0 {
            xtime = -xtime
            final = "+"
        }
        let hours = xtime/3600
        xtime = xtime - hours * 3600
        let minutes = xtime/60
        xtime = xtime - minutes * 60
        let seconds = xtime
        
        var shours = String(hours)
        var sminutes = String(minutes)
        var sseconds = String(seconds)
        if hours < 10 {
            shours = "0" + shours
        }
        if minutes < 10 {
            sminutes = "0" + sminutes
        }
        if seconds < 10 {
            sseconds = "0" + sseconds
        }
        final += "\(shours):\(sminutes):\(sseconds)"
        return final
        
    }
    
    
}

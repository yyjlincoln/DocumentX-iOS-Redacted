//
//  Instructions.swift
//  DocumentX-Access
//
//  Created by Lincoln on 9/11/21.
//


import Foundation

typealias GENERIC =  (_ :Any...) -> Any
typealias EXECUTOR =  (_ :Dictionary<String, Any>) -> Event

let Instructions = Loader()


var SCRIPT_RUNTIME_VAIRABLE: [String:Any] = [:]

func AlertExecutor(_ args: [String:Any]) -> Event {
    let title = args["title"] as? String ?? ""
    let message = args["message"] as? String ?? ""
    return Utils.alert(title: title, message: message)
}

func OptionExecutor(_ args: [String:Any]) -> Event {
    let title = args["title"] as? String ?? ""
    let message = args["message"] as? String ?? ""
    return Utils.option(title: title, message: message)
}

func PresentExecutor(_ args: [String: Any]) -> Event {
    let storyboard = args["storyboard"] as? String ?? "App"
    let identifier = args["identifier"] as? String ?? "App.Main"
    return Utils.PresentVC(storyboard: storyboard, identifier: identifier)
}

func SetMetadataValue(_ args: [String: Any]) -> Event {
    let key = args["key"]
    let value = args["value"]
    let e = Event()
    if let key = key as? String, let value = value {
        Core.UpdateAppLocalMetadata(key, value)
    } else if let value = value {
        Core.UpdateAppLocalMetadata(value)
    }
    e.fire("Resolved")
    return e
}

func ReadMetadataValue(_ args: [String: Any]) -> Event {
    let e = Event()
    let key = args["key"]
    let tovar = args["to"]
    if let key = key as? String, let tovar = tovar as? String {
        SCRIPT_RUNTIME_VAIRABLE[tovar] = Core.GetAppLocalMetadata(key)
    } else if let tovar = tovar as? String {
        SCRIPT_RUNTIME_VAIRABLE[tovar] = Core.GetAppLocalMetadata()
    }
    e.fire("Resolved")
    return e
}

func SetVairable(_ args: [String: Any]) -> Event {
    let e = Event()
    for (key, val) in args {
        SCRIPT_RUNTIME_VAIRABLE[key] = val
    }
    e.fire("Resolved")
    return e
}

func ExecuteInternal(_ args: [String: Any]) -> Event {
    return Instructions.ExecuteScript(args["script"] as? String ?? "")
}

func AppTerminate(_ args: [String: Any]) -> Event {
    DispatchQueue.main.async {
        exit(0)
    }
    exit(0)
}

func OpenAppURL(_ args: [String: Any]) -> Event {
    let e = Event()
    let url = args["url"] as? String ?? "documentx://"
    Core.ProcessURL(url).listen("Resolved", handler: { _ in
        e.fire("Resolved")
    }).done()
    return e
}

func ExecClock(_ args: [String: Any]) -> Event {
    let e = Event()
    let seconds = (args["seconds"] as? NSNumber)?.doubleValue ?? 3.0
    print(seconds)
    let ifRepeat = (args["repeat"]) as? Bool ?? false
    DispatchQueue.main.async {
        if ifRepeat {
            Timer.scheduledTimer(withTimeInterval: seconds, repeats: ifRepeat, block: { _ in
                e.fire("Loop")
            })
            e.fire("Resolved")
        } else {
            Timer.scheduledTimer(withTimeInterval: seconds, repeats: ifRepeat, block: { _ in
                e.fire("Resolved")
            })
        }

    }
    return e
}

func FORLoop(_ args: [String: Any]) -> Event {
    let e = Event()
    let max = (args["max"] as? NSNumber)?.intValue ?? 1
    let variable = args["var"] as? String
    DispatchQueue.main.async {
        for index in 0...max {
            if let variable = variable {
                SCRIPT_RUNTIME_VAIRABLE[variable] = index
            }
            e.fire("Loop")
        }
    }
    e.fire("Resolved")
    return e
}

let Executors: [String: EXECUTOR] = [
    "alert": AlertExecutor,
    "option": OptionExecutor,
    "present": PresentExecutor,
    "var": SetVairable,
    "exec": ExecuteInternal,
    "metawrite": SetMetadataValue,
    "metaread": ReadMetadataValue,
    "terminate": AppTerminate,
    "url": OpenAppURL,
    "clock": ExecClock,
    "for": FORLoop
]

class Loader {
    init(){
        
    }
    func ParseListenersAndAttach(_ _string: String, _ listener: Event) {
        
        let string = _string.trimmingCharacters(in: .whitespacesAndNewlines)

//        This will execute the instructions immediately
        var status = "event-name"
        var accumulator = ""
        var eventName = ""
        
        var stack:[String] = []
        
        for _char in string {
            let char = String(_char)
            if status == "event-name" {
                if char == "{" {
                    eventName = accumulator.trimmingCharacters(in: .whitespacesAndNewlines)
                    accumulator = ""
                    status = "event-prospective-code"
                    stack.append("{")
                    continue
                } else {
                    accumulator = accumulator + char
                }
            } else if status == "event-prospective-code" {
                if char == "{" {
                    stack.append("{")
                }
                if char == "}" {
                    stack.removeLast()
                    if stack.isEmpty {
                        listener.listen(eventName, handler: self.GenerateScriptExecutor(accumulator.trimmingCharacters(in: .whitespacesAndNewlines))).done()
                        accumulator = ""
                        status = "event-name"
                    } else {
                        accumulator = accumulator + "}"
                    }
                } else {
                    accumulator = accumulator + char
                }
            } else {
                print("Unexpected.")
            }
        }
        if status == "event-prospective-code" {
            print("Unexpected: Unmatched }")
            print(string)
        }
    }
    
    func GetExecutor(_ _executorName: String) -> EXECUTOR {
        let executorName = _executorName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let executor = Executors[executorName] {
            return executor
        } else {
            func InternalErrorExecutor(_ args: [String: Any]) -> Event {
                let e = Event()
                e.fire("Error", string: "We could not find executor for command \"\(executorName)\"")
                return e
            }
            return InternalErrorExecutor
        }
        
    }
    
    func ExecuteSingleCommand(_ executorName: String, _ _data: String) -> Event {
        // Try to replace the data with vairables
        var data = _data
        if data == "" {
            data = "{}"
        }
        for (key, val) in SCRIPT_RUNTIME_VAIRABLE {
            data = data.replacingOccurrences(of: "$(\(key))", with: "\(String(describing: val))")
        }
        var dataDict = try? JSONSerialization.jsonObject(with: data.data(using: String.Encoding.utf8)!, options: [])
        if dataDict == nil {
            dataDict = try? JSONSerialization.jsonObject(with: _data.data(using: String.Encoding.utf8)!, options: [])
        }
        if let dataDict = dataDict as? [String: Any] {
            return self.GetExecutor(executorName)(dataDict)
        }
        let e = Event()
        e.fire("Error")
        e.fire("Error", string: "Could not execute command \(executorName) with data \(data)")
        return e
    }
    
//    ExecuteScript() -- Executes at high-level
    func ExecuteScript(_ script: String) -> Event {
        let e = Event()
        var status = "read-instruction"
        var accumulator = ""
        
        var executorName: String = ""
        var executor: Event?
        var data = ""
        
        var wasAsync = false
        
        var stack: [String] = []
        
        var escape = false
        
        if script.trimmingCharacters(in: .whitespacesAndNewlines) == "" {
            e.fire("Resolved")
            return e
        }
//        TODO: Implement Stack (Just like above) but for multiple characters
        for _char in script {
            let char = String(_char)
            
            if accumulator == "" && char == " " {
                continue
            }
            
            if escape == true {
                accumulator = accumulator + char
                escape = false
                continue
            }
            if char == "\\" && escape == false {
                escape = true
                continue
            }
            
            switch status {
            case "read-instruction":
                if char != "(" {
                    accumulator = accumulator + char
                } else {
                    stack.append("(")
                    status = "read-data"
                    executorName = accumulator
                    accumulator = ""
                    continue
                }
            case "read-data":
                if char != ")" {
                    accumulator = accumulator + char
                    if char == "(" {
                        stack.append("(")
                    }
                } else {
                    if stack.removeLast() != "(" {
                        print("Warn: Unmatched )")
                    }
                    if stack.isEmpty {
                        status = "after-data"
                        data = accumulator
                        accumulator = ""
                        var executorNameComponents = executorName.components(separatedBy: " ")
                        let nameOnly = executorNameComponents.popLast() ?? "error"
                        for property in executorNameComponents {
                            if property == "async" {
                                wasAsync = true
                            }
//                            TODO: Future - Support more properties
                        }
                        executor = self.ExecuteSingleCommand(nameOnly, data.trimmingCharacters(in: .whitespacesAndNewlines))
                        continue
                    } else {
//                        It's not the matching )
                        accumulator = accumulator + ")"
                        continue
                    }
                }
            case "after-data":
                if char == "{" {
                    accumulator = ""
                    status = "read-listeners"
                    stack.append("{")
                } else {
                    accumulator = ""
                    status = "prospective-resolve"
                }
                continue
            case "read-listeners":
                if char == "}" {
                    if stack.removeLast() != "{" {
                        print("Warn: Unmatched }")
                    }
                    if stack.isEmpty {
                        status = "prospective-resolve"
                        if let executor = executor {
                            self.ParseListenersAndAttach(accumulator, executor)
                        } else {
                            print("Error: No executor")
                            e.fire("Error", string: "There's no executor available. This is possibly because you did not call the function properly.")
                            e.fire("Resolved")
                            return e
                        }
                        accumulator = ""
                        continue
                    } else {
                        accumulator = accumulator + "}"
                    }
                
                } else {
                    accumulator = accumulator + char
                    if char == "{" {
                        stack.append("{")
                    }
                }
            case "prospective-resolve":
                accumulator = accumulator + char
            default:
                print("Error: Unexpected status.")
                e.fire("Error", string: "Unexpected status \(status)")
                e.fire("Resolved")
                return e
            }
        }
        if status == "prospective-resolve"{
            accumulator = accumulator.trimmingCharacters(in: .whitespacesAndNewlines)
            if accumulator != "" {
                if wasAsync {
                    self.ExecuteScript(accumulator).done()
                } else {
                    executor?.listen("Resolved", handler: self.GenerateScriptExecutor(accumulator)).done()
                }
            }
        }
        e.fire("Executed")
        e.fire("Resolved")
        return e
    }
    
    func GenerateScriptExecutor(_ _prospectiveCode: String) -> Event.VoidEventHandler {
        let prospectiveCode = _prospectiveCode.trimmingCharacters(in: .whitespacesAndNewlines)
        func ScriptExecutor(parentEvent: Event) { // This is a callback function that conforms to the EventCallbackFunction (Void)
            self.ExecuteScript(prospectiveCode).done()
        }
        return ScriptExecutor
    }
}


// TODO: Implement this in the future.
//func IFStatement(_ args: [String: Any]) -> Event {
//    let e = Event()
////    ["x": Any, "y": Any, "type":"Bool", "relation": "=", "true":"<Statement>", "false":"<Statement>"]
//    let x = args["x"]
//    let y = args["y"]
//    let type = args["type"]
//    let relation = args["relation"] as? String ?? "="
//    let whenTrue = args["true"]
//    let whenFalse = args["false"]
//
//    if let type = type as? String {
//        switch type.lowercased() {
//        case "bool":
//        }
//    }
//    return e
//}
//
//func IFEquate<T: (Comparable, Equatable)>(_ x: T,_ y: T,_ relation: String, _ whenTrue: String, _ whenFalse: String) {
//    switch relation {
//    case "=":
//        if x == y {
//
//        }
//    }
//}


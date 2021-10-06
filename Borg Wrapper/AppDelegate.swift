//
//  AppDelegate.swift
//  Borg Wrapper
//
//  Created by Sun Knudsen on 2020-11-09.
//

import Cocoa
import SwiftUI
import UserNotifications

struct Config : Codable {
  let label: String
  let script: String
  let logFile: String
  let initiatedNotifications: Bool
  let completedNotifications: Bool
  let failedNotifications: Bool
}

func loadConfig(_ fileName: String) -> Config? {
  let url = URL(fileURLWithPath: fileName)
  let decoder = JSONDecoder()
  guard
    let data = try? Data(contentsOf: url),
    let config = try? decoder.decode(Config.self, from: data)
  else {
    return nil
  }
  return config
}

func showAlert(_ messageText: String){
  DispatchQueue.main.async {
    let alert = NSAlert.init()
    alert.messageText = messageText
    alert.runModal()
  }
}

func showNotification(_ body: String, _ config: Config){
  let content = UNMutableNotificationContent()
  content.body = body
  content.userInfo = ["logFile": config.logFile]
  let request = UNNotificationRequest(
    identifier: UUID().uuidString,
    content: content,
    trigger: nil
  )
  UNUserNotificationCenter.current().add(request) { (error:Error?) in
    if error != nil {
      print(error?.localizedDescription ?? "Could not add notification")
    }
  }
}

func shell(_ command: String, completion: ((_ status: Int32, _ output: String?) -> Void)? = nil) {
  let task = Process()
  let pipe = Pipe()
  
  task.launchPath = "/bin/zsh"
  task.arguments = ["-c", command]
  task.standardOutput = pipe
  task.waitUntilExit()
  task.launch()
  
  let data = pipe.fileHandleForReading.readDataToEndOfFile()
  let output = String(data: data, encoding: .utf8)
  
  completion?(task.terminationStatus, output)
}

func terminate() -> Void {
  DispatchQueue.main.async {
    NSApplication.shared.terminate(nil)
  }
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
  var config = Config(
    label: "default",
    script: "/usr/local/bin/borg-backup.sh",
    logFile: "/usr/local/var/log/borg-backup.log",
    initiatedNotifications: true,
    completedNotifications: true,
    failedNotifications: true
  )
  
  func run() -> Void {
    if self.config.initiatedNotifications {
      showNotification("Backup “\(self.config.label)” initiated...", self.config)
    }

    // Run script and log output
    let command = "set -o pipefail; PATH=$PATH:/opt/homebrew/bin:/usr/local/bin \(self.config.script) 2>&1 | tee -a \(self.config.logFile)"

    shell(command) {(status: Int32, output: String?) in
      if status == 0 {
        if self.config.completedNotifications {
          showNotification("Backup “\(self.config.label)” completed", self.config)
        }
        // Truncate log file to last 1000 lines
        shell("echo \"$(tail -n 1000 \(self.config.logFile))\" > \(self.config.logFile)") {(status: Int32, output: String?) in
          terminate()
        }
      } else {
        if self.config.failedNotifications {
          showNotification("Backup “\(self.config.label)” failed", self.config)
        }
        terminate()
      }
    }
  }
  
  var notificationCenterLaunch = false
  func applicationDidFinishLaunching(_ notification: Notification) {
    UNUserNotificationCenter.current().delegate = self
    UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (allowed, error) in
      // Check if notifications are allowed
      if !allowed {
        showAlert("Please allow notifications in System Preferences / Notifications")
        terminate()
      // Check if app was launched by clicking on notification
      } else if notification.userInfo?[NSApplication.launchUserNotificationUserInfoKey] != nil {
        self.notificationCenterLaunch = true
      } else {
        // Read app arguments and set config if valid configuration file was provided
        if
          CommandLine.arguments.indices.contains(1) &&
          CommandLine.arguments[1].range(of: ".json$", options: .regularExpression, range: nil, locale: nil) != nil
        {
          print(CommandLine.arguments)
          if let _config = loadConfig(CommandLine.arguments[1]) {
            self.config = _config
            self.run()
          } else {
            showAlert("Invalid config file")
            terminate()
          }
        } else {
          self.run()
        }
      }
    }
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    if let logFile = response.notification.request.content.userInfo["logFile"] as? String {
      shell("open \(logFile)")
    }
    if self.notificationCenterLaunch {
      terminate()
    }
  }
}

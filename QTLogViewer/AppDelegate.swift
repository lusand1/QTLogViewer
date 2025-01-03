//
//  AppDelegate.swift
//  QTLogViewer
//
//  Created by dog on 2024/12/6.
//

import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
    /// 当用户将文件拖放到 Dock 图标时调用此方法
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        for filename in filenames {
//            print("Received file path: \(filename)")
            
            // 直接创建 URL，因为 URL(fileURLWithPath:) 总是返回非可选类型
            let url = URL(fileURLWithPath: filename)
//            print("Converted to URL: \(url)")
            
            // 如果你需要检查文件是否存在或是否可以访问，可以这样做：
            if FileManager.default.fileExists(atPath: url.path) {
                readLogFile(url: url)
            } else {
//                print("File does not exist at path: \(url.path)")
            }
        }
    }

    /// 可选：当应用程序即将完成启动时调用
    func applicationWillFinishLaunching(_ notification: Notification) {
        // 任何启动前需要做的准备工作
    }

    func readLogFile(url: URL) {
//        print("Reading log file at \(url)")
        // 你的读取日志文件的方法
        NotificationCenter.default.post(name: Notification.Name("FileDropped"), object: url)
    }


    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

}


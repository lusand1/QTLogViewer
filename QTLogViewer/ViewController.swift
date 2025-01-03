//
//  ViewController.swift
//  QTLogViewer
//
//  Created by dog on 2024/12/6.
//

import Cocoa

class ViewController: NSViewController, NSOutlineViewDataSource, NSOutlineViewDelegate, NSTextViewDelegate {
    @IBOutlet weak var outlineView: NSOutlineView!
    @IBOutlet var textView: NSTextView!
    @IBOutlet weak var pathLabel: NSTextField!
    @IBAction func checkboxStateChanged(_ sender: NSButton) {
        isShowOnlyFailures = sender.state == .on
        reloadOutlineView()
    }
    
    private var testNames: [(name: String, result: String, range: NSRange)] = []
    var isReloadingFile = false // 新增的状态变量
    var isShowOnlyFailures = false // 新增的布尔变量
    var filteredTestNames: [(name: String, result: String, range: NSRange)] {
        return isShowOnlyFailures ? testNames.filter { $0.result == "Fail" } : testNames
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        loadLogFile()
        NotificationCenter.default.addObserver(self, selector: #selector(readLogFile(_:)), name: Notification.Name("FileDropped"), object: nil)
        outlineView.dataSource = self
        outlineView.delegate = self
        textView.delegate = self
    }
    
//    func loadLogFile() {
//        // 创建文件打开面板
//        let panel = NSOpenPanel()
//        panel.allowedFileTypes = ["txt", "log"]
//        panel.begin { response in
//            if response == .OK, let url = panel.url {
//                self.readLogFile(url: url)
//            }
//        }
//    }
    
    @objc func readLogFile(_ notification: Notification) {
        if let url = notification.object as? URL {
            self.readLogFile(url: url)
        }
    }
    
    func readLogFile(url: URL) {
        let fileManager = FileManager.default
        do {
            pathLabel.stringValue = url.path
            textView.textColor = .gray
            textView.isSelectable = false
            // 设置状态变量并重载outlineView
            isReloadingFile = true
            reloadOutlineView()
            
            // 获取文件大小
            let fileSize = try fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64 ?? 0
            if fileSize > 10 * 1024 * 1024 { // 如果文件大于10MB，采用分块读取
                processFileInChunks(url: url)
            } else {
                // 对于小文件，直接读取并处理
                DispatchQueue.global(qos: .background).async {
                    do {
                        var logContent = try String(contentsOf: url, encoding: .utf8)
                        
                        // 移除每行中以特定日期格式开头的部分
                        logContent = self.removeUnwantedPatterns(from: logContent)
                        
                        let attributedString = self.setColorForPatterns(in: logContent)
                        self.extractTestNames(from: logContent)
                        DispatchQueue.main.async {
                            self.textView.textStorage?.setAttributedString(attributedString)
                            self.isReloadingFile = false
                            self.reloadOutlineView()
                        }
                    } catch {
                        print("读取文件内容出错: \(error)")
                        // 恢复状态变量（即使有错误）
                        DispatchQueue.main.async {
                            self.isReloadingFile = false
                            self.reloadOutlineView()
                        }
                    }
                }
            }
        } catch {
            print("获取文件属性失败: \(error)")
            // 恢复状态变量（即使有错误）
            DispatchQueue.main.async {
                self.isReloadingFile = false
                self.reloadOutlineView()
            }
        }
    }
    
    func removeUnwantedPatterns(from text: String) -> String {
        // 定义一个正则表达式来匹配以特定日期格式开头的部分
        let datePattern = "^\\d{4}/\\d{2}/\\d{2}\\s+"
        // 定义一个正则表达式来匹配特定的进程信息
        let processPattern = "\\s*AtlasGroupProcess\\s*\\(pid:\\s*\\d+,"

        do {
            // 对于日期，直接创建正则表达式并替换为空
            let dateRegex = try NSRegularExpression(pattern: datePattern, options: .anchorsMatchLines)
            var modifiedText = dateRegex.stringByReplacingMatches(
                in: text,
                options: [],
                range: NSRange(location: 0, length: text.utf16.count),
                withTemplate: ""
            )
            
            // 对于进程信息，创建另一个正则表达式并替换为一个空格
            let processRegex = try NSRegularExpression(pattern: processPattern, options: [])
            modifiedText = processRegex.stringByReplacingMatches(
                in: modifiedText,
                options: [],
                range: NSRange(location: 0, length: modifiedText.utf16.count),
                withTemplate: " "
            )
            
            return modifiedText
        } catch {
            print("正则表达式错误: \(error)")
            return text
        }
    }
    
    func processFileInChunks(url: URL) {
        let bufferSize = 1024 * 1024 // 1MB 缓冲区
        var offset = 0
        let totalAttributedString = NSMutableAttributedString()
        
        while true {
            let (chunk, bytesRead) = readFileChunk(url: url, offset: offset, length: bufferSize)
            if bytesRead == 0 {
                break // 文件结束
            }
            let attributedChunk = setColorForPatterns(in: chunk)
            totalAttributedString.append(attributedChunk)
            offset += bytesRead
        }

        DispatchQueue.main.async {
            self.textView.textStorage?.setAttributedString(totalAttributedString)
            self.reloadOutlineView()
        }
    }
    
    func readFileChunk(url: URL, offset: Int, length: Int) -> (String, Int) {
        guard let fileHandle = FileHandle(forReadingAtPath: url.path) else {
            print("无法打开文件句柄")
            return("", 0)
        }
        
        defer { fileHandle.closeFile() }
        
        fileHandle.seek(toFileOffset: UInt64(offset))
        let data = fileHandle.readData(ofLength: length)
        if let chunk = String(data: data, encoding: .utf8) {
            return (chunk, data.count)
        } else {
            print("数据编码错误，可能包含非UTF-8内容")
            return ("", data.count)
        }
    }
    
    // MARK: - 设置颜色并提取 TestName
    func setColorForPatterns(in text: String) -> NSAttributedString {
        let attributedString = NSMutableAttributedString(string: text)
        
        // Define colors
        let orangeColor = NSColor.systemOrange
        var blueColor = NSColor.systemBlue
        if #available(macOS 12.0, *) {
            blueColor = NSColor.systemCyan
        } else {
            blueColor = NSColor.systemBlue
        }
        let greenColor = NSColor.systemGreen
        let brownColor = NSColor.systemBrown
        let redColor = NSColor.systemRed
        
        // Define patterns and their corresponding colors
        let patternsAndColors: [(String, NSColor)] = [
            ("\\[Test Start\\].*", orangeColor),
            ("\\[Action Start\\].*", blueColor),
            ("\\[Action Pass\\].*", greenColor),
            ("\\[Action Fail\\].*", redColor),
            ("\\[Test End\\].*", brownColor)
        ]
        
        do {
            for (pattern, color) in patternsAndColors {
                let regex = try NSRegularExpression(pattern: pattern, options: [])
                let range = NSRange(location: 0, length: text.count)
                regex.enumerateMatches(in: text, options: [], range: range) { match, flags, stop in
                    if let matchRange = match?.range {
                        attributedString.addAttribute(.foregroundColor, value: color, range: matchRange)
                        // 特别处理 "Action Fail" 的字体大小
                        if pattern == "\\[Action Fail\\].*" {
                            let font = NSFont.systemFont(ofSize: 13.0)
                            attributedString.addAttribute(.font, value: font, range: matchRange)
                        }
                    }
                }
            }
        } catch {
            print("正则表达式错误: \(error)")
        }
        return attributedString
    }

    func extractTestNames(from text: String) {
        testNames.removeAll()
        let testNamePattern = "\\[Test Start\\]\\[.*?\\]\\[.*?\\]\\[(.*?)\\]"
        let testResultPattern = "\\[Action (Pass|Fail)\\]\\[.*?\\]\\[.*?\\]\\[(.*?)\\]"
        
        do {
            let testNameRegex = try NSRegularExpression(pattern: testNamePattern, options: [])
            let testResultRegex = try NSRegularExpression(pattern: testResultPattern, options: [])
            let range = NSRange(location: 0, length: text.utf16.count)
            testNameRegex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                if let matchRange = match?.range(at: 1), let rangeInText = match?.range {
                    let testName = (text as NSString).substring(with: matchRange)
                        .replacingOccurrences(of: "<", with: "")
                        .replacingOccurrences(of: ">", with: "")
                    let resultMatch = testResultRegex.firstMatch(in: text, options: [], range: NSRange(location: rangeInText.location, length: text.utf16.count - rangeInText.location))
                    let result = (resultMatch != nil) ? (text as NSString).substring(with: resultMatch!.range(at: 1)) : "Unknown"
//                    print("提取到TestName：\(testName)，结果：\(result)")
                    self.testNames.append((name: testName, result: result, range: rangeInText))
                }
            }
            DispatchQueue.main.async {
                self.textView.isSelectable = true
            }
        } catch {
            print("提取 TestName 出错: \(error)")
        }
    }

    func reloadOutlineView() {
        DispatchQueue.main.async {
            self.outlineView.reloadData()
        }
    }
    
    // MARK: - NSOutlineViewDataSource
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
//        let count = testNames.count
//        print("导航栏包含\(count)个项目")
        return filteredTestNames.count
    }
 
    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        return false
    }
 
    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        var testInfo = filteredTestNames[index]
        let numberedTestName = "\(index + 1) \(testInfo.name)"
        testInfo.name = numberedTestName
//        print("导航栏项目：\(numberedTestName)")
        return testInfo // 返回完整的测试信息元组
    }
 
    // MARK: - NSOutlineViewDelegate
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let testInfo = item as? (name: String, result: String, range: NSRange) else { return nil }
                
        let cell = outlineView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "DataCell"), owner: self) as? NSTableCellView
        cell?.textField?.stringValue = testInfo.name
        if cell?.layer == nil {
            cell?.wantsLayer = true
            // 添加边框
            cell?.layer?.borderWidth = 1.0
            cell?.layer?.borderColor = NSColor.white.cgColor
            cell?.layer?.cornerRadius = 4.0  // 可选：添加圆角
        }
        
        // 设置背景颜色
        if isReloadingFile {
            cell?.layer?.backgroundColor = NSColor.gray.cgColor
        } else {
            switch testInfo.result {
                case "Pass":
                    cell?.layer?.backgroundColor = NSColor.systemGreen.cgColor
                case "Fail":
                    cell?.layer?.backgroundColor = NSColor.systemRed.cgColor
                default:
                    cell?.layer?.backgroundColor = NSColor.blue.cgColor
            }
        }

        return cell
    }
 
    func outlineViewSelectionDidChange(_ notification: Notification) {
        guard let outlineView = notification.object as? NSOutlineView else { return }
        let selectedRow = outlineView.selectedRow
        guard selectedRow >= 0 && selectedRow < filteredTestNames.count else { return }
        
        // 根据过滤后的数据找到原始 testNames 中的索引
        if let originalIndex = testNames.firstIndex(where: { $0.range == filteredTestNames[selectedRow].range }) {
            // 获取选中的测试项以及其范围
            let selectedTest = testNames[originalIndex]
            let selectedRange = selectedTest.range
            
            // 定位到对应的文本位置
            textView.scrollRangeToVisible(selectedRange)
            textView.showFindIndicator(for: selectedRange)
        }
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }


}


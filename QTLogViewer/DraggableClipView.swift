//
//  DraggableClipView.swift
//  QTLogViewer
//
//  Created by dog on 2024/12/6.
//

import Cocoa

class DraggableClipView: NSClipView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        // 注册拖放类型
        registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL])
    }

    // MARK: - NSDraggingDestination methods
    
    public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
//        print("DraggableClipView - performDragOperation called")
        if let board = sender.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
           let fileUrl = board.first {
            // 调用 ViewController 的方法或者直接处理逻辑
            NotificationCenter.default.post(name: Notification.Name("FileDropped"), object: fileUrl)
            return true
        }
        return false
    }

    public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
//        print("DraggableClipView - draggingEntered called")
        return .copy
    }

    public override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
//        print("DraggableClipView - prepareForDragOperation called")
        return true
    }

    public override func concludeDragOperation(_ sender: NSDraggingInfo?) {
//        print("DraggableClipView - concludeDragOperation called")
    }

    public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
//        print("DraggableClipView - draggingUpdated called")
        return .copy
    }

    public override func draggingExited(_ sender: NSDraggingInfo?) {
//        print("DraggableClipView - draggingExited called")
    }
}


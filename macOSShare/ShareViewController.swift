//
//  ShareViewController.swift
//  macOSShare
//
//  Created by Caturday Reed on 2026/6/17.
//

import Cocoa
import Common
import SwiftData
import SwiftUI

class ShareViewController: NSViewController {
    override var nibName: NSNib.Name? {
        return NSNib.Name("ShareViewController")
    }

    override func loadView() {
        super.loadView()

        let attachments = extensionContext?.inputItems.flatMap { ($0 as! NSExtensionItem).attachments ?? [] } ?? []
        let hostingController = NSHostingController(rootView:
            ShareSheetView(attachments.filter { $0.canLoadObject(ofClass: URL.self) })
                .environment(\.dismissSharesheet, dismiss)
                .modelContainer(appModelContainer)
        )

        hostingController.view.frame = view.bounds
        view.addSubview(hostingController.view)
        addChild(hostingController)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        hostingController.view.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        hostingController.view.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
    }

    func dismiss() {
        extensionContext!.completeRequest(returningItems: nil)
    }
}

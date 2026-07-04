//
//  ShareViewController.swift
//  iOSShare
//
//  Created by Caturday Reed on 2026/6/17.
//

import Common
import SwiftUI
import UIKit
import SwiftData

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let attachments = extensionContext?.inputItems.flatMap { ($0 as! NSExtensionItem).attachments ?? [] } ?? []
        let hostingController = UIHostingController(
            rootView: ShareSheetView(attachments)
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

    func dismiss(_ dismissal: SharesheetDismissal) {
        switch dismissal {
        case .ok:
            extensionContext!.completeRequest(returningItems: nil)
        case .canceled(let error):
            extensionContext!.cancelRequest(withError: error)
        }
    }
}

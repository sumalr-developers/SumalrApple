//
//  ShareViewController.swift
//  iOSShare
//
//  Created by Caturday Reed on 2026/6/17.
//

import Common
import RealmSwift
import SwiftUI
import UIKit

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let attachments = extensionContext?.inputItems.flatMap { ($0 as! NSExtensionItem).attachments ?? [] } ?? []
        let hostingController = UIHostingController(rootView: ShareSheetView(attachments).environment(\.dismissSharesheet, dismiss))

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
        extensionContext?.completeRequest(returningItems: nil)
    }
}

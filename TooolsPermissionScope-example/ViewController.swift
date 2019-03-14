//
//  ViewController.swift
//  PermissionScope-example
//
//  Created by Nick O'Neill on 4/5/15.
//  Copyright (c) 2015 That Thing in Swift. All rights reserved.
//

import UIKit
import TooolsPermissionScope

class ViewController: UIViewController {

    let singlePscope = TooolsPermissionScope()
    let multiPscope = TooolsPermissionScope()
    let noUIPscope = TooolsPermissionScope()

    override func viewDidLoad() {

        super.viewDidLoad()

        singlePscope.addPermission(permission: NotificationsPermission(), message: "We use this to send you\r\nspam and love notes")

        multiPscope.addPermission(permission: ContactsPermission(), message: "We use this to steal\r\nyour friends")
        multiPscope.addPermission(permission: NotificationsPermission(), message: "We use this to send you\r\nspam and love notes")
        multiPscope.addPermission(permission: LocationWhileInUsePermission(), message: "We use this to track\r\nwhere you live")

        noUIPscope.addPermission(permission: NotificationsPermission(), message: "notifications")
        noUIPscope.addPermission(permission: MicrophonePermission(), message: "microphone")
        noUIPscope.onAuthChange = { (finished, results) in

            print("auth change", finished, results)
        }
    }

    func checkContacts() {

        switch TooolsPermissionScope().statusContacts() {

        case .unknown:
            TooolsPermissionScope().requestContacts()
        case .unauthorized, .disabled:
            return
        case .authorized:
            return
        }
    }

    @IBAction func singlePerm() {

        singlePscope.show(authChange: { _, results in

            print("got results \(results)")
        }, cancelled: { _ in

            print("thing was cancelled")
        })
    }

    @IBAction func multiPerms() {

        multiPscope.show(authChange: { _, results in

            print("got results \(results)")
        }, cancelled: { _ in

            print("thing was cancelled")
        })
    }

    @IBAction func noUIPerm() {

        noUIPscope.requestNotifications()
    }
}

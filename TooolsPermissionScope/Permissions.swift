//
//  Permissions.swift
//  PermissionScope
//
//  Created by Nick O'Neill on 8/25/15.
//  Copyright © 2015 That Thing in Swift. All rights reserved.
//

import Foundation
import CoreLocation
import AddressBook
import AVFoundation
import Photos
import EventKit
import CoreBluetooth
import CoreMotion
import CloudKit
import Accounts

/**
*  Protocol for permission configurations.
*/
public protocol Permission {

    /// Permission type
    var type: PermissionType { get }
}

public class NotificationsPermission: NSObject, Permission {

    public let type: PermissionType = .notifications
}

public class LocationWhileInUsePermission: NSObject, Permission {

    public let type: PermissionType = .locationInUse
}

public class LocationAlwaysPermission: NSObject, Permission {

    public let type: PermissionType = .locationAlways
}

public class ContactsPermission: NSObject, Permission {

    public let type: PermissionType = .contacts
}

public typealias RequestPermissionUnknownResult = () -> Void
public typealias RequestPermissionShowAlert = (PermissionType) -> Void

public class EventsPermission: NSObject, Permission {

    public let type: PermissionType = .events
}

public class MicrophonePermission: NSObject, Permission {

    public let type: PermissionType = .microphone
}

public class CameraPermission: NSObject, Permission {

    public let type: PermissionType = .camera
}

public class PhotosPermission: NSObject, Permission {

    public let type: PermissionType = .photos
}

public class RemindersPermission: NSObject, Permission {

    public let type: PermissionType = .reminders
}

public class BluetoothPermission: NSObject, Permission {

    public let type: PermissionType = .bluetooth
}

public class MotionPermission: NSObject, Permission {

    public let type: PermissionType = .motion
}

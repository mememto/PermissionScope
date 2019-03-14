//
//  PermissionScope.swift
//  PermissionScope
//
//  Created by Nick O'Neill on 4/5/15.
//  Copyright (c) 2015 That Thing in Swift. All rights reserved.
//

import UIKit
import CoreLocation
import AddressBook
import AVFoundation
import Photos
import EventKit
import CoreBluetooth
import CoreMotion
import Contacts
import UserNotifications

public typealias StatusRequestClosure = (_ status: PermissionStatus) -> Void
public typealias AuthClosureType = (_ finished: Bool, _ results: [PermissionResult]) -> Void
public typealias CancelClosureType = (_ results: [PermissionResult]) -> Void
typealias ResultsForConfigClosure = ([PermissionResult]) -> Void

public class TooolsPermissionScope: UIViewController, CLLocationManagerDelegate, UIGestureRecognizerDelegate, CBPeripheralManagerDelegate { //swiftlint:disable:this type_body_length

    //********************************************************
    // MARK: - Parameters
    //********************************************************
    /// Header UILabel with the message "Hey, listen!" by default.
    public var headerLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 50))
    /// Header UILabel with the message "We need a couple things\r\nbefore you get started." by default.
    public var bodyLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 240, height: 70))
    /// Color for the close button's text color.
    public var closeButtonTextColor = UIColor(red: 0, green: 0.47, blue: 1, alpha: 1)
    /// Color for the permission buttons' text color.
    public var permissionButtonTextColor = UIColor(red: 0, green: 0.47, blue: 1, alpha: 1)
    /// Color for the permission buttons' border color.
    public var permissionButtonBorderColor = UIColor(red: 0, green: 0.47, blue: 1, alpha: 1)
    /// Width for the permission buttons.
    public var permissionButtonΒorderWidth: CGFloat = 1
    /// Corner radius for the permission buttons.
    public var permissionButtonCornerRadius: CGFloat = 6
    /// Color for the permission labels' text color.
    public var permissionLabelColor: UIColor = .black
    /// Font used for all the UIButtons
    public var buttonFont: UIFont = .boldSystemFont(ofSize: 14)
    /// Font used for all the UILabels
    public var labelFont: UIFont = .systemFont(ofSize: 14)
    /// Close button. By default in the top right corner.
    public var closeButton = UIButton(frame: CGRect(x: 0, y: 0, width: 50, height: 32))
    /// Offset used to position the Close button.
    public var closeOffset = CGSize.zero
    /// Color used for permission buttons with authorized status
    public var authorizedButtonColor = UIColor(red: 0, green: 0.47, blue: 1, alpha: 1)
    /// Color used for permission buttons with unauthorized status. By default, inverse of `authorizedButtonColor`.
    public var unauthorizedButtonColor: UIColor?
    /// Messages for the body label of the dialog presented when requesting access.
    lazy var permissionMessages: [PermissionType: String] = [PermissionType: String]()

    //********************************************************
    // MARK: - View Hierarchy for custom alert
    //********************************************************
    let baseView    = UIView()
    public let contentView = UIView()

    //********************************************************
    // MARK: - Lazy managers...
    //********************************************************
    lazy var locationManager: CLLocationManager = {

        let locationmanager = CLLocationManager()
        locationmanager.delegate = self
        return locationmanager
    }()

    lazy var bluetoothManager: CBPeripheralManager = {

        return CBPeripheralManager(delegate: self, queue: nil, options: [CBPeripheralManagerOptionShowPowerAlertKey: false])
    }()

    lazy var motionManager: CMMotionActivityManager = {

        return CMMotionActivityManager()
    }()

    /// NSUserDefaults standardDefaults lazy var
    lazy var defaults: UserDefaults = {

        return .standard
    }()

    /// Default status for Core Motion Activity
    var motionPermissionStatus: PermissionStatus = .unknown

    //********************************************************
    // MARK: - Interal State & Resolution
    //********************************************************
    var configuredPermissions: [Permission] = []
    var permissionButtons: [UIButton] = []
    var permissionLabels: [UILabel] = []

    public var onAuthChange: AuthClosureType?
    public var onCancel: CancelClosureType?
    public var onDisabledOrDenied: CancelClosureType?
    public var viewControllerForAlerts: UIViewController?

    //********************************************************
    // MARK: - Utility functions
    //********************************************************
    /**
     Checks whether all the configured permission are authorized or not.
     - parameter completion: Closure used to send the result of the check.
     */
    func allAuthorized(completion: @escaping (Bool) -> Void ) {

        getResultsForConfig { results in

            let result = results.first { $0.status != .authorized }.isNil
            completion(result)
        }
    }

    /**
     Checks whether all the required configured permission are authorized or not.
     **Deprecated** See issues #50 and #51.
     - parameter completion: Closure used to send the result of the check.
     */
    func requiredAuthorized(completion: @escaping (Bool) -> Void ) {

        getResultsForConfig { results in

            let result = results.first { $0.status != .authorized }.isNil
            completion(result)
        }
    }

    // use the code we have to see permission status
    public func permissionStatuses(permissionTypes: [PermissionType]?) -> [PermissionType: PermissionStatus] {

        var statuses = [PermissionType: PermissionStatus]()
        let types: [PermissionType] = permissionTypes ?? PermissionType.allValues

        for type in types {

            statusForPermission(type: type, completion: { status in

                statuses[type] = status
            })
        }
        return statuses
    }

    //********************************************************
    // MARK: - Initialization
    //********************************************************
    public init(backgroundTapCancels: Bool) {

        super.init(nibName: nil, bundle: nil)

        viewControllerForAlerts = self

        // Set up main view
        view.frame = UIScreen.main.bounds
        view.autoresizingMask = [UIView.AutoresizingMask.flexibleHeight, UIView.AutoresizingMask.flexibleWidth]
        view.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.7)
        view.addSubview(baseView)
        // Base View
        baseView.frame = view.frame
        baseView.addSubview(contentView)
        if backgroundTapCancels {
            let tap = UITapGestureRecognizer(target: self, action: #selector(cancel))
            tap.delegate = self
            baseView.addGestureRecognizer(tap)
        }
        // Content View
        contentView.backgroundColor = UIColor.white
        contentView.layer.cornerRadius = 10
        contentView.layer.masksToBounds = true
        contentView.layer.borderWidth = 0.5

        // header label
        headerLabel.font = UIFont.systemFont(ofSize: 22)
        headerLabel.textColor = UIColor.black
        headerLabel.textAlignment = NSTextAlignment.center
        headerLabel.text = "Hey, listen!".localized

        contentView.addSubview(headerLabel)

        // body label
        bodyLabel.font = UIFont.boldSystemFont(ofSize: 16)
        bodyLabel.textColor = UIColor.black
        bodyLabel.textAlignment = NSTextAlignment.center
        bodyLabel.text = "We need a couple things\r\nbefore you get started.".localized
        bodyLabel.numberOfLines = 2

        contentView.addSubview(bodyLabel)

        // close button
        closeButton.setTitle("Close".localized, for: .normal)
        closeButton.addTarget(self, action: #selector(cancel), for: .touchUpInside)

        contentView.addSubview(closeButton)

        _ = self.statusMotion() //Added to check motion status on load
    }

    public convenience init() {

        self.init(backgroundTapCancels: true)
    }

    required public init(coder aDecoder: NSCoder) {

        fatalError("init(coder:) has not been implemented")
    }

    override public init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {

        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    public override func viewWillLayoutSubviews() { //swiftlint:disable:this function_body_length

        super.viewWillLayoutSubviews()
        let screenSize = UIScreen.main.bounds.size
        // Set background frame
        view.frame.size = screenSize
        // Set frames
        let xPos = (screenSize.width - Constants.UIConstants.contentWidth) / 2

        let dialogHeight: CGFloat
        switch self.configuredPermissions.count {

        case 2:
            dialogHeight = Constants.UIConstants.dialogHeightTwoPermissions
        case 3:
            dialogHeight = Constants.UIConstants.dialogHeightThreePermissions
        default:
            dialogHeight = Constants.UIConstants.dialogHeightSinglePermission
        }

        let yPos = (screenSize.height - dialogHeight) / 2
        contentView.frame = CGRect(x: xPos, y: yPos, width: Constants.UIConstants.contentWidth, height: dialogHeight)

        // offset the header from the content center, compensate for the content's offset
        headerLabel.center = contentView.center
        headerLabel.frame.offsetInPlace(-contentView.frame.origin.x, -contentView.frame.origin.y)
        headerLabel.frame.offsetInPlace(0, -((dialogHeight/2)-50))

        // ... same with the body
        bodyLabel.center = contentView.center
        bodyLabel.frame.offsetInPlace(-contentView.frame.origin.x, -contentView.frame.origin.y)
        bodyLabel.frame.offsetInPlace(0, -((dialogHeight/2)-100))

        closeButton.center = contentView.center
        closeButton.frame.offsetInPlace(-contentView.frame.origin.x, -contentView.frame.origin.y)
        closeButton.frame.offsetInPlace(105, -((dialogHeight/2)-20))
        closeButton.frame.offsetInPlace(self.closeOffset.width, self.closeOffset.height)
        if closeButton.imageView?.image != nil {

            closeButton.setTitle("", for: .normal)
        }
        closeButton.setTitleColor(closeButtonTextColor, for: .normal)

        DispatchQueue.main.async {

            let baseOffset = 95
            var index = 0
            var index2 = 0
            for button in self.permissionButtons {

                NSLog("index1 \(index)")

                button.center = self.contentView.center
                button.frame.offsetInPlace(-self.contentView.frame.origin.x, -self.contentView.frame.origin.y)
                button.frame.offsetInPlace(0, -((dialogHeight/2)-160) + CGFloat(index * baseOffset))

                let type = self.configuredPermissions[index].type
                self.statusForPermission(type: type, completion: { currentStatus in

                    DispatchQueue.main.async {

                        let prettyDescription = type.prettyDescription
                        if currentStatus == .authorized {

                            self.setButtonAuthorizedStyle(button: button)
                            button.setTitle("Allowed \(prettyDescription)".localized.uppercased(), for: .normal)
                        } else if currentStatus == .unauthorized {

                            self.setButtonUnauthorizedStyle(button: button)
                            button.setTitle("Denied \(prettyDescription)".localized.uppercased(), for: .normal)
                        } else if currentStatus == .disabled {

                            button.setTitle("\(prettyDescription) Disabled".localized.uppercased(), for: .normal)
                        }

                        NSLog("index2 \(index2)")

                        let label = self.permissionLabels[index2]
                        label.center = self.contentView.center
                        label.frame.offsetInPlace(-self.contentView.frame.origin.x, -self.contentView.frame.origin.y)
                        label.frame.offsetInPlace(0, -((dialogHeight/2)-205) + CGFloat(index2 * baseOffset))

                        index2 += 1
                    }
                })
                index += 1
            }
        }
    }

    //********************************************************
    // MARK: - Customizing the permissions
    //********************************************************
    /**
     Adds a permission configuration to PermissionScope.

     - parameter config: Configuration for a specific permission.
     - parameter message: Body label's text on the presented dialog when requesting access.
     */
    public func addPermission(permission: Permission, message: String) {

        assert(!message.isEmpty, "Including a message about your permission usage is helpful")
        assert(configuredPermissions.count < 3, "Ask for three or fewer permissions at a time")
        assert(configuredPermissions.first { $0.type == permission.type }.isNil, "Permission for \(permission.type) already set")

        configuredPermissions.append(permission)
        permissionMessages[permission.type] = message

        if permission.type == .bluetooth && askedBluetooth {

            triggerBluetoothStatusUpdate()
        } else if permission.type == .motion && askedMotion {

            triggerMotionStatusUpdate()
        }
    }

    /**
     Permission button factory. Uses the custom style parameters such as `permissionButtonTextColor`, `buttonFont`, etc.
     - parameter type: Permission type
     - returns: UIButton instance with a custom style.
     */
    func permissionStyledButton(type: PermissionType) -> UIButton { //swiftlint:disable:this cyclomatic_complexity

        let button = UIButton(frame: CGRect(x: 0, y: 0, width: 240, height: 40))
        button.setTitleColor(permissionButtonTextColor, for: .normal)
        button.titleLabel?.font = buttonFont

        button.layer.borderWidth = permissionButtonΒorderWidth
        button.layer.borderColor = permissionButtonBorderColor.cgColor
        button.layer.cornerRadius = permissionButtonCornerRadius

        // this is a bit of a mess, eh?
        switch type {

        case .locationAlways, .locationInUse:
            button.setTitle("Enable \(type.prettyDescription)".localized.uppercased(), for: .normal)
        default:
            button.setTitle("Allow \(type)".localized.uppercased(), for: .normal)
        }
        switch type {

        case .bluetooth:
            button.addTarget(self, action: #selector(requestBluetooth), for: .touchUpInside)
        case .camera:
            button.addTarget(self, action: #selector(requestCamera), for: .touchUpInside)
        case .contacts:
            button.addTarget(self, action: #selector(requestContacts), for: .touchUpInside)
        case .events:
            button.addTarget(self, action: #selector(requestEvents), for: .touchUpInside)
        case .locationAlways:
            button.addTarget(self, action: #selector(requestLocationAlways), for: .touchUpInside)
        case .locationInUse:
            button.addTarget(self, action: #selector(requestLocationInUse), for: .touchUpInside)
        case .microphone:
            button.addTarget(self, action: #selector(requestMicrophone), for: .touchUpInside)
        case .motion:
            button.addTarget(self, action: #selector(requestMotion), for: .touchUpInside)
        case .notifications:
            button.addTarget(self, action: #selector(requestNotifications), for: .touchUpInside)
        case .photos:
            button.addTarget(self, action: #selector(requestPhotos), for: .touchUpInside)
        case .reminders:
            button.addTarget(self, action: #selector(requestReminders), for: .touchUpInside)
        }
        return button
    }

    /**
     Sets the style for permission buttons with authorized status.
     - parameter button: Permission button
     */
    func setButtonAuthorizedStyle(button: UIButton) {

        DispatchQueue.main.async {

            button.layer.borderWidth = 0
            button.backgroundColor = self.authorizedButtonColor
            button.setTitleColor(.white, for: .normal)
        }
    }

    /**
     Sets the style for permission buttons with unauthorized status.
     - parameter button: Permission button
     */
    func setButtonUnauthorizedStyle(button: UIButton) {

        button.layer.borderWidth = 0
        button.backgroundColor = unauthorizedButtonColor ?? authorizedButtonColor.inverseColor
        button.setTitleColor(.white, for: .normal)
    }

    /**
     Permission label factory, located below the permission buttons.
     - parameter type: Permission type
     - returns: UILabel instance with a custom style.
     */
    func permissionStyledLabel(type: PermissionType) -> UILabel {

        let label  = UILabel(frame: CGRect(x: 0, y: 0, width: 260, height: 60))
        label.font = labelFont
        label.numberOfLines = 0
        label.textAlignment = .center
        label.text = permissionMessages[type]
        label.textColor = permissionLabelColor

        return label
    }

    //********************************************************
    // MARK: - Location
    //********************************************************
    /**
     Returns the current permission status for accessing LocationAlways.
     - returns: Permission status for the requested type.
     */
    public func statusLocationAlways() -> PermissionStatus {

        guard CLLocationManager.locationServicesEnabled() else { return .disabled }

        let status = CLLocationManager.authorizationStatus()
        switch status {

        case .authorizedAlways:
            return .authorized
        case .restricted, .denied:
            return .unauthorized
        case .authorizedWhenInUse:
            // Curious why this happens? Details on upgrading from WhenInUse to Always:
            // [Check this issue](https://github.com/nickoneill/PermissionScope/issues/24)
            if defaults.bool(forKey: Constants.NSUserDefaultsKeys.requestedInUseToAlwaysUpgrade) {
                return .unauthorized
            } else {

                return .unknown
            }
        case .notDetermined:
            return .unknown
        }
    }

    /**
     Requests access to LocationAlways, if necessary.
     */
    @objc public func requestLocationAlways() {

        let hasAlwaysKey: Bool = !Bundle.main.object(forInfoDictionaryKey: Constants.InfoPlistKeys.locationAlways).isNil
        assert(hasAlwaysKey, Constants.InfoPlistKeys.locationAlways + " not found in Info.plist.")

        let status = statusLocationAlways()
        switch status {
        case .unknown:
            if CLLocationManager.authorizationStatus() == .authorizedWhenInUse {

                defaults.set(true, forKey: Constants.NSUserDefaultsKeys.requestedInUseToAlwaysUpgrade)
                defaults.synchronize()
            }
            locationManager.requestAlwaysAuthorization()
        case .unauthorized:
            self.showDeniedAlert(permission: .locationAlways)
        case .disabled:
            self.showDisabledAlert(permission: .locationInUse)
        default:
            break
        }
    }

    /**
     Returns the current permission status for accessing LocationWhileInUse.
     - returns: Permission status for the requested type.
     */
    public func statusLocationInUse() -> PermissionStatus {

        guard CLLocationManager.locationServicesEnabled() else { return .disabled }

        let status = CLLocationManager.authorizationStatus()
        // if you're already "always" authorized, then you don't need in use
        // but the user can still demote you! So I still use them separately.
        switch status {

        case .authorizedWhenInUse, .authorizedAlways:
            return .authorized
        case .restricted, .denied:
            return .unauthorized
        case .notDetermined:
            return .unknown
        }
    }

    /**
     Requests access to LocationWhileInUse, if necessary.
     */
    @objc public func requestLocationInUse() {

        let hasWhenInUseKey: Bool = !Bundle.main.object(forInfoDictionaryKey: Constants.InfoPlistKeys.locationWhenInUse).isNil
        assert(hasWhenInUseKey, Constants.InfoPlistKeys.locationWhenInUse + " not found in Info.plist.")

        let status = statusLocationInUse()
        switch status {

        case .unknown:
            locationManager.requestWhenInUseAuthorization()
        case .unauthorized:
            self.showDeniedAlert(permission: .locationInUse)
        case .disabled:
            self.showDisabledAlert(permission: .locationInUse)
        default:
            break
        }
    }

    //********************************************************
    // MARK: - Contacts
    //********************************************************
    /**
     Returns the current permission status for accessing Contacts.
     - returns: Permission status for the requested type.
     */
    public func statusContacts() -> PermissionStatus {

        if #available(iOS 9.0, *) {

            let status = CNContactStore.authorizationStatus(for: .contacts)
            switch status {

            case .authorized:
                return .authorized
            case .restricted, .denied:
                return .unauthorized
            case .notDetermined:
                return .unknown
            }
        } else {

            // Fallback on earlier versions
            let status = ABAddressBookGetAuthorizationStatus()
            switch status {

            case .authorized:
                return .authorized
            case .restricted, .denied:
                return .unauthorized
            case .notDetermined:
                return .unknown
            }
        }
    }

    /**
     Requests access to Contacts, if necessary.
     */
    @objc public func requestContacts() {

        let status = statusContacts()
        switch status {

        case .unknown:
            if #available(iOS 9.0, *) {

                CNContactStore().requestAccess(for: .contacts, completionHandler: { (_, _) in

                    self.detectAndCallback()
                })
            } else {

                ABAddressBookRequestAccessWithCompletion(nil) { (_, _) in

                    self.detectAndCallback()
                }
            }
        case .unauthorized:
            self.showDeniedAlert(permission: .contacts)
        default:
            break
        }
    }

    //********************************************************
    // MARK: - Notifications
    //********************************************************
    /**
     Returns the current permission status for accessing Notifications.
     - returns: Permission status for the requested type.
     */
    public func statusNotifications(_ completion: @escaping ((PermissionStatus) -> Void)) {

        UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { (settings) in

            if settings.authorizationStatus == .authorized {

                completion(.authorized)
            } else {

                if self.defaults.bool(forKey: Constants.NSUserDefaultsKeys.requestedNotifications) {

                    completion(.unauthorized)
                } else {

                    completion(.unknown)
                }
            }
        })
    }

    /**
     To simulate the denied status for a notifications permission,
     we track when the permission has been asked for and then detect
     when the app becomes active again. If the permission is not granted
     immediately after becoming active, the user has cancelled or denied
     the request.
     This function is called when we want to show the notifications
     alert, kicking off the entire process.
     */
    @objc func showingNotificationPermission() {

        let notifCenter = NotificationCenter.default

        notifCenter.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        notifCenter.addObserver(self, selector: #selector(finishedShowingNotificationPermission), name: UIApplication.didBecomeActiveNotification, object: nil)
        notificationTimer?.invalidate()
    }

    /**
     A timer that fires the event to let us know the user has asked for
     notifications permission.
     */
    var notificationTimer: Timer?

    /**
     This function is triggered when the app becomes 'active' again after
     showing the notification permission dialog.
     See `showingNotificationPermission` for a more detailed description
     of the entire process.
     */
    @objc func finishedShowingNotificationPermission () {

        NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)

        notificationTimer?.invalidate()

        defaults.set(true, forKey: Constants.NSUserDefaultsKeys.requestedNotifications)
        defaults.synchronize()

        // callback after a short delay, otherwise notifications don't report proper auth
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {

            self.getResultsForConfig { results in

                if let notificationResult = results.first(where: { $0.type == .notifications}) {

                    if notificationResult.status == .unknown {

                        self.showDeniedAlert(permission: notificationResult.type)
                    } else {

                        self.detectAndCallback()
                    }
                } else {

                    return
                }
            }
        })
    }

    /**
     Requests access to User Notifications, if necessary.
     */
    @objc public func requestNotifications() {

        statusNotifications({ status in

            switch status {

            case .unknown:
                NotificationCenter.default.addObserver(self, selector: #selector(self.showingNotificationPermission), name: UIApplication.willResignActiveNotification, object: nil)
                self.notificationTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(self.finishedShowingNotificationPermission), userInfo: nil, repeats: false)

                DispatchQueue.main.async {

                    UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound]) { (_, _) in }
                    UIApplication.shared.registerForRemoteNotifications()
                }
            case .unauthorized:
                self.showDeniedAlert(permission: .notifications)
            case .disabled:
                self.showDisabledAlert(permission: .notifications)
            case .authorized:
                self.detectAndCallback()
            }
        })
    }

    //********************************************************
    // MARK: - Microphone
    //********************************************************
    /**
     Returns the current permission status for accessing the Microphone.
     - returns: Permission status for the requested type.
     */
    public func statusMicrophone() -> PermissionStatus {

        let recordPermission = AVAudioSession.sharedInstance().recordPermission
        switch recordPermission {

        case AVAudioSession.RecordPermission.denied:
            return .unauthorized
        case AVAudioSession.RecordPermission.granted:
            return .authorized
        default:
            return .unknown
        }
    }

    /**
     Requests access to the Microphone, if necessary.
     */
    @objc public func requestMicrophone() {
        let status = statusMicrophone()
        switch status {

        case .unknown:
            AVAudioSession.sharedInstance().requestRecordPermission({ _ in

                self.detectAndCallback()
            })
        case .unauthorized:
            showDeniedAlert(permission: .microphone)
        case .disabled:
            showDisabledAlert(permission: .microphone)
        case .authorized:
            break
        }
    }

    //********************************************************
    // MARK: - Camera
    //********************************************************
    /**
     Returns the current permission status for accessing the Camera.
     - returns: Permission status for the requested type.
     */
    public func statusCamera() -> PermissionStatus {

        let status = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        switch status {

        case .authorized:
            return .authorized
        case .restricted, .denied:
            return .unauthorized
        case .notDetermined:
            return .unknown
        }
    }

    /**
     Requests access to the Camera, if necessary.
     */
    @objc public func requestCamera() {

        let status = statusCamera()
        switch status {

        case .unknown:
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { _ in

                self.detectAndCallback()
            })
        case .unauthorized:
            showDeniedAlert(permission: .camera)
        case .disabled:
            showDisabledAlert(permission: .camera)
        case .authorized:
            break
        }
    }

    //********************************************************
    // MARK: - Photos
    //********************************************************
    /**
     Returns the current permission status for accessing Photos.

     - returns: Permission status for the requested type.
     */
    public func statusPhotos() -> PermissionStatus {

        let status = PHPhotoLibrary.authorizationStatus()
        switch status {

        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .unauthorized
        case .notDetermined:
            return .unknown
        }
    }

    /**
     Requests access to Photos, if necessary.
     */
    @objc public func requestPhotos() {

        let status = statusPhotos()
        switch status {

        case .unknown:
            PHPhotoLibrary.requestAuthorization({ _ in

                self.detectAndCallback()
            })
        case .unauthorized:
            self.showDeniedAlert(permission: .photos)
        case .disabled:
            showDisabledAlert(permission: .photos)
        case .authorized:
            break
        }
    }

    //********************************************************
    // MARK: - Reminders
    //********************************************************
    /**
     Returns the current permission status for accessing Reminders.
     - returns: Permission status for the requested type.
     */
    public func statusReminders() -> PermissionStatus {

        let status = EKEventStore.authorizationStatus(for: .reminder)
        switch status {

        case .authorized:
            return .authorized
        case .restricted, .denied:
            return .unauthorized
        case .notDetermined:
            return .unknown
        }
    }

    /**
     Requests access to Reminders, if necessary.
     */
    @objc public func requestReminders() {

        let status = statusReminders()
        switch status {
        case .unknown:
            EKEventStore().requestAccess(to: .reminder, completion: { _, _ in

                self.detectAndCallback()
            })
        case .unauthorized:
            self.showDeniedAlert(permission: .reminders)
        default:
            break
        }
    }

    //********************************************************
    // MARK: - Events
    //********************************************************
    /**
     Returns the current permission status for accessing Events.
     - returns: Permission status for the requested type.
     */
    public func statusEvents() -> PermissionStatus {

        let status = EKEventStore.authorizationStatus(for: .event)
        switch status {

        case .authorized:
            return .authorized
        case .restricted, .denied:
            return .unauthorized
        case .notDetermined:
            return .unknown
        }
    }

    /**
     Requests access to Events, if necessary.
     */
    @objc public func requestEvents() {

        let status = statusEvents()
        switch status {
        case .unknown:
            EKEventStore().requestAccess(to: .event, completion: { _, _ in

                self.detectAndCallback()
            })
        case .unauthorized:
            self.showDeniedAlert(permission: .events)
        default:
            break
        }
    }

    //********************************************************
    // MARK: - Bluetooth
    //********************************************************
    /// Returns whether Bluetooth access was asked before or not.
    private var askedBluetooth: Bool {

        get {

            return defaults.bool(forKey: Constants.NSUserDefaultsKeys.requestedBluetooth)
        }
        set {

            defaults.set(newValue, forKey: Constants.NSUserDefaultsKeys.requestedBluetooth)
            defaults.synchronize()
        }
    }

    /// Returns whether PermissionScope is waiting for the user to enable/disable bluetooth access or not.
    private var waitingForBluetooth = false

    /**
     Returns the current permission status for accessing Bluetooth.
     - returns: Permission status for the requested type.
     */
    public func statusBluetooth() -> PermissionStatus {

        // if already asked for bluetooth before, do a request to get status, else wait for user to request
        if askedBluetooth {

            triggerBluetoothStatusUpdate()
        } else {

            return .unknown
        }

        let state = (bluetoothManager.state, CBPeripheralManager.authorizationStatus())
        switch state {

        case (.unsupported, _), (.poweredOff, _), (_, .restricted):
            return .disabled
        case (.unauthorized, _), (_, .denied):
            return .unauthorized
        case (.poweredOn, .authorized):
            return .authorized
        default:
            return .unknown
        }

    }

    /**
     Requests access to Bluetooth, if necessary.
     */
    @objc public func requestBluetooth() {

        let status = statusBluetooth()
        switch status {

        case .disabled:
            showDisabledAlert(permission: .bluetooth)
        case .unauthorized:
            showDeniedAlert(permission: .bluetooth)
        case .unknown:
            triggerBluetoothStatusUpdate()
        default:
            break
        }

    }

    /**
     Start and immediately stop bluetooth advertising to trigger
     its permission dialog.
     */
    private func triggerBluetoothStatusUpdate() {

        if !waitingForBluetooth && bluetoothManager.state == .unknown {

            bluetoothManager.startAdvertising(nil)
            bluetoothManager.stopAdvertising()
            askedBluetooth = true
            waitingForBluetooth = true
        }
    }

    //********************************************************
    // MARK: - Core Motion Activity
    //********************************************************
    /**
     Returns the current permission status for accessing Core Motion Activity.
     - returns: Permission status for the requested type.
     */
    public func statusMotion() -> PermissionStatus {

        if askedMotion {

            triggerMotionStatusUpdate()
        }
        return motionPermissionStatus
    }

    /**
     Requests access to Core Motion Activity, if necessary.
     */
    @objc public func requestMotion() {

        let status = statusMotion()
        switch status {

        case .unauthorized:
            showDeniedAlert(permission: .motion)
        case .unknown:
            triggerMotionStatusUpdate()
        default:
            break
        }
    }

    /**
     Prompts motionManager to request a status update. If permission is not already granted the user will be prompted with the system's permission dialog.
     */
    private func triggerMotionStatusUpdate() {

        let tmpMotionPermissionStatus = motionPermissionStatus
        defaults.set(true, forKey: Constants.NSUserDefaultsKeys.requestedMotion)
        defaults.synchronize()

        let today = Date()
        motionManager.queryActivityStarting(from: today, to: today, to: .main) { _, error in

            if let error = error, error._code == Int(CMErrorMotionActivityNotAuthorized.rawValue) {

                self.motionPermissionStatus = .unauthorized
            } else {

                self.motionPermissionStatus = .authorized
            }
            self.motionManager.stopActivityUpdates()
            if tmpMotionPermissionStatus != self.motionPermissionStatus {

                self.waitingForMotion = false
                self.detectAndCallback()
            }
        }

        askedMotion = true
        waitingForMotion = true
    }

    /// Returns whether Bluetooth access was asked before or not.
    private var askedMotion: Bool {

        get {

            return defaults.bool(forKey: Constants.NSUserDefaultsKeys.requestedMotion)
        }
        set {

            defaults.set(newValue, forKey: Constants.NSUserDefaultsKeys.requestedMotion)
            defaults.synchronize()
        }
    }

    /// Returns whether PermissionScope is waiting for the user to enable/disable motion access or not.
    private var waitingForMotion = false

    //********************************************************
    // MARK: - UI
    //********************************************************
    /**
     Shows the modal viewcontroller for requesting access to the configured permissions and sets up the closures on it.
     - parameter authChange: Called when a status is detected on any of the permissions.
     - parameter cancelled:  Called when the user taps the Close button.
     */
    public func show(authChange: AuthClosureType? = nil, cancelled: CancelClosureType? = nil) {

        assert(!configuredPermissions.isEmpty, "Please add at least one permission")

        onAuthChange = authChange
        onCancel = cancelled

        DispatchQueue.main.async {

            while self.waitingForBluetooth || self.waitingForMotion { }

            // call other methods that need to wait before show
            // no missing required perms? callback and do nothing
            self.requiredAuthorized(completion: { areAuthorized in

                if areAuthorized {

                    self.getResultsForConfig(completionBlock: { results in

                        self.onAuthChange?(true, results)
                    })
                } else {

                    self.showAlert()
                }
            })
        }
    }

    /**
     Creates the modal viewcontroller and shows it.
     */
    private func showAlert() {

        DispatchQueue.main.async {

            // add the backing views
            let window = UIApplication.shared.keyWindow!

            //hide KB if it is shown
            window.endEditing(true)

            window.addSubview(self.view)
            self.view.frame = window.bounds
            self.baseView.frame = window.bounds

            for button in self.permissionButtons {

                button.removeFromSuperview()
            }
            self.permissionButtons = []

            for label in self.permissionLabels {

                label.removeFromSuperview()
            }
            self.permissionLabels = []

            // create the buttons
            for permission in self.configuredPermissions {

                let button = self.permissionStyledButton(type: permission.type)
                self.permissionButtons.append(button)
                self.contentView.addSubview(button)

                let label = self.permissionStyledLabel(type: permission.type)
                self.permissionLabels.append(label)
                self.contentView.addSubview(label)
            }

            self.view.setNeedsLayout()

            // slide in the view
            self.baseView.frame.origin.y = self.view.bounds.origin.y - self.baseView.frame.size.height
            self.view.alpha = 0

            UIView.animate(withDuration: 0.2, delay: 0.0, options: [], animations: {

                self.baseView.center.y = window.center.y + 15
                self.view.alpha = 1
            }, completion: { _ in

                UIView.animate(withDuration: 0.2, animations: {

                    self.baseView.center = window.center
                })
            })
        }
    }

    /**
     Hides the modal viewcontroller with an animation.
     */
    public func hide() {

        DispatchQueue.main.async {

            let window = UIApplication.shared.keyWindow!

            UIView.animate(withDuration: 0.2, animations: {

                self.baseView.frame.origin.y = window.center.y + 400
                self.view.alpha = 0
            }, completion: { _ in

                self.view.removeFromSuperview()
            })
            self.notificationTimer?.invalidate()
            self.notificationTimer = nil
        }
    }

    //********************************************************
    // MARK: - Gesture Delegate
    //********************************************************
    public func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {

        // this prevents our tap gesture from firing for subviews of baseview
        if touch.view == baseView {

            return true
        }
        return false
    }

    //********************************************************
    // MARK: - Location Delegate
    //********************************************************
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {

        detectAndCallback()
    }

    //********************************************************
    // MARK: - Bluetooth Delegate
    //********************************************************
    public func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {

        waitingForBluetooth = false
        detectAndCallback()
    }

    //********************************************************
    // MARK: - UI Helpers
    //********************************************************
    /**
     Called when the users taps on the close button.
     */
    @objc func cancel() {

        self.hide()
        if let onCancel = onCancel {

            getResultsForConfig(completionBlock: { results in

                onCancel(results)
            })
        }
    }

    /**
     Shows an alert for a permission which was Denied.
     - parameter permission: Permission type.
     */
    func showDeniedAlert(permission: PermissionType) {

        // compile the results and pass them back if necessary
        if let onDisabledOrDenied = self.onDisabledOrDenied {

            self.getResultsForConfig(completionBlock: { results in

                onDisabledOrDenied(results)
            })
        }

        let alert = UIAlertController(title: "Permission for \(permission.prettyDescription) was denied.".localized, message: "Please enable access to \(permission.prettyDescription) in the Settings app".localized, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Show me".localized, style: .default, handler: { _ in

            NotificationCenter.default.addObserver(self, selector: #selector(self.appForegroundedAfterSettings), name: UIApplication.didBecomeActiveNotification, object: nil)
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {

                UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
            }
        }))
        DispatchQueue.main.async {

            self.viewControllerForAlerts?.present(alert, animated: true, completion: nil)
        }
    }

    /**
     Shows an alert for a permission which was Disabled (system-wide).
     - parameter permission: Permission type.
     */
    func showDisabledAlert(permission: PermissionType) {

        // compile the results and pass them back if necessary
        if let onDisabledOrDenied = self.onDisabledOrDenied {

            self.getResultsForConfig(completionBlock: { results in

                onDisabledOrDenied(results)
            })
        }

        let alert = UIAlertController(title: "\(permission.prettyDescription) is currently disabled.".localized, message: "Please enable access to \(permission.prettyDescription) in Settings".localized, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Show me".localized, style: .default, handler: { _ in

            NotificationCenter.default.addObserver(self, selector: #selector(self.appForegroundedAfterSettings), name: UIApplication.didBecomeActiveNotification, object: nil)
            if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {

                UIApplication.shared.open(settingsUrl, options: [:], completionHandler: nil)
            }
        }))

        DispatchQueue.main.async {

            self.viewControllerForAlerts?.present(alert, animated: true, completion: nil)
        }
    }

    //********************************************************
    // MARK: - Helpers
    //********************************************************
    /**
     This notification callback is triggered when the app comes back
     from the settings page, after a user has tapped the "show me"
     button to check on a disabled permission. It calls detectAndCallback
     to recheck all the permissions and update the UI.
     */
    @objc func appForegroundedAfterSettings() {

        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
        detectAndCallback()
    }

    /**
     Requests the status of any permission.

     - parameter type:       Permission type to be requested
     - parameter completion: Closure called when the request is done.
     */
    func statusForPermission(type: PermissionType, completion: @escaping StatusRequestClosure) { //swiftlint:disable:this cyclomatic_complexity

        let permissionStatus: PermissionStatus
        switch type {

        case .locationAlways:
            permissionStatus = statusLocationAlways()
            completion(permissionStatus)
        case .locationInUse:
            permissionStatus = statusLocationInUse()
            completion(permissionStatus)
        case .contacts:
            permissionStatus = statusContacts()
            completion(permissionStatus)
        case .microphone:
            permissionStatus = statusMicrophone()
            completion(permissionStatus)
        case .camera:
            permissionStatus = statusCamera()
            completion(permissionStatus)
        case .photos:
            permissionStatus = statusPhotos()
            completion(permissionStatus)
        case .reminders:
            permissionStatus = statusReminders()
            completion(permissionStatus)
        case .events:
            permissionStatus = statusEvents()
            completion(permissionStatus)
        case .bluetooth:
            permissionStatus = statusBluetooth()
            completion(permissionStatus)
        case .motion:
            permissionStatus = statusMotion()
            completion(permissionStatus)
        case .notifications:
            statusNotifications({ status in

                completion(status)
            })
        }
    }

    /**
     Rechecks the status of each requested permission, updates
     the PermissionScope UI in response and calls your onAuthChange
     to notifiy the parent app.
     */
    func detectAndCallback() {

        DispatchQueue.main.async {

            if let onAuthChange = self.onAuthChange {

                self.getResultsForConfig(completionBlock: { results in

                    self.allAuthorized(completion: { areAuthorized in

                        onAuthChange(areAuthorized, results)
                    })
                })
            }

            self.view.setNeedsLayout()

            // and hide if we've sucessfully got all permissions
            self.allAuthorized(completion: { areAuthorized in

                if areAuthorized {

                    self.hide()
                }
            })
        }
    }

    /**
     Calculates the status for each configured permissions for the caller
     */
    func getResultsForConfig(completionBlock: @escaping ResultsForConfigClosure) {

        var results: [PermissionResult] = []

        for config in configuredPermissions {

            self.statusForPermission(type: config.type, completion: { status in

                let result = PermissionResult(type: config.type, status: status)
                results.append(result)
                if results.count == self.configuredPermissions.count {

                    completionBlock(results)
                }
            })
        }
        //completionBlock(results)
    }
} //swiftlint:disable:this file_length

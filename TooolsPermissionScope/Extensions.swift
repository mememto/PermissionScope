//
//  Extensions.swift
//  PermissionScope
//
//  Created by Nick O'Neill on 8/21/15.
//  Copyright © 2015 That Thing in Swift. All rights reserved.
//

import Foundation
import UIKit

extension UIColor {

    /// Returns the inverse color
    var inverseColor: UIColor {

        var red: CGFloat = 0.0
        var green: CGFloat = 0.0
        var blue: CGFloat = 0.0
        var alpha: CGFloat = 0.0
        if self.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {

            return UIColor(red: 1.0 - red, green: 1.0 - green, blue: 1.0 - blue, alpha: alpha)
        }
        return self
    }
}

extension String {

    /// NSLocalizedString shorthand
    var localized: String {

        return NSLocalizedString(self, comment: "")
    }
}

extension Optional {

    /// True if the Optional is .None. Useful to avoid if-let.
    var isNil: Bool {

        if case .none = self {

            return true
        }
        return false
    }
}

extension CGRect {

    mutating func offsetInPlace(_ xOffset: CGFloat, _ yOffset: CGFloat) {

        self = self.offsetBy(dx: xOffset, dy: yOffset)
    }
}

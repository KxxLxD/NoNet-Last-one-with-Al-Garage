import SwiftUI

/// One spacing and corner scale for every custom layout. Native `List`/`Form` screens
/// get Apple's own metrics; these keep the few custom screens consistent with them.
enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32
}

enum Radius {
    /// Buttons and text fields.
    static let control: CGFloat = 14
    /// Cards and grouped surfaces (matches inset-grouped lists).
    static let card: CGFloat = 20
}

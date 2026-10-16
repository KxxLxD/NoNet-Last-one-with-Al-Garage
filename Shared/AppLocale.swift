import Foundation

extension Locale {
    /// The user's locale with Western digits (360, not ٣٦٠) whatever the device region,
    /// so numbers look the same everywhere in Samla. Pass it to every number/date format
    /// and to `String(localized:locale:)` when the string interpolates numbers.
    static var app: Locale {
        var components = Locale.Components(locale: .current)
        components.numberingSystem = Locale.NumberingSystem("latn")
        return Locale(components: components)
    }
}

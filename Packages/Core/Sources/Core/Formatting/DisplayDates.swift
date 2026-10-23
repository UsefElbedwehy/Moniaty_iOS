import Foundation

/// Dates on screen use the Gregorian calendar in every language. A Saudi region otherwise
/// defaults to Umm al-Qura, which showed Hijri days (with no year) in Arabic while English, the
/// backend and the booking emails all use Gregorian. Month names and digits still follow the
/// user's language. Switching the app to Hijri would be a change here only.
public extension Calendar {
    static var display: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = .current
        calendar.timeZone = .current
        return calendar
    }
}

public extension Date {
    /// `formatted(date:time:)` in the display calendar.
    func displayFormatted(date: Date.FormatStyle.DateStyle, time: Date.FormatStyle.TimeStyle) -> String {
        formatted(Date.FormatStyle(date: date, time: time, calendar: .display))
    }

    /// `formatted(_:)` for a `.dateTime…` style, in the display calendar.
    func displayFormatted(_ style: Date.FormatStyle) -> String {
        var style = style
        style.calendar = .display
        return formatted(style)
    }
}

import Foundation

/// A source of LED frames for a given mode.
///
/// Given a moment in time and the active controller layout, produce exactly one
/// frame of per-LED colors (`result.count == layout.count`). Implementations are
/// classes so the engine can hold and reconfigure them.
public protocol ModeSource: AnyObject {
    func frame(at date: Date, layout: LEDLayout) -> [RGB]
}

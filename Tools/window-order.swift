// Lists on-screen windows front to back, so a check can assert what is on top.
// Window titles need no special permission here; screen recording is not used.
import CoreGraphics
import Foundation

guard let list = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
) as? [[String: Any]] else { exit(1) }

for w in list {
    let owner = (w[kCGWindowOwnerName as String] as? String) ?? "?"
    let layer = (w[kCGWindowLayer as String] as? Int) ?? -999
    let name = (w[kCGWindowName as String] as? String) ?? ""
    print("layer=\(layer)\t\(owner)\t\(name)")
}

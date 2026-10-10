import Foundation
import FuelSwitchCore

extension AppModel {
    enum ResetResult: Equatable {
        case completed(String)
        case failed(String)
    }

    enum LoginState: Equatable {
        case idle
        case running(Provider)
        case failed(Provider, String)
        case added(String)
        case reconnected(String)
        case switched(Provider, String)
        case autoSwitched(Provider, from: String, to: String)
    }
}

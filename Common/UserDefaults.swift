import Foundation

extension UserDefaults {
    public static var appGroup: UserDefaults {
        UserDefaults(suiteName: APP_GROUP_ID)!
    }
}

public func getRlamusFrom(userDefaults: UserDefaults) -> RlamusClient? {
    guard let setUrl = userDefaults.string(forKey: "rlamusURL"),
          let endpoint = URL(string: setUrl) else {
        return nil
    }
    return RlamusClient(endpoint: endpoint)
}

public func setRlamusTo(userDefaults: UserDefaults, endpoint: URL?) {
    userDefaults.setValue(endpoint?.absoluteString, forKey: "rlamusURL")
}

public func setDeviceToken(_ newValue: Data, to: UserDefaults) {
    to.set(newValue, forKey: "deviceToken")
}

public func getDeviceToken(from: UserDefaults) -> Data? {
    from.data(forKey: "deviceToken")
}

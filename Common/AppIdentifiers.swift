import Foundation

public let DEEP_LINK_SCHEME = Bundle(for: ThisBundle.self).object(forInfoDictionaryKey: "DEEP_LINK_SCHEME") as! String
public let APP_GROUP_ID = Bundle(for: ThisBundle.self).object(forInfoDictionaryKey: "APP_GROUP_ID") as! String
public let APP_CODENAME = Bundle(for: ThisBundle.self).object(forInfoDictionaryKey: "APP_CODENAME") as! String

fileprivate class ThisBundle: NSObject {}

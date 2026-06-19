import Foundation
import RealmSwift
import Realm

let currentVersion: UInt64 = 1

public var realmConfig: Realm.Configuration {
    Realm.Configuration(
        fileURL: FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: APP_GROUP_ID)!.appending(component: "realm"),
        schemaVersion: currentVersion,
        migrationBlock: { migration, oldVersion in
            let migrations: [UInt64: (Migration) -> Void] = [
                0: zeroToOne
            ]
            for version in oldVersion ..< currentVersion {
                migrations[version]!(migration)
            }
        }
    )
}

func zeroToOne(_ migration: Migration) {
    var count = 0
    migration.enumerateObjects(ofType: MemoryItem.className()) { oldObject, newObject in
        newObject!["_id"] = ObjectId(timestamp: .now, machineId: 0, processId: count)
        count += 1
    }
}

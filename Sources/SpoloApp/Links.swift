import Foundation

/// Pages on tang-spark.no, in the language the app is running in.
enum Links {
    private static var pageSuffix: String {
        switch Bundle.main.preferredLocalizations.first {
        case "zh-Hans": "-zh-cn"
        case "zh-Hant": "-zh-tw"
        default: ""
        }
    }

    static var website: URL { URL(string: "https://tang-spark.no/spolo\(pageSuffix).html")! }
    static var support: URL { URL(string: "https://tang-spark.no/spolo-support\(pageSuffix).html")! }
    static let contact = URL(string: "mailto:support@tang-spark.no?subject=Spolo")!

    #if !APPSTORE
    /// The download page compares the installed version it is given with the latest one.
    /// The App Store version is updated by the App Store, so it has no such link.
    static var newVersion: URL {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        return URL(string: "https://tang-spark.no/spolo\(pageSuffix).html?installed=\(version)#download")!
    }
    #endif
}

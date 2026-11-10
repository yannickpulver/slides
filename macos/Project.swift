import Foundation
import ProjectDescription

/// `MARKETING_VERSION` comes from the repo-root `VERSION` file, overridable with `TUIST_SLIDES_VERSION`.
let marketingVersion: String = {
    let override = Environment.slidesVersion.getString(default: "")
    if !override.isEmpty { return override }
    let versionFile = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("VERSION")
    let contents = (try? String(contentsOf: versionFile, encoding: .utf8)) ?? ""
    let trimmed = contents.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? "0.0.0" : trimmed
}()

/// `CURRENT_PROJECT_VERSION`, overridable with `TUIST_SLIDES_BUILD`. Sparkle compares this number.
let buildVersion: String = {
    let override = Environment.slidesBuild.getString(default: "")
    return override.isEmpty ? "1" : override
}()

let sharedSettings: SettingsDictionary = [
    "MARKETING_VERSION": .string(marketingVersion),
    "CURRENT_PROJECT_VERSION": .string(buildVersion),
    "SWIFT_VERSION": "6.0",
    "SWIFT_STRICT_CONCURRENCY": "complete",
    "MACOSX_DEPLOYMENT_TARGET": "26.0",
    "DEAD_CODE_STRIPPING": "YES",
]

let appSettings: SettingsDictionary = sharedSettings.merging([
    // Notarization needs the hardened runtime. No sandbox: media is read from anywhere on disk.
    "ENABLE_HARDENED_RUNTIME": "YES",
    "ENABLE_APP_SANDBOX": "NO",
    // Release is ad hoc by default; the CI archive step passes its Developer ID identity and team.
    "CODE_SIGN_IDENTITY": "-",
    "CODE_SIGN_STYLE": "Manual",
    // No custom accent: the app follows the system accent color.
    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "",
]) { _, new in new }

/// Local Debug builds sign with the development certificate, so macOS keeps file permissions across rebuilds.
let debugSigningSettings: SettingsDictionary = [
    "CODE_SIGN_STYLE": "Manual",
    "CODE_SIGN_IDENTITY": "Apple Development",
    "DEVELOPMENT_TEAM": .string(Environment.slidesTeam.getString(default: "337L47P9N7")),
]

let project = Project(
    name: "Slides",
    organizationName: "Yannick Pulver",
    packages: [
        .local(path: "SlidesCore"),
        .remote(url: "https://github.com/sparkle-project/Sparkle", requirement: .upToNextMajor(from: "2.10.0")),
    ],
    settings: .settings(base: sharedSettings),
    targets: [
        .target(
            name: "Slides",
            destinations: [.mac],
            product: .app,
            bundleId: "com.yannickpulver.slides",
            deploymentTargets: .macOS("26.0"),
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "Slides",
                "CFBundleIconFile": "AppIcon",
                "CFBundleShortVersionString": "$(MARKETING_VERSION)",
                "CFBundleVersion": "$(CURRENT_PROJECT_VERSION)",
                "LSApplicationCategoryType": "public.app-category.photography",
                "LSMinimumSystemVersion": "$(MACOSX_DEPLOYMENT_TARGET)",
                "NSHumanReadableCopyright": "© Yannick Pulver",
                // Sparkle: the release workflow attaches `appcast.xml` to every release and
                // signs the zip with the private half of this key (`SPARKLE_PRIVATE_KEY`).
                "SUFeedURL": "https://github.com/yannickpulver/slides/releases/latest/download/appcast.xml",
                "SUPublicEDKey": "tGT29fSlZ7vDkKObxYYT0q20BBewKrfRFQfUBL7oW3o=",
                "SUEnableAutomaticChecks": true,
            ]),
            sources: ["Slides/Sources/**"],
            resources: ["Slides/Resources/**"],
            dependencies: [
                .package(product: "SlidesCore"),
                .package(product: "Sparkle"),
            ],
            settings: .settings(
                base: appSettings,
                configurations: [
                    .debug(name: .debug, settings: debugSigningSettings),
                    .release(name: .release),
                ]
            )
        ),
    ],
    schemes: [
        .scheme(
            name: "Slides",
            shared: true,
            buildAction: .buildAction(targets: ["Slides"]),
            runAction: .runAction(executable: "Slides")
        ),
    ]
)

// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "SalaryTicker",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "SalaryTicker", targets: ["SalaryTicker"]),
    ],
    targets: [
        .executableTarget(
            name: "SalaryTicker",
            path: "SalaryTicker",
            exclude: ["Info.plist"]
        ),
    ]
)

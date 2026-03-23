import AppKit
@testable import Sources_DivvyClick_lib

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
}

_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)

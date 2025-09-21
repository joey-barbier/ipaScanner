import ArgumentParser
import Foundation

struct IPAScanner: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ipascanner",
        abstract: "IPA file analyzer",
        subcommands: [AnalyzeCommand.self],
        defaultSubcommand: AnalyzeCommand.self
    )
}

IPAScanner.main()
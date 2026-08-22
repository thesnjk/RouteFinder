#if os(macOS)
import Foundation

@main
struct RouteFinderCLI {
    static func main() async {
        var args = Array(CommandLine.arguments.dropFirst())
        if args.first == "--" {
            args.removeFirst()
        }
        guard let subcommand = args.first else {
            CLIUsage.printUsage()
            exit(1)
        }

        switch subcommand {
        case "route":
            await RouteCommand.run(Array(args.dropFirst()))
        case "help", "--help", "-h":
            CLIUsage.printUsage()
        default:
            CLIExit.usage("Unknown subcommand: \(subcommand)")
        }
    }
}
#else
@main
enum RouteFinderCLIStub {
    static func main() {
        print("RouteFinder CLI is macOS-only. Use RouteFinderMacApp on macOS GUI or RouteFinderIOS on iOS.")
    }
}
#endif

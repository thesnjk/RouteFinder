import Foundation

enum CLIUsage {
    static func printUsage() {
        print("""
        RouteFinder — headless macOS routing CLI

        Usage:
          RouteFinder <subcommand> [options]

        Subcommands:
          route     Calculate a route (local graph or OpenRouteService cloud)
          help      Show this help

        Local graph routing:
          RouteFinder route \\
            --graph <dir> \\
            --from <node-id> --to <node-id> \\
            [--algorithm astar|dijkstra] \\
            [--weather dry|rain|ice]

        OpenRouteService cloud routing:
          RouteFinder route \\
            --origin <lat,lon> --destination <lat,lon> \\
            [--via <lat,lon> ...] \\
            [--ors-key <key>] \\
            [--hgv] [--height <m>] [--weight <t>] [--width <m>] \\
            [--weather dry|rain|ice] \\
            [--json]

        Environment:
          ORS_API_KEY           HeiGIT API key when --ors-key is omitted
          OPENWEATHER_API_KEY   Required for live weather when --weather is omitted

        Examples:
          swift run RouteFinder -- route --graph ./tiles/norfolk --from n1 --to n2
          swift run RouteFinder -- route --origin 52.63,-1.13 --destination 51.50,-0.12 --ors-key "$ORS_API_KEY" --weather ice
        """)
    }
}

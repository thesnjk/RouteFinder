import DataLayer
import GraphCore
import Foundation

@main
struct PBFPreprocessor {
    static func main() async {
        let args = CommandLine.arguments

        guard args.count >= 3 else {
            printUsage()
            exit(1)
        }

        var inputPath: String?
        var outputPath: String?
        var mode = "csv"
        var resolution = H3Grid.defaultResolution

        var index = 1
        while index < args.count {
            switch args[index] {
            case "--input":
                index += 1
                inputPath = args[index]
            case "--output":
                index += 1
                outputPath = args[index]
            case "--mode":
                index += 1
                mode = args[index]
            case "--resolution":
                index += 1
                if let value = Int(args[index]) { resolution = value }
            default:
                break
            }
            index += 1
        }

        guard let inputPath, let outputPath else {
            printUsage()
            exit(1)
        }

        let outputURL = URL(fileURLWithPath: outputPath, isDirectory: true)

        do {
            switch mode {
            case "csv":
                let nodesPath = inputPath.hasSuffix(".csv") ? inputPath : "\(inputPath)/nodes.csv"
                let edgesPath = inputPath.hasSuffix(".csv") ? inputPath.replacingOccurrences(of: "nodes.csv", with: "edges.csv") : "\(inputPath)/edges.csv"
                let graph = try await Graph.loadFromCSV(nodesPath: nodesPath, edgesPath: edgesPath)
                try TileExporter.exportGraph(graph, to: outputURL, resolution: resolution)
                print("Exported CSV graph (\(graph.nodeCount) nodes) to \(outputPath)")
            case "synthetic":
                let graph = SyntheticGraphBuilder.makeGrid(rows: 10, cols: 10)
                try TileExporter.exportGraph(graph, to: outputURL, resolution: resolution)
                print("Exported synthetic grid to \(outputPath)")
            case "pbf":
                print("PBF ingestion requires osmium-tool. See Scripts/build-global-tiles.sh")
                print("")
                print("OSM way tags exported to edges.csv:")
                print("  highway        -> road_type")
                print("  maxheight      -> max_height (metres)")
                print("  maxweight      -> max_weight (tonnes)")
                print("  maxwidth       -> max_width")
                print("  maxlength      -> max_length")
                print("  hgv=no         -> hgv_restricted")
                print("  motor_vehicle=no -> hgv_restricted")
                print("  oneway=yes     -> is_one_way")
                print("  name           -> road_name")
                print("")
                print("Workflow:")
                print("  ./Scripts/build-global-tiles.sh --pbf region.osm.pbf --output ./tiles")
                exit(2)
            default:
                print("Unknown mode: \(mode)")
                printUsage()
                exit(1)
            }
        } catch {
            fputs("Error: \(error)\n", stderr)
            exit(1)
        }
    }

    static func printUsage() {
        print("""
        PBFPreprocessor — convert routing data into H3-indexed graph tiles

        Usage:
          PBFPreprocessor --input <path> --output <dir> [--mode csv|synthetic|pbf] [--resolution 7]

        Modes:
          csv       Load nodes.csv + edges.csv and export tiles (default)
          synthetic Generate a demo grid graph and export tiles
          pbf       Document OSM tag mapping; use Scripts/build-global-tiles.sh for PBF

        Edge CSV columns (see Graph+CSV.swift):
          from,to,distance,speed,road_type,is_toll,is_ferry,is_tunnel,
          max_height,max_weight,max_width,max_length,has_camera,is_one_way,
          hgv_restricted,road_name
        """)
    }
}

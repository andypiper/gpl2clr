import AppKit
import Foundation

enum GPLConversionError: Error {
    case invalidFile
    case invalidFormat(reason: String)
    case parsingError(line: String)
    case fileCreationError, fileWritingError
}

/// Logs a message conditionally based on verbosity.
func log(_ message: String, verbose: Bool) {
    if verbose {
        print(message)
    }
}

/// Validates and returns a valid output path for the .clr file.
func validateOutputPath(_ path: String) throws -> String {
    let fileManager = FileManager.default
    let directory = URL(fileURLWithPath: path).deletingLastPathComponent().path

    if !fileManager.isWritableFile(atPath: directory) {
        throw GPLConversionError.fileCreationError
    }

    return path.hasSuffix(".clr") ? path : path + ".clr"
}

/// Reads a GIMP .gpl file and extracts color data.
func parseGPL(fileAtPath path: String) throws -> [(name: String, red: CGFloat, green: CGFloat, blue: CGFloat)] {
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
        throw GPLConversionError.invalidFile
    }

    var colors: [(name: String, red: CGFloat, green: CGFloat, blue: CGFloat)] = []
    let lines = content.split(separator: "\n")

    // Validate GPL format
    guard lines.first?.starts(with: "GIMP Palette") == true else {
        if lines.isEmpty {
            throw GPLConversionError.invalidFormat(reason: "The file is empty.")
        } else {
            throw GPLConversionError.invalidFormat(reason: "The file does not start with 'GIMP Palette'.")
        }
    }

    for line in lines.dropFirst() {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.starts(with: "#") || trimmed.starts(with: "Name:") || trimmed.starts(with: "Columns:") {
            continue
        }

        let components = trimmed.split(separator: " ")
        guard components.count >= 3, let r = Int(components[0]), let g = Int(components[1]), let b = Int(components[2]) else {
            throw GPLConversionError.parsingError(line: String(line))
        }

        let name = components.dropFirst(3).joined(separator: " ")
        let colorName = name.isEmpty ? "Color \(colors.count + 1)" : name
        colors.append((name: colorName, red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0))
    }

    return colors
}

/// Creates a macOS .clr file from the given color data.
func createCLR(from colors: [(name: String, red: CGFloat, green: CGFloat, blue: CGFloat)], saveTo path: String) throws {
    let colorList = NSColorList(name: URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent)

    for color in colors {
        let nsColor = NSColor(calibratedRed: color.red, green: color.green, blue: color.blue, alpha: 1.0)
        colorList.setColor(nsColor, forKey: NSColor.Name(color.name))
    }

    do {
        try colorList.write(to: URL(fileURLWithPath: path))
    } catch {
        throw GPLConversionError.fileWritingError
    }
}

/// Installs a .clr file to ~/Library/Colors.
func installPaletteToLibrary(at path: String, verbose: Bool) throws {
    let libraryPath = "\(NSHomeDirectory())/Library/Colors"
    let fileManager = FileManager.default

    if !fileManager.fileExists(atPath: libraryPath) {
        log("Creating ~/Library/Colors directory", verbose: verbose)
        try fileManager.createDirectory(atPath: libraryPath, withIntermediateDirectories: true, attributes: nil)
    }

    let fileName = URL(fileURLWithPath: path).lastPathComponent
    let destinationPath = "\(libraryPath)/\(fileName)"
    try fileManager.copyItem(atPath: path, toPath: destinationPath)
    log("Installed palette to \(destinationPath)", verbose: verbose)
}

/// Main function to parse a .gpl file and generate a .clr file.
func convertGPLToCLR(gplPath: String, clrPath: String?, install: Bool, verbose: Bool, dryRun: Bool) {
    do {
        log("Parsing GPL file: \(gplPath)", verbose: verbose)
        let colors = try parseGPL(fileAtPath: gplPath)

        log("Parsed colors:", verbose: verbose)
        for (name, red, green, blue) in colors {
            log("- \(name): R\(Int(red * 255)), G\(Int(green * 255)), B\(Int(blue * 255))", verbose: verbose)
        }

        if dryRun {
            print("Dry run: Conversion completed without creating files.")
            return
        }

        let outputPath: String
        if let clrPath = clrPath {
            outputPath = try validateOutputPath(clrPath)
        } else {
            let gplURL = URL(fileURLWithPath: gplPath)
            outputPath = try validateOutputPath(gplURL.deletingPathExtension().appendingPathExtension("clr").path)
        }

        log("Creating CLR file: \(outputPath)", verbose: verbose)
        try createCLR(from: colors, saveTo: outputPath)

        if install {
            log("Installing palette to ~/Library/Colors", verbose: verbose)
            try installPaletteToLibrary(at: outputPath, verbose: verbose)
        }

    } catch GPLConversionError.invalidFile {
        print("Error: Invalid GPL file or unable to read file.")
    } catch GPLConversionError.invalidFormat(let reason) {
        print("Error: Invalid GPL file format. Reason: \(reason)")
    } catch GPLConversionError.parsingError(let line) {
        print("Error: Unable to parse color data from the GPL file. Invalid line: \(line)")
    } catch GPLConversionError.fileCreationError {
        print("Error: Unable to create the CLR file. Check output directory permissions.")
    } catch GPLConversionError.fileWritingError {
        print("Error: Unable to write to the CLR file.")
    } catch {
        print("An unexpected error occurred: \(error)")
    }
}

// MARK: - CLI Interface

struct Arguments {
    let gplPath: String?
    let clrPath: String?
    let install: Bool
    let verbose: Bool
    let dryRun: Bool
}

enum ArgumentError: Error {
    case missingGPLPath
    case unrecognizedOption(option: String)
}

func parseArguments() throws -> Arguments {
    let validOptions = ["--install", "--verbose", "--dry-run", "--help"]
    let arguments = CommandLine.arguments
    if arguments.contains("--help") {
        printHelp()
        exit(0)
    }

    var gplPath: String? = nil
    var clrPath: String? = nil
    var install = false
    var verbose = false
    var dryRun = false

    for arg in arguments.dropFirst() {
        if validOptions.contains(arg) {
            switch arg {
            case "--install":
                install = true
            case "--verbose":
                verbose = true
            case "--dry-run":
                dryRun = true
            default:
                continue
            }
        } else if arg.starts(with: "--") {
            throw ArgumentError.unrecognizedOption(option: arg)
        } else if gplPath == nil {
            gplPath = arg
        } else if clrPath == nil {
            clrPath = arg
        } else {
            throw ArgumentError.unrecognizedOption(option: arg)
        }
    }

    return Arguments(gplPath: gplPath, clrPath: clrPath, install: install, verbose: verbose, dryRun: dryRun)
}

func printHelp() {
    print("""
    Usage:
        gpl2clr <gpl-file-path> [<clr-file-path>] [--install] [--verbose] [--dry-run]

    Options:
        <gpl-file-path>  Path to the input GPL file (required).
        <clr-file-path>  Optional path to save the .clr file. Defaults to input path with .clr suffix.
        --install        Install .clr file to ~/Library/Colors
        --verbose        Enable verbose activity output
        --dry-run        Simulate the process without creating or installing files.
        --help           Display this help message.
    """)
}

do {
    let args = try parseArguments()
    guard let gplPath = args.gplPath else {
        printHelp()
        exit(1)
    }
    convertGPLToCLR(gplPath: gplPath, clrPath: args.clrPath, install: args.install, verbose: args.verbose, dryRun: args.dryRun)
} catch ArgumentError.missingGPLPath {
    print("Error: Missing GPL file path.")
    printHelp()
} catch ArgumentError.unrecognizedOption(let option) {
    print("Error: Unrecognized option '\(option)'.")
    printHelp()
} catch {
    print("An unexpected error occurred: \(error)")
}

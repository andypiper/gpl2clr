# GPL to CLR Converter

A Swift command-line tool to convert GIMP `.gpl` palette files to macOS `.clr` color palette files.

Includes an option to install the generated `.clr` file to the macOS `~/Library/Colors` directory so that they show up in the user's colour picker (in the drop-down list on the Colour Palettes tab).

## Background

I wanted to be able to use a set of brand colours in my macOS apps. I had the colour information in hex format, and this was simple to put into a Gimp palette file which is a plain text format. Apple macOS colour palette files are binary; the Python options I found for manipulating them didn't work as I wanted, so I whipped this up using Swift.

It does the job; I later discovered [another existing tool](https://github.com/tachoknight/GIMP-Palette-to-Apple-Color-Picker) to do something similar. YMMV.

## Features

- Parse GIMP `.gpl` palette files.
- Generate `.clr` color palette files for macOS.
- Install palettes to `~/Library/Colors`.
- Optional **dry-run** mode for testing without creating files.

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/andypiepr/gpl2clr.git
   cd gpl2clr
   ```

2. Compile using Swift:

    ```bash
    swiftc GeneratePalette.swift -o gpl2clr
    ```

3. Move the executable to a directory in your `PATH` for easy use:

    ```bash
    mv gpl2clr /usr/local/bin
    ```

The tool can also be run directly without being compiled:

`swiftc GeneratePalette.swift [options]`

## Usage

### Syntax

```bash
gpl2clr <gpl-file-path> [<clr-file-path>] [--install] [--verbose] [--dry-run]
```

### Options

- `<gpl-file-path>`: Path to the input `.gpl` file (required).
- `<clr-file-path>`: Optional path to save the `.clr` file. Defaults to input path with `.clr` suffix.
- `--install`: Installs the `.clr` file to `~/Library/Colors`.
- `--dry-run`: Checks the conversion process without creating or installing files.
- `--verbose`: Outputs detailed parsing logs.
- `--help`: Displays the help message.

### Examples

#### Convert a `.gpl` file to a `.clr` file

```bash
gpl2clr GNOME_HIG.gpl GNOME.clr
```

#### Convert and install the palette

```bash
gpl2clr GNOME_HIG.gpl --install
```

#### Test the process without creating files

```bash
gpl2clr GNOME_HIG.gpl --dry-run
```

#### Enable verbose logging

```bash
gpl2clr GNOME_HIG.gpl GNOME_HIG.clr --verbose
```

## Contributing

Contributions are welcome! Feel free to open an issue or submit a pull request.

## LICENSE

This project is licensed under the MIT License.

"""Data format converter.

data_converter
==============

A command-line utility for converting data between XML, JSON, and YAML formats.
Supports bidirectional conversion between these common data serialization formats
using standard libraries and xmltodict for XML handling.

Key features
------------
- Supports conversion between XML, JSON, and YAML formats
- Command-line interface with flexible mode specification
- Automatic error handling for invalid input formats
- Output to file or stdout
- Type-safe implementation with comprehensive error reporting

Parameters
----------
input_file : str
    Path to the input file containing data in the source format
mode : str
    Conversion mode in the format 'from2to' (e.g., 'xml2json', 'json2yaml')
output_file : str, optional
    Path to the output file. If not provided, output is written to stdout

Return value
------------
On success, writes the converted data to the specified output location.
The returned data maintains the structure and content of the original,
converted to the target format with appropriate formatting.

Examples
--------
Convert XML to JSON::

    python data_converter.py input.xml xml2json output.json

Convert JSON to YAML and output to stdout::

    python data_converter.py data.json json2yaml

Notes
-----
- XML conversion uses xmltodict for dictionary-based parsing
- JSON output is formatted with 2-space indentation
- YAML output uses default block style formatting
- Input files must be valid in their respective formats

Raises
------
FileNotFoundError
    When the input file does not exist
ValueError
    When the mode format is invalid or unsupported formats are specified
json.JSONDecodeError
    When JSON input is malformed
yaml.YAMLError
    When YAML input is malformed
xmltodict.expat.ExpatError
    When XML input is malformed
"""

import argparse
import json
import signal
import sys
import traceback
from collections import OrderedDict
from pathlib import Path
from typing import Any

try:
    # Try to import non-standard libraries, send a list of libraries if any aren't
    # installed.
    import xmltodict
    import yaml

except ImportError as import_err:
    # Update with the necessary libraries
    mod_list = ["xmltodict", "pyyaml"]
    print("\n\nAn error occurred while trying to import the required modules.\n")
    print("The following error was raised:\n")

    print(import_err)
    print(
        "Please ensure the following modules are imported to the environment you are "
        "running python from before trying to run the program again.\n"
    )
    print("Non-Standard Module List: ")
    for mod in mod_list:
        print(mod)
    sys.exit()

MODE_SEPARATOR = "2"
EXPECTED_PARTS = 2


def clean_data_for_yaml(data: Any) -> Any:
    """Recursively clean data for YAML output by converting OrderedDict to dict and cleaning strings.

    :param data: The data to clean

    :returns: Cleaned data suitable for YAML serialization
    """
    if isinstance(data, (OrderedDict, dict)):
        return {key: clean_data_for_yaml(value) for key, value in data.items()}
    if isinstance(data, list):
        return [clean_data_for_yaml(item) for item in data]
    if isinstance(data, str):
        # Strip trailing newlines and normalize whitespace in multiline strings
        lines = data.rstrip("\n").split("\n")
        cleaned_lines = [line.rstrip() for line in lines]
        return "\n".join(cleaned_lines).rstrip()
    return data


def parse_mode(mode: str) -> tuple[str, str]:
    """Parse the conversion mode string into source and target formats.

    :param mode: Conversion mode in format 'from2to' (e.g., 'xml2json')

    :returns: Tuple of (source_format, target_format)

    :raises ValueError:
        When mode format is invalid or unsupported formats are specified
    """
    if MODE_SEPARATOR not in mode:
        msg = (
            f"Invalid mode format: {mode}. Expected format: 'from2to' (e.g., 'xml2json')"
        )
        raise ValueError(msg)

    parts = mode.split(MODE_SEPARATOR)
    if len(parts) != EXPECTED_PARTS:
        msg = f"Invalid mode format: {mode}. Expected exactly one '{MODE_SEPARATOR}' separator"
        raise ValueError(msg)

    from_fmt, to_fmt = parts
    supported_formats = ["xml", "json", "yaml"]

    if from_fmt not in supported_formats:
        msg = f"Unsupported source format: {from_fmt}. Supported: {', '.join(supported_formats)}"
        raise ValueError(msg)

    if to_fmt not in supported_formats:
        msg = f"Unsupported target format: {to_fmt}. Supported: {', '.join(supported_formats)}"
        raise ValueError(msg)

    if from_fmt == to_fmt:
        msg = f"Source and target formats are the same: {from_fmt}"
        raise ValueError(msg)

    return from_fmt, to_fmt


def read_input_file(input_file: str) -> str:
    """Read the content of the input file.

    :param input_file: Path to the input file

    :returns: Content of the file as a string

    :raises FileNotFoundError:
        When the input file does not exist
    """
    input_path = Path(input_file)
    if not input_path.is_file():
        msg = f"Input file not found: {input_file}"
        raise FileNotFoundError(msg)

    with input_path.open(encoding="utf-8") as f:
        return f.read()


def load_data(content: str, from_fmt: str) -> Any:
    """Load data from string content based on the source format.

    :param content: String content of the input data
    :param from_fmt: Source format ('xml', 'json', or 'yaml')

    :returns: Parsed data which may be a dict, list, or primitive depending on the input

    :raises ValueError:
        When source format is unexpected
    :raises json.JSONDecodeError:
        When JSON input is malformed
    :raises yaml.YAMLError:
        When YAML input is malformed
    :raises xmltodict.expat.ExpatError:
        When XML input is malformed
    """
    if from_fmt == "xml":
        return xmltodict.parse(content)
    if from_fmt == "json":
        return json.loads(content)
    if from_fmt == "yaml":
        try:
            return yaml.safe_load(content)
        except yaml.YAMLError:
            # Fallback to unsafe loader for YAML with Python objects
            return yaml.load(content, Loader=yaml.Loader)

    msg = f"Unexpected source format: {from_fmt}"
    raise ValueError(msg)


def convert_data(data: Any, to_fmt: str) -> str:
    """Convert parsed data to the target format string.

    :param data: Parsed data (dict, list, or primitive) to convert
    :param to_fmt: Target format ('xml', 'json', or 'yaml')

    :returns: Converted data as a string

    :raises ValueError:
        When target format is unexpected
    """
    if to_fmt == "xml":
        # xmltodict.unparse may be typed as returning Any by some type stubs,
        # so explicitly ensure we return a str for the declared return type.
        return str(xmltodict.unparse(data))
    if to_fmt == "json":
        return json.dumps(data, indent=2)
    if to_fmt == "yaml":
        # Convert OrderedDict to dict and clean strings for clean YAML output
        clean_data = clean_data_for_yaml(data)
        return yaml.dump(clean_data)

    msg = f"Unexpected target format: {to_fmt}"
    raise ValueError(msg)


def write_output(output: str, output_file: str | None) -> None:
    """Write the output to file or stdout.

    :param output: Output string to write
    :param output_file: Path to output file, or None for stdout

    :returns: None
    """
    if output_file:
        output_path = Path(output_file)
        with output_path.open("w", encoding="utf-8") as f:
            f.write(output)
        print(f"Conversion complete. Output written to {output_file}")
    else:
        print(output)


def sub_main(args: argparse.Namespace) -> None:
    """Convert data between XML, JSON, and YAML formats.

    :param args: Parsed command-line arguments containing input_file, mode, and output_file

    :returns: None
        This function does not return a value; it writes output to file or stdout.

    :raises ValueError:
        When mode format is invalid or unsupported conversion formats are specified
    :raises FileNotFoundError:
        When input file does not exist
    :raises json.JSONDecodeError:
        When JSON input is malformed
    :raises yaml.YAMLError:
        When YAML input is malformed
    :raises xmltodict.expat.ExpatError:
        When XML input is malformed
    """
    input_file: str = args.input_file
    mode: str = args.mode
    output_file: str | None = args.output_file

    from_fmt, to_fmt = parse_mode(mode)
    content = read_input_file(input_file)
    data = load_data(content, from_fmt)
    output = convert_data(data, to_fmt)
    write_output(output, output_file)


def main() -> None:
    """Main entry point for the data converter program."""
    # Restore default signal handler for SIGINT (Ctrl-C)
    signal.signal(signal.SIGINT, signal.SIG_DFL)  # KeyboardInterrupt: Ctrl-C

    # Create CLI arguments and descriptions
    parser = argparse.ArgumentParser(
        description="Convert data between XML, JSON, and YAML formats"
    )
    parser.add_argument("input_file", help="Path to the input file to convert")
    parser.add_argument(
        "mode",
        help="Conversion mode in format 'from2to' (e.g., xml2json, json2yaml, yaml2xml)",
    )
    parser.add_argument(
        "output_file",
        nargs="?",
        help="Path to the output file (optional, defaults to stdout)",
    )

    args = parser.parse_args()

    try:
        sub_main(args)
    except KeyboardInterrupt:
        print("\nKeyboardInterrupt: Program interrupted by user. Exiting gracefully.")
        sys.exit(0)
    except Exception as e:
        exit_with_error(e, traceback)


def exit_with_error(e: Exception, tb_module: Any) -> None:
    """Handles exceptions by printing error details and exiting the program.

    :param e: The exception instance raised by the program
    :param tb_module: The traceback module used to extract error information

    :returns: None
        This function does not return a value; it terminates the program.

    :effects:
        Prints error details, including exception type, message, notes, and line number.
        Exits the program with status code 1.
    """
    print("Error raised by sub function:")
    tbinfo = tb_module.extract_tb(sys.exc_info()[2])
    errclass = e.__class__.__name__
    errmessage = str(e) if str(e) else "no message"
    errnotes = e.__notes__ if hasattr(e, "__notes__") else []
    errlineno = tbinfo[-1].lineno if tbinfo else "unknown"
    print(f'{errclass}: "{errmessage}" at line {errlineno}')

    if errnotes:
        print("Notes:")
        for note in errnotes:
            print(f" - {note}")
    print("Terminating program.")
    sys.exit(1)


if __name__ == "__main__":
    main()

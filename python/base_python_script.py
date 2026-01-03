import argparse
import os
import re
import shutil
import signal
import sys
import traceback
import types
import yaml

try:
    # Try to import non-standard libraries, send a list of libraries if any aren't
    # installed.
    # Change the following line(s) to import the necessary non-standard libraries for
    # this project
    import pynautobot

except ImportError as import_err:
    # Update with the necessary libraries
    mod_list = ["pynautobot"]
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


def sub_main(args: argparse.Namespace) -> None:
    """Insert Docstring"""
    print(f"The arguments passed into the program are {args}\n")

    try:
        print("Insert main program logic here")
    except Exception as e:
        raise e  # Re-raise the exception to be caught by the main function
    print("The program has successfully completed.\n")


def main() -> None:
    """PLaceholder"""
    # Restore default signal handler for SIGINT (Ctrl-C)
    signal.signal(signal.SIGINT, signal.SIG_DFL)  # KeyboardInterrupt: Ctrl-C

    # Create CLI arguments and descriptions
    parser = argparse.ArgumentParser(description="{Program Description}")
    parser.add_argument("{argument_name}", help="{argument_help}")

    args = parser.parse_args()

    try:
        sub_main(args)
    except KeyboardInterrupt:
        print("\nKeyboardInterrupt: Program interrupted by user. Exiting gracefully.")
        sys.exit(0)
    except Exception as e:
        exit_with_error(e, traceback)


def exit_with_error(e: Exception, tb_module: types.ModuleType) -> None:
    """Handles exceptions by printing error details and exiting the program.

    :param e:
        The exception instance raised by the program.
    :param tb_module:
        The traceback module used to extract error information.

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

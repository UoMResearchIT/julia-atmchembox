########################################################################################
# This is the main file for the project. It is the entry point for the application.
# It is responsible for setting up the application and run the main logic.
# Use the using keyword to import the exported functions from the module parse_equation.
########################################################################################

# import command line argument parsing library
using ArgParse

# using the export function inside /src/parse_equation.jl
include("parse_equation.jl")
using .parse_equation

function parse_commandline()
    # Define the command line arguments
    settings = ArgParseSettings()
    @add_arg_table settings begin
        "--eqt_file"
        help="Path to the eqt file"
        required=true
        arg_type=String
    end
    return parse_args(settings)
end

function main()
    parsed_args = parse_commandline()
    println("eqt_file: ", parsed_args["eqt_file"])

    extract_mechanism(parsed_args["eqt_file"])
end
# Call exported function: extract_mechanism from parse_equation module
#extract_mechanism("/eqt_file/MCM_BCARY.eqn.txt")

main()



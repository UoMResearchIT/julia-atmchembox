########################################################################################
# This is the main file for the project. It is the entry point for the application.
# It is responsible for setting up the application and run the main logic.
# Use the using keyword to import the exported functions from the module parse_equation.
########################################################################################

# using the export function inside /src/parse_equation.jl
include("parse_equation.jl")
using .parse_equation

# Call exported function: extract_mechanism from parse_equation module
extract_mechanism("/eqt_file/MCM_BCARY.eqn.txt")




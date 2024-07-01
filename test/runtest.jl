# SPDX-FileCopyrightText: 2024 University of Manchester
#
# SPDX-License-Identifier: agpl-3.0-only

####################################
# The main program to run all the test cases
####################################
using Test
include("../src/parse_equation.jl")
using .parse_equation

@testset "All Tests" begin
    include("test_extract_mechanism.jl")
end
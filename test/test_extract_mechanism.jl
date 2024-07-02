# SPDX-FileCopyrightText: 2024 University of Manchester
#
# SPDX-License-Identifier: agpl-3.0-only

################################
# create a test for the extract_mechanism function
################################
@testset "Test extract_mechanism" begin
    @testset "Test extract_mechanism with valid input" begin
        @test extract_mechanism("../eqt_file/MCM_BCARY.eqn.txt") == 1601
    end
end
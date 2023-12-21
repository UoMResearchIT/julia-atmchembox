#########################################################################################
# Read the mechanism equation file (located at eqt_file folder and
# extracts reactants, products and a definition of the rate coefficient for each reaction
#
# Step:
# Read the equation file line by line (it prevent loads the entire file into memory and suitable for large files)
# Input:
# filename: name of mechanism file
# Output:
##########################################################################################
function extract_mechanism(filename::String)
    println("Opening file $filename.txt for parsing")
    
    full_file_path = joinpath(@__DIR__, "../eqt_file/$filename.txt") #find the full file path contain the equation file

    max_equations = 0 # Use to store max number of equation
    
    io_buffer = IOBuffer(append=true)

    rate_dict = Dict{Integer, String}()
    
    ###############################################################################
    # Use open() function is more idiomatic and helps manage resources effectively.
    # It ensures that the file is closed automatically as well
    ###############################################################################
    open(full_file_path, "r") do f
        for line in eachline(f)
            current_equation_index = match(r"(\d+)", line).captures[1] # find the first match with the digit pattern, i.e. the equation number between { and .}, return as String
            max_equations = max(max_equations, parse(Int, current_equation_index)) # convert currentEquationIndex to Integer and fnd out the maxium one then it to the variable: maxNumberOfEquation 
            
            #########################################################################################################
            # Extract 
            #   - Reactants and stochiometric coefficients
            #   - Products and stochiometric coefficients
            #   - Rate coefficients:
            #       = Coefficients and typical forms used in MCM models
            #  This information is stored in dictionaries 
            #  
            # Since equations can span multiple lines according to KPP files,
            # we cannot just parse line by line
            # Therefore, in here, although we read line by line, we will concrate it to the text buffer. 
            # We will keep checking the text buffer with KPP equation pattern 
            # Once we can find a match inside the text buffer,
            # we can do the parse. 
            # When the parse process is done, the text buffer will be clear anbd keep reading the next line           
            #############################################################################################################
            
            #KPPEquationPattern = r"\{\d+\.\}\s*[\w\d\s\+\-\*\/\(\)\=\:\.]+"
            KPPEquationPattern = r"\{\d+\.\}\s*[\w\W^;]+;$"  # pattern: {Any number .} space [/Any char/Any non char/ but not ;] end with ;
            write(io_buffer, line)
            
            #match_result = match(KPPEquationPattern, String(take!(io_buffer)))        
            match_result = match(KPPEquationPattern, read(seekstart(io_buffer), String))     
            
            if match_result !== nothing
                equation_full = replace(match_result.match, "\t"=> "", ";"=>"")
                equation = split(split(equation_full, ":", limit=2)[1], "=", limit=2) # split the line into reactants and products
                
                reactants = split(equation[1], "+") # extract content to the left of the previous split [reactants]
                reactants = [strip(x) for x in reactants] # strip away all whitespace
                
                products = split(equation[2], "+")
                products = [strip(x) for x in products]

                #println("The equation is : $products")
                #At the moment, we have not seperated the reactant/product from its stochiometric value
                rate_full = split(equation_full, ":", limit=2)[2]
                rate_full = strip(rate_full)
                
                rate_dict[parse(Int, current_equation_index)] = rate_full
                println(current_equation_index, " is ", rate_dict[parse(Int, current_equation_index)])
                
                
                # Clear IOBuffer
                take!(io_buffer)
            end
        end
    end
    
    
    println("Calculating total number of equations = $max_equations")
end



extract_mechanism("MCM_BCARY.eqn")
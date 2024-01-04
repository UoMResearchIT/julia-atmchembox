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
            # When the parse process is done, the text buffer will be clear and keep reading the next line           
            #############################################################################################################
            
            #KPPEquationPattern = r"\{\d+\.\}\s*[\w\d\s\+\-\*\/\(\)\=\:\.]+"
            #KPPEquationPattern = r"\{\d+\.\}\s*([\w\W^;]+);$"
            KPPEquationPattern = r"\{\d+\.\}\s*(.+?)\s*;"  
            # pattern explain: 
            #   \{\d+\.\} - match the literal {} with any digit inside. 
            #   \s* - Matches zero or more whitespace characters. 
            #   (.+?) - Captures one or more characters (non-greedy) and stores them in a capture group. 
            #   ; - Matches the semicolon at the end of the pattern.
            
            write(io_buffer, line)
            
            match_result = match(KPPEquationPattern, read(seekstart(io_buffer), String))     
            
            if match_result !== nothing
                equation_full = replace(match_result.captures[1], "\t"=> "", ";"=>"")
                #println(match_result.captures[1])
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
                #println(current_equation_index, " is ", rate_dict[parse(Int, current_equation_index)])
                #This assumes everyline, as in KPP, finishes with a ';' character

                #println("Full equation extracted")
                #println(equation_full)
                #println("Rate extracted :")
                #println(rate_full)
                
                # Now cycle through all reactants and products, splitting the unique specie from its stochiometry
                # This information is then stored in dictionaries for use in the ODE solver
                
                # At the moment the reactants, and products, include joint stoichiometric information. 
                # This means we need to identify these numbers and then split the string again to ensure
                # the specie always remains unique. Thus, we may have saved something like
                # '2.0NO2' or '5ISOPOOH'. The use of integer versus float can vary so have to assume no care taken
                # in being consistent 

                reactant_step=0 #used to identify reactants by number, for any given reaction
                product_step=0
                
                for reactant in reactants
                    reactant = replace(reactant, r"\s+" => "") #remove all tables, newlines, whitespace
                    
                    try
                        temp = collect(m.match for m in eachmatch(r"[-+]?\d*\.\d+|\d+|\d+", reactant)) #This extracts all numbers either side of some text.
                        #println(temp[1])
                        
                        stoich = temp[1]  #This selects the first number extracted, if any. *Julia start with index 1

                        # Now need to work out if this value is before the variable
                        # If after, we ignore this. EG. If '2' it could come from '2NO2' or just 'NO2'
                        # If len(temp)==1 then we only have one number and can proceed with the following/
                        if length(temp) == 1
                            if startswith(reactant, stoich)
                                #eg: 2NO
                                reactant = split(reactant, stoich, limit=2)[2]
                                stoich = float(stoich)
                            else
                                stoich = 1.0
                            end
                        elseif length(temp) > 1
                            #If this is the case, we need to ensure the reactant extraction is unique. For example
                            #If the string is '2NO2' the above procedure extracts 'NO' as the unique reactant. 
                            #We therefore need to ensure that the reactant is 'NO2'. To do this we cut the value
                            #in temp[0] away from the original string. Lets assume that we can attach the first
                            #part of the text with the second number in temp. Thus
                            reactant = split(reactant, stoich, limit=2)[2] + temp[2]
                            println("testing: $reactant")
                        else
                            println("empty temp")
                        end

                        #println("{reactant} the length is {len(temp)}" )

                    catch
                        println("not match $reactant")
                    end
                end
                
                
                # Clear IOBuffer 
                take!(io_buffer)
            end
        end
    end
    
    
    println("Calculating total number of equations = $max_equations")
    


end



extract_mechanism("MCM_BCARY.eqn")
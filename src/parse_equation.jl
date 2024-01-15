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
    loss_dict = Dict{String, Dict{Integer, Float64}}()
    gain_dict = Dict{String, Dict{Integer, Float64}}()
    stoich_dict = Dict{Integer, Dict{Integer, Integer}}()
    rate_dict_reactants = Dict{Integer, Dict{Integer, String}}()
    species_dict = Dict{Integer, String}()
    species_dict2array = Dict{String, Integer}()
    species_hess_data = Dict{Any, Any}()
    species_hess_loss_data = Dict{String, Vector{Any}}()
    species_hess_gain_data = Dict{String, Vector{Any}}()
    
    #Create an integer that stores number of unque species
    species_step = 0

    println("Parsing each equation")

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
                
                equation_step = parse(Int, current_equation_index)
                
                rate_dict[equation_step] = rate_full
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

                reactant_step = 0 #used to identify reactants by number, for any given reaction
                product_step = 0
                
                stoich = 0

                #Create the default inner dictionaries
                #stoich_dict[equation_step] = inner_dict()
                #rate_dict_reactants[equation_step] = inner_dict()

                stoich_dict[equation_step] = Dict{Integer, Integer}()
                rate_dict_reactants[equation_step] = Dict{Integer, String}()

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
                                stoich = parse(Float64, stoich)
                            else
                                stoich = 1.0
                            end
                        elseif length(temp) > 1
                            #If this is the case, we need to ensure the reactant extraction is unique. For example
                            #If the string is '2NO2' the above procedure extracts 'NO' as the unique reactant. 
                            #We therefore need to ensure that the reactant is 'NO2'. To do this we cut the value
                            #in temp[0] away from the original string. Lets assume that we can attach the first
                            #part of the text with the second number in temp. Thus
                            if startswith(reactant, stoich)
                                reactant = split(reactant, stoich, limit=2)[2] * temp[2] # concrate
                                stoich = parse(Float64, stoich)
                            else
                                stoich = 1.0 
                            end
                        else
                            # should not go into this case
                        end

                        #println("{reactant} the length is {len(temp)}" )

                    catch ex
                        #println("$reactant This is $ex")
                        stoich = 1.0
                    end

                    #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                    # - Store stoichiometry, species flags and hessian info in dictionaries
                    #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                    
                    #Now store the stoichiometry and reactant in dictionaries
                    if !(reactant in ["hv"])
                        stoich_dict[equation_step][reactant_step] = stoich
                        rate_dict_reactants[equation_step][reactant_step] = reactant 
                        
                        #print(stoich_dict)
                        
                        # -- Update species dictionaries --
                        if !(reactant in values(species_dict)) #check to see if entry already exists
                            species_dict[species_step] = reactant # useful for checking all parsed species    
                            species_dict2array[reactant] = species_step #useful for converting a dict to array
                            species_step+=1
                            
                            #print(species_dict)
                        end

                        # -- Update hessian dictionaries --
                        if !(reactant in values(species_hess_loss_data))
                            species_hess_loss_data[reactant] = []
                        end
                        
                        push!(species_hess_loss_data[reactant], equation_step) #so from this we can work out a dx/dy
                        
                        # -- Update loss dictionaries --
                        # if haskey(loss_dict, reactant)
                        #     if haskey(loss_dict[reactant], equation_step)
                        #         # If it exists, increment the value
                        #         loss_dict[reactant][equation_step] += stoich       
                        #     else
                        #         # If it doesn't exist, create a new entry
                        #         loss_dict[reactant][equation_step] = stoich
                        #     end
                        # else
                        #     # If the outer dictionary doesn't have an entry for the name, create one
                        #     loss_dict[reactant] = Dict{Int, Float64}()
                        #     loss_dict[reactant][equation_step] = stoich
                        # end
                        
                        # -- Update loss dictionaries --
                        loss_dict[reactant][equation_step]  = get!(get!(loss_dict, reactant, Dict{Int, Float64}()), equation_step, 0.0) + stoich 
                    end
                    
                    reactant_step += 1
                end
                
                #reset the 
                stoich = 0

                if length(products) > 0
                    for product in products #This are the 'reactants' in this equation
                        try
                            product = replace(product, r"\s+" => "") #remove all tables, newlines, whitespace

                            #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
		                    # - Extract stochiometry and unique product identifier
		                    #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                            try
                                temp = collect(m.match for m in eachmatch(r"[-+]?\d*\.\d+|\d+|\d+", product)) #This extracts all numbers either side of some text. 
                                stoich = temp[0] #This selects the first number extracted, if any.

                                # Now need to work out if this value is before the variable
                                # If after, we ignore this. EG. If '2' it could come from '2NO2' or just 'NO2'
                                # If len(temp)==1 then we only have one number and can proceed with the following
                                if length(temp) == 1
                                    if startswith(product, stoich)
                                        product = split(product, stoich, limit=2)[2]
                                        stoich = parse(Float64, stoich)
                                    else
                                        stoich = 1.0
                                    end
                                elseif length(temp) > 1
                                    #If this is the case, we need to ensure the reactant extraction is unique. For example
                                    #If the string is '2NO2' the above procedure extracts 'NO' as the unique reactant. 
                                    #We therefore need to ensure that the reactant is 'NO2'. To do this we cut the value
                                    #in temp[0] away from the original string. Lets assume that we can attach the first
                                    #part of the text with the second number in temp. Thus
                                    if startswith(product, stoich)
                                        product = split(product, stoich, limit=2)[2] * temp[2]
                                        stoich = parse(Float64, stoich)
                                    else
                                        stoich = 1.0                                
                                    end
                                else
                                    #should not go into this case
                                end
                            catch ex
                                stoich = 1.0
                            end
                            #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                            # - Store stoichiometry, species flags and hessian info in dictionaries
                            #++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
                            #Now store the stoichiometry and reactant in dictionaries
                            if !(product in ["hv"])
                                # -- Update species dictionaries --
                                if !(product in values(species_dict)) #check to see if entry already exists
                                    species_dict[species_step]=product # useful for checking all parsed species
                                    species_dict2array[product]=species_step #useful for converting a dict to array
                                    species_step+=1
                                end

                                # -- Update hessian dictionaries --
                                if !(product in values(species_hess_gain_data))
                                    species_hess_gain_data[product]=[]
                                end

                                push!(species_hess_gain_data[product], equation_step) #so from this we can work out a dx/dy

                                # -- Update loss dictionaries --
                                gain_dict[product][equation_step] = get!(get!(gain_dict, product, Dict{Int, Float64}()), equation_step, 0.0) + stoich
                                
                            end
                            product_step+=1
                        catch ex
                        end
                    end    
                end
                
                # Clear IOBuffer 
                take!(io_buffer)
            end
        end
    end
    
    #print(rate_dict)
    #print(stoich_dict)
    #print(rate_dict_reactants)
    println("Calculating total number of equations = $max_equations")
    


end

# Define a function to create the default inner dictionary
function inner_dict()
    return Dict{Any, Any}()
end


extract_mechanism("MCM_BCARY.eqn")

#test
# testvalue = "hello"
# myvalue = Dict{Any, Any}()
# myvalue[1] = "hello"
# if testvalue in values(myvalue)
#     print("it can")
# end
# loss_dict[reactant][equation_step]  = get!(get!(loss_dict, reactant, Dict{Int, Float64}()), equation_step, 0.0) + stoich 

# test_dict = Dict{Any, Dict{Any, Any}}()
# key = "a"
# step = 1
# value = 1.2
# test_dict[key][step] = get!(get!(test_dict, key, Dict{Int, Float64}()), step, 0.0) + value 
# println(test_dict)

# value = 0.8
# test_dict[key][step] = get!(get!(test_dict, key, Dict{Int, Float64}()), step, 0.0) + value 
# println(test_dict)
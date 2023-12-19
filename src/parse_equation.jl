#########################################################################################
# Read the mechanism equation file (located at eqt_file folder and
# extracts reactants, products and a definition of the rate coefficient for each reaction
#
# Step:
# Read the equation file line by line (it prevent loads the entire file into memory and suitable for large files)
# Input:
# filename: name of mechanism file
# Output:
#
function parse_eqt(fileName::String)
    println("Opening file $fileName.txt for parsing")
    fullFilePath = joinpath(@__DIR__, "../eqt_file/$fileName.txt") #find the full file path contain the equation file

    maxNumberOfEquation = 0 #Use to store max number of equation

    textFileBuffer = ""

    

    for line in eachline(fullFilePath)
        currentEquationIndex = match(r"(\d+)", line).captures[1] #find the first match with the digit pattern, i.e. the equation number between { and .}, return as String
        maxNumberOfEquation = max(maxNumberOfEquation, parse(Int, currentEquationIndex)) # convert currentEquationIndex to Integer and fnd out the maxium one then it to the variable: maxNumberOfEquation 
        
        # Extract 
        #   - Reactants and stochiometric coefficients
        #   - Products and stochiometric coefficients
        #   - Rate coefficients:
        #       = Coefficients and typical forms used in MCM models
        #  This information is stored in dictionaries 
        
        
        #println("strip result:", eval(strip(line)[1:end-1]))
        process_full_eqt(textFileBuffer, line)
    end
    
    println("Calculating total number of equations = $maxNumberOfEquation")
end

function process_full_eqt(textFileBuffer::String, line::String)
    fullEquationPattern = r"\{(\d+)\.\}[.]*;"
    textFileBuffer*=line
    println("This is the full text: $textFileBuffer")
end

parse_eqt("MCM_APINENE.eqn")
# julia-atmchembox
Atmospheric Chemistry Box Model, written in Julia

## Main entry point 
The main entry point of Julia-atmchembox is located in 'main.jl'. You can find this file under '/src/main.jl'. 

To run this program, navigate to the root directory of this project and execute:

```
julia --project=Project.toml src\main.jl
```
## Test Cases
All test cases are located under the 'test' folder. You can create any test file as needed. One straightforward method to conduct testing is by creating a test file for the target module or function, writing desired test case, and grouping them into a testset. Subsequently register the test in runtest.jl. 
To execute all tests at once, navigate to the 'test' directory and execute:

```
julia --project=Project.toml runtest.jl
```
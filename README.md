# ForestFire

A simple simulation of fire spreading through trees. **You need a GPU** to make it run.

Julia is a great tool for scientific programming. I wanted to experiment with [CUDA.jl](https://github.com/JuliaGPU/CUDA.jl), [Makie.jl](https://github.com/JuliaPlots/Makie.jl) and although I did not use the library, this work is greatly inspired by [Agent.jl](https://github.com/JuliaDynamics/Agents.jl) and [George Datseries](https://github.com/Datseris) tutorials. 

![ForestFire.jl](https://github.com/fiwr/ForestFire/blob/main/images/forest_fire.gif?raw=true)

This is a grid based simulation. Each greed cell can be either **empty**, a **tree** or a **fire** cell. Those entities obey to different rules. A tree will colonize an adjacent empty cell with some probability. A fire cell will spread to an adjacent tree with some probability. An empty cell do nothing except being ready to be colonized. Trees may be seen has fire spreading through empty cells, with the only difference that fire has some probability to die-out.

Those probabilities can be ajusted with the sliders : **seedling**, **ignition** and **extinction**.

The parameters values and the proportion of trees and fires during sessions can be recorded as **.csv files**.

> "... and life as it could be." Christopher Langton


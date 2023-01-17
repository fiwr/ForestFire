module ForestFire

using CUDA
using ColorTypes: N0f8

mutable struct Forest{G,C}
    step::Int
    gridA::CuMatrix{G}
    gridB::CuMatrix{G}
    image::CuMatrix{C}
    colors::CuVector{C}
    function Forest(dims; G = Int, C = RGB{N0f8})
        gridA = CUDA.zeros(G, dims)
        gridB = CUDA.zeros(G, dims)
        image = CUDA.zeros(C, dims)
        colors = [C(ctx.entities[k].color) for k in sort(keys(ctx.entities) |> collect)]
        new{G,C}(0, gridA, gridB, image, colors)
    end
end

include("config.jl")
export ctx, EMPTY, TREE, FIRE

include("interface.jl")
export run_interface, forest

export Forest
export growtrees!, setfire!, colorimage!, step!

function growtrees!(forest::Forest; density = 0.5)
    L = Int(√1024)
    bx, by = cld.(size(forest.gridA), L)
    @cuda threads=(L, L) blocks=(bx, by) kernel_growtrees!(forest.gridA, density)
end

function kernel_growtrees!(grid, probability)
    x = threadIdx().x + (blockIdx().x - 1) * blockDim().x
    y = threadIdx().y + (blockIdx().y - 1) * blockDim().y
    xmax, ymax = size(grid)
    if 0 < x < xmax + 1 && 0 < y < ymax + 1
        grid[x, y] = rand() < probability ? TREE : 0
    end
    return
end

function setfire!(firecells::Array{CartesianIndex{2}}, forest::Forest)
    CUDA.@allowscalar forest.gridA[firecells] .= FIRE
    return
 end

function step!(forest::Forest; seedling_probability = 0.1, ignition_probability = 0.1, 
        extinction_probability = 0.1)
    L = Int(√1024)
    bx, by = cld.(size(forest.image), L) 
    CUDA.@sync @cuda threads=(L, L) blocks=(bx, by) kernel_step!(forest.gridA, forest.gridB,
    seedling_probability, ignition_probability, extinction_probability)
    
    # swap buffers
    gridA = forest.gridA
    forest.gridA = forest.gridB
    forest.gridB = gridA

    forest.step += 1
    return
end

function kernel_step!(gA, gB, seedling_probability, ignition_probability, 
        extinction_probability)
    x = threadIdx().x + (blockIdx().x - 1) * blockDim().x
    y = threadIdx().y + (blockIdx().y - 1) * blockDim().y
    xmax, ymax = size(gA)

    if (1 < x < xmax && 1 < y < ymax) # TEST with bundaries 

        nw = (x-1,y-1)
        n = (x-1,y) 
        ne = (x-1,y+1)
        w = (x,y-1)
        here = (x,y)
        e = (x,y+1)
        sw = (x+1,y-1)
        s = (x+1,y) 
        se = (x+1,y+1)

        entity = gA[here...]

        if entity == TREE 
            
            # surrounding fires
            fires_count = (gA[nw...] == FIRE) + (gA[n...] == FIRE) + (gA[ne...] == FIRE)
            fires_count += (gA[w...] == FIRE) + (gA[e...] == FIRE)
            fires_count += (gA[sw...] == FIRE) + (gA[s...] == FIRE) + (gA[se...] == FIRE)
            
            # each fire has the same probability to light this tree
            gB[here...] = rand() < 1 - (1 - ignition_probability)^fires_count ? FIRE : TREE
        
        elseif entity == FIRE
            
            # surrounding fires
            fires_count = (gA[nw...] == FIRE) + (gA[n...] == FIRE) + (gA[ne...] == FIRE)
            fires_count += (gA[w...] == FIRE) + (gA[e...] == FIRE)
            fires_count += (gA[sw...] == FIRE) + (gA[s...] == FIRE) + (gA[se...] == FIRE)
            not_fires_count = 8 - fires_count 
            # the fire cools down when there is less fire around
            gB[here...] = rand() < 1 - (1 - extinction_probability)^not_fires_count ? EMPTY : FIRE

        elseif entity == EMPTY
            
            # surrounding trees
            trees_count = (gA[nw...] == TREE) + (gA[n...] == TREE) + (gA[ne...] == TREE)
            trees_count += (gA[w...] == TREE) + (gA[e...] == TREE)
            trees_count += (gA[sw...] == TREE) + (gA[s...] == TREE) + (gA[se...] == TREE)

            # this empty cell has a greater chance to be colonized when many trees around
            gB[here...] =  rand() < 1 - (1 - seedling_probability)^trees_count ? TREE : EMPTY

        end
    end
    return
end

function colorimage!(forest::Forest)
    L = Int(√1024)
    bx, by = cld.(size(forest.image), L) 
    @cuda threads=(L, L) blocks=(bx, by) kernel_colorimage!(forest.gridA, forest.image, 
        forest.colors)
end

function kernel_colorimage!(grid, image, colors)
    x = threadIdx().x + (blockIdx().x - 1) * blockDim().x
    y = threadIdx().y + (blockIdx().y - 1) * blockDim().y
    xmax, ymax = size(grid)
    if 0 < x < xmax + 1 && 0 < y < ymax + 1
        image[x, y] = colors[grid[x, y] + 1]
    end
    return
end

end # module

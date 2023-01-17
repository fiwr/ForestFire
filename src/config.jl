using Colors

const EMPTY = 0
const TREE = 1
const FIRE = 2

ctx = (
    entities = Dict(
        EMPTY => (color = colorant"black", symbol = :empty),
        TREE => (color = colorant"green", symbol = :tree),
        FIRE => (color = colorant"red", symbol = :fire), 
    ),
)
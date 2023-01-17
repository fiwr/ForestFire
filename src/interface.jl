using GLMakie
using Dates: format, now

function run_interface(;grid_dims = (1000, 1000), initial_forest_density = 0.67, 
        interface_resolution = (1280, 720), spi = 30) # steps per image
    forest = Forest(grid_dims); growtrees!(forest; density = initial_forest_density)
    # initialize a square of fire
    xf = grid_dims[1] ÷ 10
    yf = grid_dims[2] ÷ 10
    firecells = CartesianIndices((xf:2xf, yf:2yf)) |> collect
    setfire!(firecells, forest)   

    fig, ax1, ax2, ax3, buttons, sliders = setup_interface(forest;
        resolution = interface_resolution)

    # bring device (gpu) image on host (cpu)
    host_forest_image = Observable(Array(forest.image))
    image!(ax1, host_forest_image)

    # plot trees & fires counts
    trees_count = sum(forest.gridA .== TREE)
    fires_count = sum(forest.gridA .== FIRE)
    trees_points = Observable(Point2f[(0, trees_count)])
    fires_points = Observable(Point2f[(0, fires_count)])
    lines!(ax2, trees_points, color = ctx.entities[TREE].color)
    lines!(ax2, fires_points, color = ctx.entities[FIRE].color)

    # plot parameters values
    seedling_points = Observable(Point2f[(0, sliders[1].value[])])
    ignition_points = Observable(Point2f[(0, sliders[2].value[])])
    extinction_points = Observable(Point2f[(0, sliders[3].value[])])
    lines!(ax3, seedling_points, color = colorant"yellowgreen")
    lines!(ax3, ignition_points, color = colorant"tomato")
    lines!(ax3, extinction_points, color = colorant"grey70")

    datum = [
        (name = "trees", obs = trees_points, T = Int),
        (name = "fires", obs = fires_points, T = Int),
        (name = "seedling", obs = seedling_points, T = Float32),
        (name = "ignition", obs = ignition_points, T = Float32),
        (name = "extinction", obs = extinction_points, T = Float32)
    ]

    global DATE_FORMAT = "yyyymmdd-HHMMSS"
    global DATE_SESSION = format(now(), DATE_FORMAT) # data export identifiers
    global SIZE_STR = join(size(forest.gridA), "x") 

    vstream = VideoStream(fig)

    # events & interactivity
    reset, run, csv, rec = buttons
    isrunning = Observable(false)
    isrecording = Observable(false)

    on(reset.clicks) do clicks
        isrunning[] = false
        # reset forest image
        fill!(forest.gridA, EMPTY)
        growtrees!(forest; density = initial_forest_density)
        setfire!(firecells, forest)
        colorimage!(forest)
        CUDA.@allowscalar forest.step = 0
        host_forest_image[] = Array(forest.image)
        # reset data points
        trees_count = sum(forest.gridA .== TREE)
        fires_count = sum(forest.gridA .== FIRE)
        trees_points[] = Point2f[(0, trees_count)]; notify(trees_points)
        fires_points[] = Point2f[(0, fires_count)]; notify(fires_points)
        autolimits!(ax2)
        seedling_points[] = Point2f[(0, sliders[1].value[])]; notify(seedling_points)
        ignition_points[] = Point2f[(0, sliders[2].value[])]; notify(ignition_points)
        extinction_points[] = Point2f[(0, sliders[3].value[])]; notify(extinction_points)
        autolimits!(ax3)
        DATE_SESSION = format(now(), DATE_FORMAT)
        vstream = VideoStream(fig)
    end

    on(run.clicks) do clicks; isrunning[] = !isrunning[]; end
    on(run.clicks) do clicks
        @async while isrunning[]
            isopen(fig.scene) || break
            for i in 1:spi 
                step!(forest;
                    seedling_probability = sliders[1].value[],
                    ignition_probability = sliders[2].value[],
                    extinction_probability = sliders[3].value[]
                )
            end
            colorimage!(forest)
            host_forest_image[] = Array(forest.image)
            # record trees and fires counts, update plot
            trees_count = sum(forest.gridA .== TREE)
            fires_count = sum(forest.gridA .== FIRE)
            push!(trees_points[], Point2f(forest.step, trees_count)); notify(trees_points)
            push!(fires_points[], Point2f(forest.step, fires_count)); notify(fires_points)
            autolimits!(ax2)
            # record parameters values, update plot
            push!(seedling_points[], Point2f(forest.step, sliders[1].value[]))
            push!(ignition_points[], Point2f(forest.step, sliders[2].value[]))
            push!(extinction_points[], Point2f(forest.step, sliders[3].value[]))
            notify(seedling_points); notify(ignition_points); notify(extinction_points)
            autolimits!(ax3)
            sleep(0.02)
            isrecording[] && recordframe!(vstream)
        end
    end

    on(csv.clicks) do clicks
        save_data_to_csv(forest, datum, spi)
    end

    on(rec.clicks) do clicks
        isrecording[] && save("videos/FF-$(SIZE_STR)-$(DATE_SESSION).mp4", vstream)
        isrecording[] = !isrecording[]
    end

    display(fig)

    return forest, fig
end

function setup_interface(forest::Forest; resolution = (1280, 720))
    fig = Figure(resolution = resolution)
    fig[1, 1] = lgl = GridLayout()
    fig[1, 2] = rgl = GridLayout()

    # ----- interface -----
    # forest simulation display
    lgl[1, 1] = ax1 = Axis(fig, aspect=DataAspect()); hidedecorations!(ax1)

    # plot trees & fires
    rgl[1:3, 1:4] = ax2 = Axis(fig); hidexdecorations!(ax2)
    ax2.title = "Trees & Fire Cells"

    # plot parameters values
    rgl[4:6, 1:4] = ax3 = Axis(fig)
    ax3.title = "Sliders"

    # sliders
    rgl[7:8, 1:4] = slidergrid = SliderGrid(fig,
        (label = "seedling", range = 0:0.0001:1, startvalue = 0.001),
        (label = "ignition", range = 0:0.0001:1, startvalue = 0.01),
        (label = "extinction", range = 0:0.0001:1, startvalue = 0.01),
        tellheight = false
    )
    sliders = slidergrid.sliders
    sliders[1].color_active_dimmed[] = colorant"yellowgreen"
    sliders[2].color_active_dimmed[] = colorant"tomato"
    sliders[3].color_active_dimmed[] = colorant"grey70"
    sliders[1].color_inactive[] = colorant"grey90"
    sliders[2].color_inactive[] = colorant"grey90"
    sliders[3].color_inactive[] = colorant"grey90"

    # buttons
    bcolor = RGB(0.3, 0.4, 0.7)
    rgl[9, 1:2] = buttongrid = GridLayout(tellheight = false)
    reset = Button(fig, label = "reset", buttoncolor = bcolor)
    run = Button(fig, label = "run", buttoncolor = bcolor)
    csv = Button(fig, label = "csv", buttoncolor = bcolor)
    rec = Button(fig, label = "rec", buttoncolor = bcolor)
    buttons = buttongrid[1, 1:4] = [reset, run, csv, rec]
    # TODO: add buttons to draw trees and fire

    return fig, ax1, ax2, ax3, buttons, sliders
end

D = Vector{NamedTuple{(:name, :obs, :T), 
        Tuple{String, Observable{Vector{Point{2, Float32}}}, DataType}}}
function save_data_to_csv(forest::Forest, datum::D, spi::Int)
    step_col = [(i - 1) * spi for i in 1:length(datum[1].obs[])]
    columns_names = String["step"] # add "step" column
    columns_values = Vector{Real}[step_col]
    for data in datum
        push!(columns_names, data.name)
        push!(columns_values, (pt -> data.T(pt[2])).(data.obs[]))
    end
    tuples = zip(columns_values...) |> collect
    tuples = Tuple[Tuple(columns_names); tuples]
    file_lines = (t -> join(t, ",")).(tuples)
    file_content = join(file_lines, "\n")
    open("data/FF-$(SIZE_STR)-$(DATE_SESSION).csv", "w") do f
        write(f, file_content)
    end
    return
end
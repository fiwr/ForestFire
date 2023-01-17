using ForestFire


forest, fig = run_interface(;
    grid_dims = (1000, 1000), 
    initial_forest_density = 0.7,
    interface_resolution = (1280, 720), #(1920, 1080), 
    spi = 3 # steps per image / animation speed
)


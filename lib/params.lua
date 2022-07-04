params:add_separator('tuning')
params:add {
    type='number', name='scale preset', id='scale_preset', min = 1, max = 8,
    default = 1, action = function() 
        nest.screen.make_dirty()
        nest.grid.make_dirty()
    end
}

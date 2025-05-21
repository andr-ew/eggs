local Patcher = Map_patcher

local Components = {
    enc_screen = {},
    key_screen = {},
    grid = {},
}

do
    local x, y, e, k = eggs.x, eggs.y, eggs.e, eggs.k

    function Components.enc_screen.param()
        local _control = Patcher.enc.destination(Enc.control())
        local _integer = Patcher.enc.destination(Enc.integer())

        local _list = Patcher.screen.destination(Screen.list())

        return function(props)
            local p = params:lookup_param(props.id)
            local options = p.options
            local spec = p.controlspec 

            if spec then
                _control(props.id, eggs.mapping, {
                    n = props.n,
                    controlspec = spec,
                    state = eggs.of_param(props.id),
                })
            else
                _integer(props.id, eggs.mapping, {
                    n = props.n, 
                    min = p.min or 1, max = p.max or #options,
                    state = eggs.of_param(props.id),
                })
            end
            
            if crops.mode == 'input' and crops.device == 'enc' then
                patcher.last_assignment.src = nil
                patcher.last_assignment.dest = nil
            end
            
            local src = patcher.get_assignment_of_destination(props.id) 
            local assigned = src and (src ~= 'none')
            
            _list(props.id, eggs.mapping, {
                x = e[props.n].x, y = e[props.n].y, margin = 3,
                text = {
                    props.name or p.name, 
                    options and (
                        options[params:get(props.id)]
                    )
                    or (
                        string.format(
                            props.format or '%.2f', params:get(props.id)
                        )
                        -- ..' '..(spec.units or '')
                    ),
                    assigned and '+' or nil,
                    assigned and string.format(
                        '%.3f', patcher.get_source_value_by_destination(props.id)
                    ) or nil
                },
                levels = { 4, 15 },
            })
        end
    end

    function Components.key_screen.param()
        local _integer = Patcher.key.destination(Key.integer())
        local _binary = {
            momentary = Patcher.key.destination(Key.momentary()),
            toggle = Patcher.key.destination(Key.toggle()),
            trigger = Patcher.key.destination(Key.trigger()),
        }
        local _integer_hold = Patcher.key.destination(Key.integer())
        local _binary_hold = {
            momentary = Patcher.key.destination(Key.momentary()),
            toggle = Patcher.key.destination(Key.toggle()),
            trigger = Patcher.key.destination(Key.trigger()),
        }
        
        local _list = Patcher.screen.destination(Screen.list())

        local downtime = nil
        local blink = false
        local blink_level = 1

        return function(props)
            local p = params:lookup_param(props.id)
            local options = p.options
            local behavior = p.behavior
            local p_hold = props.id_hold and params:lookup_param(props.id_hold)
            local options_hold = p_hold and p_hold.options
            local behavior_hold = p_hold and p_hold.behavior
            
            if crops.device == 'key' and crops.mode == 'input' then
                local n, z = table.unpack(crops.args) 

                local _comp, comp_props
                if behavior then
                    --TODO: trigger needs a different state
                    _comp = _binary[behavior]
                    comp_props = {
                        n = props.n, edge = 'falling',
                        state = eggs.of_param(props.id),
                    }
                else
                    _comp = _integer
                    comp_props = {
                        n_next = props.n, edge = 'falling',
                        min = p.min or 1, max = p.max or #options,
                        state = eggs.of_param(props.id),
                    }
                end

                if n == props.n then
                    if z==1 then
                        downtime = util.time()

                        _comp(props.id, eggs.mapping, comp_props)
                    elseif z==0 then
                        if p_hold and downtime and ((util.time() - downtime) > 0.25) then 
                            blink = true
                            blink_level = 1
                            crops.dirty.screen = true

                            clock.run(function() 
                                params:delta(props.id_hold, 1)

                                clock.sleep(0.1)
                                blink_level = 2
                                crops.dirty.screen = true

                                clock.sleep(0.2)
                                blink_level = 1
                                crops.dirty.screen = true

                                clock.sleep(0.4)
                                blink = false
                                crops.dirty.screen = true
                            end)

                            if behavior == 'momentary' then 
                                _comp(props.id, eggs.mapping, comp_props) 
                            end
                        else
                            _comp(props.id, eggs.mapping, comp_props)
                        end
                        
                        downtime = nil
                    end
                end
            end
            
            local src = patcher.get_assignment_of_destination(props.id)
            local assigned = src and (src ~= 'none')

            _list(props.id, eggs.mapping, {
                x = k[props.n].x, y = k[props.n].y, margin = 3,
                focus = 1,
                text = {
                    blink and (
                        (props.name_hold or p_hold.name)..': '..(
                            behavior_hold and (
                                params:get(props.id_hold) > 0 and 'on' or 'off'
                            ) 
                            or options_hold and (
                                options[params:get(props.id_hold)]
                            )
                        )
                        or options_hold and (
                            options[params:get(props.id_hold)]
                        )
                        or (
                            string.format(props.format or '%i', params:get(props.id_hold))
                        )
                    ) or (
                        behavior and (
                            props.name or p.name
                        )
                        or options and (
                            options[params:get(props.id)]
                        )
                        or (
                            string.format(props.format or '%i', params:get(props.id))
                        )
                    ),
                    assigned and '+' or nil,
                    assigned and string.format(
                        '%.0f', patcher.get_source_value_by_destination(props.id)
                    ) or nil
                },
                --TODO: trigger needs a different state
                levels = { 
                    4, 
                    ((blink and blink_level < 2) or (behavior and params:get(props.id) < 1))
                    and 4 or 15 
                },
            })
        end
    end
end

do
    --default values for every valid prop.
    local defaults = {
        state = {1},
        x = 1,                      --x position of the component
        y = 1,                      --y position of the component
        edge = 'rising',            --input edge sensitivity. 'rising' or 'falling'.
        input = function(n, z) end, --input callback, passes last key state on any input
        levels = { 0, 15, 15 },     --brightness levels. expects a table of 3 ints 0-15
        size = 128,                 --total number of keys
        wrap = 16,                  --wrap to the next row/column every n keys
        flow = 'right',             --primary direction to flow: 'up', 'down', 'left', 'right'
        flow_wrap = 'down',         --direction to flow when wrapping. must be perpendicular to flow
        padding = 0,                --add blank spaces before the first key
        min = 1,                    --value of lowest key. max = min + size
    }
    defaults.__index = defaults

    function Components.grid.fader()
        return function(props)
            if crops.device == 'grid' then 
                setmetatable(props, defaults) 

                if crops.mode == 'input' then 
                    local x, y, z = table.unpack(crops.args) 
                    local n = Grid.util.xy_to_index(props, x, y)

                    if n then 
                        local v = n + props.min - 1

                        if
                            (z == 1 and props.edge == 'rising')
                            or (z == 0 and props.edge == 'falling')
                        then
                            crops.set_state(props.state, v) 
                        end
                        
                        props.input(v, z)
                    end
                elseif crops.mode == 'redraw' then 
                    local g = crops.handler 

                    local n = crops.get_state(props.state) - props.min + 1
                    for i = 1, props.size do
                        local lvl = props.levels[(i == n) and 3 or (i < n) and 2 or 1] 

                        local x, y = Grid.util.index_to_xy(props, i)

                        if lvl>0 then g:led(x, y, lvl) end
                    end
                end
            end
        end
    end
end

do
    --default values for every valid prop.
    local defaults = {
        state = {1},
        state_secondary = { nil },
        x = 1,                      --x position of the component
        y = 1,                      --y position of the component
        edge = 'rising',            --input edge sensitivity. 'rising' or 'falling'.
        input = function(n, z) end, --input callback, passes last key state on any input
        levels = { 0, 4, 15 },      --brightness levels. expects a table of 3 ints 0-15
        size = 128,                 --total number of keys
        wrap = 16,                  --wrap to the next row/column every n keys
        flow = 'right',             --primary direction to flow: 'up', 'down', 'left', 'right'
        flow_wrap = 'down',         --direction to flow when wrapping. must be perpendicular to flow
        padding = 0,                --add blank spaces before the first key
        min = 1,                    --value of lowest key. max = min + size
    }
    defaults.__index = defaults
    
    local dtaptime = 0.25

    function Components.grid.integer_two_layers()
        local lasttime = 0

        return function(props)
            if crops.device == 'grid' then 
                setmetatable(props, defaults) 

                if crops.mode == 'input' then 
                    local x, y, z = table.unpack(crops.args) 
                    local n = Grid.util.xy_to_index(props, x, y)

                    if n then 
                        local v = n + props.min - 1

                        if
                            (z == 1 and props.edge == 'rising')
                            or (z == 0 and props.edge == 'falling')
                        then
                            local tlast = util.time() - lasttime

                            crops.set_state(props.state, v) 
                                
                            if tlast < dtaptime then
                                if crops.get_state(props.state_secondary) then
                                    crops.set_state(props.state_secondary, nil) 
                                else
                                    crops.set_state(props.state_secondary, v) 
                                end
                            end
                            
                            lasttime = util.time()
                        end
                        
                        props.input(v, z)
                    end
                elseif crops.mode == 'redraw' then 
                    local g = crops.handler 

                    local n = crops.get_state(props.state) - props.min + 1
                    local n_secondary = crops.get_state(props.state_secondary) 
                    if n_secondary then
                        n_secondary = n_secondary - props.min + 1
                    end

                    for i = 1, props.size do
                        local lvl
                        if not n_secondary then
                            lvl = props.levels[(i == n) and 3 or 1] 
                        else
                            lvl = props.levels[
                                (i == n) and 2 
                                or (i == n_secondary) and 3
                                or 1
                            ]
                        end

                        local x, y = Grid.util.index_to_xy(props, i)

                        if lvl>0 then g:led(x, y, lvl) end
                    end
                end
            end
        end
    end
end

do
    local defaults = {
        state = {0},
        state_locked = {0},
        x = 1,                   
        y = 1,                   
        levels = { 0, 15 },      
    }
    defaults.__index = defaults
        
    local dtaptime = 0.25

    function Components.grid.momentary_lock() 
        local lasttime = 0

        return function(props) 
            if crops.device == 'grid' then 
                setmetatable(props, defaults) 

                if crops.mode == 'input' then 
                    local x, y, z = table.unpack(crops.args) 
                    local v = z 

                    if x == props.x and y == props.y then 
                        if z==1 then 
                            if crops.get_state(props.state) == 1 then
                                crops.set_state(props.state_locked, 0) 
                            end

                            crops.set_state(props.state, 1) 
                        else
                            local tlast = util.time() - lasttime
                        
                            if tlast > dtaptime then
                                if crops.get_state(props.state_locked) == 0 then
                                    crops.set_state(props.state, 0) 
                                end
                            else
                                crops.set_state(props.state_locked, 1) 
                            end

                            lasttime = util.time()
                        end
                    end
                elseif crops.mode == 'redraw' then 
                    local g = crops.handler 
                    local v = crops.get_state(props.state) or 0 

                    local lvl = props.levels[v + 1] 

                    if lvl>0 then g:led(props.x, props.y, lvl) end 
                end
            end
        end
    end
end

return Components

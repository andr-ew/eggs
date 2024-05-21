local Components = {
    enc_screen = {},
    key_screen = {},
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

return Components

local Components = {
    enc_screen = {},
    key_screen = {},
}

do
    local x, y, e, k = eggs.x, eggs.y, eggs.e, eggs.k

    function Components.enc_screen.param()
        local _control = Enc.control()
        local _integer = Enc.integer()

        local _map = Enc.integer()
        
        local _list = Screen.list()

        return function(props)
            local p = params:lookup_param(props.id)
            local options = p.options
            local spec = p.controlspec 
            local id_ass, options_ass, v_ass

            if props.is_dest ~= false then               
                id_ass = patcher.get_assignment_param_id(props.id)
                options_ass = params:lookup_param(id_ass).options
                v_ass = params:get(id_ass)
            end

            if not eggs.mapping then
                if spec then
                    _control{
                        n = props.n,
                        controlspec = spec,
                        state = eggs.of_param(props.id),
                    }
                else
                    _integer{
                        n = props.n, 
                        min = p.min or 1, max = p.max or #options,
                        state = eggs.of_param(props.id),
                    }
                end
            elseif props.is_dest ~= false then
                _map{
                    n = props.n, max = #options_ass,
                    state = crops.of_variable(v_ass, params.set, params, id_ass)
                }
            end

            local src = (props.is_dest ~= false) and v_ass or 1

            _list{
                x = e[props.n].x, y = e[props.n].y, margin = 3,
                text = ((not eggs.mapping) or (not (props.is_dest ~= false))) and {
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
                    (src > 1) and '+' or nil,
                    (src > 1) and string.format('%.3f', patcher.get_mod_value(props.id)) or nil
                } or {
                    props.name or p.name, 
                    options_ass[v_ass]
                    -- mod.sources[props.mod_id][src]
                },
                levels = { 4, 15 },
            }
        end
    end

    function Components.key_screen.param()
        local _integer = Key.integer()
        local _binary = {
            momentary = Key.momentary(),
            toggle = Key.toggle(),
            trigger = Key.trigger(),
        }
        local _integer_hold = Key.integer()
        local _binary_hold = {
            momentary = Key.momentary(),
            toggle = Key.toggle(),
            trigger = Key.trigger(),
        }
        
        local _map = Key.integer()
        
        local _list = Screen.list()

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
                if not eggs.mapping then
                    local n, z = table.unpack(crops.args) 

                    if n == props.n then
                        if z==1 then
                            downtime = util.time()
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
                            else
                                if behavior then
                                    --TODO: trigger needs a different state
                                    _binary[behavior]{
                                        n = props.n, edge = 'falling',
                                        state = eggs.of_param(props.id),
                                    }
                                else
                                    _integer{
                                        n_next = props.n, edge = 'falling',
                                        min = p.min or 1, max = p.max or #options,
                                        state = eggs.of_param(props.id),
                                    }
                                end
                            end
                            
                            downtime = nil
                        end
                    end
                else
                    _map{
                        ---
                    }
                end
            end

            _list{
                x = k[props.n].x, y = k[props.n].y, margin = 3,
                focus = 1,
                text = (not eggs.mapping) and {
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
                    -- (src > 1) and '+' or nil,
                    -- (src > 1) and string.format('%.3f', mod.get(props.mod_id)) or nil
                } or {
                    -- mod.sources[props.mod_id][src]
                },
                --TODO: trigger needs a different state
                levels = { 
                    4, 
                    ((blink and blink_level < 2) or (behavior and params:get(props.id) < 1))
                    and 4 or 15 
                },
            }
        end
    end
end

return Components

local App = {}

local page = 1

function App.grid(args)
    local hl = { 4, 15 }
    
    local Pages = {}
    
    local reset_keys = {}
    local playing = {}

    for track = 1,2 do
        local off = track==2 and 2 or 0
        local outs = { cv = 1+off, gate = 2+off }

        Pages[track] = function()
            local gate_fwd = 1
            local _gate_fwd = to.pattern(mpat[track], 'gate fwd '..track, Grid.toggle, function()
                return {
                    x = 2, y = 1, lvl = { 4, 15 },
                    state = { gate_fwd, function(v) gate_fwd = v end },
                }
            end)

            local gate = 0
            local function set_gate(v)
                gate = v
                crow.output[outs.gate].volts = gate * 5
            end
            local _gate = to.pattern(mpat[track], 'gate '..track, Grid.momentary, function()
                return {
                    x = 3, y = 1,
                    state = { gate, set_gate },
                }
            end)

            local _keymap, reset_keymap = to.pattern(
                mpat[track], 'keymap '..track, Grid.momentary, 
                function()
                    return {
                        x = { 1, 16 }, y = { 3, 8 }, 
                        -- count = 1,
                        lvl = function(_, x, y)
                            return tune.is_tonic(x, y, params:get('scale_preset')) 
                                and { 4, 15 } 
                                or { 0, 15 }
                        end,
                        action = function(v, t, d, add, rem, l)
                            if #l > 0 then 
                                local k = l[#l]
                                local id = k.x + (k.y * 16)
                                local volts = tune.volts(
                                    k.x, k.y, nil, nil, params:get('scale_preset')
                                )

                                crow.output[outs.cv].volts = volts
                                if gate_fwd>0 then
                                    set_gate(1)
                                end
                            else
                                if gate_fwd>0 then
                                    set_gate(0)
                                end
                            end
                        end
                    }
                end
            )

            local reset = function()
                reset_keymap()
                crow.output[outs.gate].volts = 0
            end

            reset_keys[track] = reset

            local _patrec = PatternRecorder()

            return function()
                _gate_fwd()
                _gate()

                _keymap()
        
                _patrec{
                    x = { 1, 4 }, y = 2, count = 1,
                    pattern = { 
                        pattern[track][1],pattern[track][2],pattern[track][3],pattern[track][4], 
                    }, 
                    varibright = varibright,
                    action = function(v, t, d, add, rem, l)
                        playing[track] = l[1]
                        reset()
                    end
                }
            end
        end
    end

    Pages[3] = function()
        local track = 3

        local _keymap = to.pattern(mpat[track], 'keymap '..track, Grid.momentary, function()
            return {
                x = { 1, 16 }, y = { 3, 8 }, count = 6,
                lvl = function(_, x, y)
                    return tune.is_tonic(x, y, params:get('scale_preset')) 
                        and { 4, 15 } 
                        or { 0, 15 }
                end,
                action = function(v, t, d, add, rem)
                    local k = add or rem
                    local id = k.x + (k.y * 16)
                    local vel = math.random()*0.2 + 0.85

                    if add then 
                    elseif rem then end
                end
            }
        end)

        return function()
            _keymap()
        end
    end

    Pages[4] = function()
        local _scale_degrees = Tune.grid.scale_degrees{ left = 2, top = 4 }
        local _tonic = Tune.grid.tonic{ left = 2, top = 7 }

        return function()
            _scale_degrees{ preset = params:get('scale_preset') }
            _tonic{ preset = params:get('scale_preset') }
        end
    end

    local _pages = {}; for i, Page in ipairs(Pages) do _pages[i] = Page() end

    local _tab = Grid.number()

    return function(props)
        
        _tab{
            x = { 4 + 1, 4 + #_pages }, y = 1, lvl = hl,
            state = { 
                page, 
                function(v) 
                    page = v 
                    nest.screen.make_dirty()

                    for i,res in ipairs(reset_keys) do 
                        if not playing[i] then res() end
                    end
                end 
            }
        }

        _pages[page]()
    end
end

function App.norns(args)
    
    local Pages = {}

    for track = 1,2 do
        Pages[track] = function()

            return function()
            end
        end
    end

    Pages[3] = function()
        local track = 3

        return function()
        end
    end

    Pages[4] = function()
        local _scale_degrees = Tune.norns.scale_degrees()
        local _options = Tune.norns.options()

        return function()
            _scale_degrees{ preset = params:get('scale_preset') }
            _options{ preset = params:get('scale_preset') }
        end
    end

    local _pages = {}; for i, Page in ipairs(Pages) do _pages[i] = Page() end

    return function(props)
        _pages[page]()
    end
end

return App

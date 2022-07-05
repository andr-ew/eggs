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
        crow.output[outs.cv].shape = 'exponential' 

        --TODO: use params for session persistence
        Pages[track] = function()
            local slew = 0
            local show_slew_time = false
            local set_slew = multipattern.wrap_set(
                mpat[track], 'slew '..track, function(v)
                    slew = v
                end
            )
            local _slew = Grid.momentary(function()
                return {
                    x = 1, y = 2, lvl = { 0, 15 },
                    state = { 
                        slew, 
                        function(v) 
                            set_slew(v)
                            show_slew_time = v==1
                        end 
                    }
                }
            end)

            local slew_times = { 0.05, 0.07, 0.1, 0.2, 0.3, 0.4, 0.5, 1 }
            local slew_time = 1
            local _slew_time = to.pattern(mpat[track], 'slew time '..track, Grid.number, function()
                return { 
                    x = { 2, 8 }, y = 2, lvl = hl,
                    state = { slew_time, function(v) slew_time = v end }
                }
            end)

            local oct = 0
            local x, y = 1, 1
            local gate = 0

            local function update_gate()
                crow.output[outs.gate].volts = gate * 5
            end
            --TODO: crow input transpose
            local function update_pitch()
                local volts = tune.volts(
                    x, y, nil, oct, params:get('scale_preset')
                )
                crow.output[outs.cv].slew = slew * (
                    slew_times[slew_time] 
                    --+ (math.random() * 0.05 * (math.random(0, 1) * 2 - 1))
                )
                crow.output[outs.cv].volts = volts

                nest.grid.make_dirty()
            end


            local _oct = to.pattern(mpat[track], 'oct '..track, Grid.number, function()
                return {
                    x = { 1, 6 }, y = 8, min = -2, max = 3, lvl = hl,
                    state = { oct, function(v) oct = v; update_pitch() end }
                }
            end)

            local pat = pattern[track]
            local _keymap_recorder = PatternRecorder()
            local _parameter_recorder = PatternRecorder()

            local time_factors = { 4, 3, 2, 1, 1/2, 1/3, 1/4 }
            local _pattern_rate = to.pattern(
                { mpat[track][5], mpat[track][6] }, 'pattern rate '..track, Grid.number, 
                function() 
                    local p = pat[playing[track]]
                    print('playing', playing[track], p)
                    return {
                        x = { 2, 8 }, y = 2,
                        state = { 
                            p and tab.key(time_factors, p.time_factor) or 0,
                            function(v)
                                local pp = pat[playing[track]]
                                if pp then pp:set_time_factor(time_factors[v]) end
                            end
                        }
                    }
                end
            )

            local _keymap, reset_keymap = to.pattern(
                mpat[track], 'keymap '..track, Grid.momentary, 
                function()
                    return {
                        x = { 1, 16 }, y = { 3, 7 }, 
                        -- count = 1,
                        lvl = function(_, x, y)
                            return tune.is_tonic(x, y, params:get('scale_preset')) 
                                and { 4, 15 } 
                                or { 0, 15 }
                        end,
                        action = function(v, t, d, add, rem, l)
                            if #l > 0 then 
                                local k = l[#l]

                                x, y = k.x, k.y
                                gate = 1

                                update_pitch()
                                update_gate()
                            else
                                gate = 0; update_gate()
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

            --TODO: rate & reverse components per pattern

            return function()
                _keymap_recorder{
                    x = { 5, 8 }, y = 1, count = 1,
                    pattern = { pat[1], pat[2], pat[3], pat[4] }, 
                    varibright = varibright,
                    action = function(v, t, d, add, rem, l)
                        playing[track] = l[1]
                        reset()
                    end
                }

                _slew()
                if show_slew_time then 
                    _slew_time() 
                else
                    if playing[track] then
                        _pattern_rate()
                    end
                end

                _keymap()

                _oct()
                _parameter_recorder{
                    x = { 7, 8 }, y = 8,
                    pattern = { pat[5], pat[6] }, 
                    varibright = varibright,
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
            x = { 0 + 1, 0 + #_pages }, y = 1, lvl = hl,
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

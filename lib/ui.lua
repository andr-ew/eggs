local App = {}

local page = 1

params:add_separator('tracks')

function App.grid(args)
    local hl = { 4, 15 }
    
    local Pages = {}
    
    local reset_keys = {}
    --local playing = {}

    function get_playing(track)
        for i,v in ipairs(pattern_states[track].keymap) do
            if v >= 3 then return i end
        end
    end

    for track = 1,2 do
        local off = track==2 and 2 or 0
        local outs = { cv = 1+off, gate = 2+off }
        crow.output[outs.cv].shape = 'exponential' 

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
                    x = 1, y = 2, lvl = hl,
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

            params:add{
                id = 'slew time '..track, type = 'option',
                options = slew_times,
            }

            local _slew_time = to.pattern(mpat[track], 'slew time '..track, Grid.number, function()
                return { 
                    x = { 2, 8 }, y = 2, lvl = hl,
                    state = of.param('slew time '..track),
                }
            end)

            local x, y = 1, 1
            local gate = 0

            local function update_gate()
                crow.output[outs.gate].volts = gate * 5
            end

            --TODO: crow input 1 transpose track 1 (diatonic)
            local function update_pitch()
                local volts = tune.volts(
                    x, y, nil, params:get('oct '..track), params:get('scale_preset')
                )
                crow.output[outs.cv].slew = slew * (
                    slew_times[params:get('slew time '..track)] 
                    --+ (math.random() * 0.05 * (math.random(0, 1) * 2 - 1))
                )
                crow.output[outs.cv].volts = volts

                nest.grid.make_dirty()
            end

            params:add{
                id = 'oct '..track, type = 'number', min = -2, max = 3,
                action = update_pitch
            }

            local _oct = to.pattern(mpat[track], 'oct '..track, Grid.number, function()
                return {
                    x = { 1, 6 }, y = 8, min = -2, max = 3, lvl = hl,
                    state = of.param('oct '..track),
                }
            end)

            local pat = pattern[track]
            local _keymap_recorder = PatternRecorder()
            local _parameter_recorder = PatternRecorder()

            local time_factors = { 4, 3, 2, 1, 1/2, 1/3, 1/4 }
            local _pattern_rate = to.pattern(
                { mpat[track][5], mpat[track][6] }, 'pattern rate '..track, Grid.number, 
                function() 
                    local p = pat[get_playing(track)]
                    return {
                        x = { 2, 8 }, y = 2,
                        state = { 
                            p and tab.key(time_factors, p.time_factor) or 0,
                            function(v)
                                local pp = pat[get_playing(track)]
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

            local p_st = pattern_states[track]

            return function()
                _keymap_recorder{
                    x = { 5, 8 }, y = 1, count = 1,
                    pattern = { pat[1], pat[2], pat[3], pat[4] }, 
                    state = { pattern_states[track].keymap },
                    varibright = varibright,
                    action = function(v, t, d, add, rem, l)
                        reset()
                    end
                }

                _slew()
                if show_slew_time then 
                    _slew_time() 
                else
                    if get_playing(track) then
                        _pattern_rate()
                    end
                end

                _keymap()

                _oct()
                _parameter_recorder{
                    x = { 7, 8 }, y = 8,
                    pattern = { pat[5], pat[6] }, 
                    state = { pattern_states[track].parameter },
                    varibright = varibright,
                }
            end
        end
    end

    Pages[3] = function()
        local track = 3

        params:add{
            id = 'jf synth mode', type = 'binary', 
            behavior = 'toggle', default = 1,
            action = function(v)
                crow.ii.jf.mode(v)
            end
        }
        local _mode = Grid.toggle()

        local bend = 0
        local nums = { -5, -4, -3, -2, 1, 2, 3, 4, 5 }
        -- local numerator = tab.key(nums, 1)
        -- local denominator = 1

        local function update_run()
            local num = nums[params:get('jf fm numerator')] 
            local r = num/params:get('jf fm denominator')
            if num > 0 then r = r - 1 end
            if num < 0 then r = r + 1 end
            crow.ii.jf.run_mode(1)
            crow.ii.jf.run(r * 5)
        end

        params:add{
            id = 'jf fm numerator', type = 'option', options = nums, action = update_run
        }
        params:add{
            id = 'jf fm denominator', type = 'number', min = 1, max = 5, action = update_run
        }


        local _one = Grid.fill()
        local _numerator = to.pattern(mpat[track], 'numerator', Grid.number, function()
            return {
                x = { 8, 16 }, y = 1,
                state = of.param('jf fm numerator')
            }
        end)
        local _denominator = to.pattern(mpat[track], 'denominator ', Grid.number, function()
            return {
                x = { 12, 16 }, y = 2,
                state = of.param('jf fm denominator')
            }
        end)

        local function update_transpose()
            crow.ii.jf.transpose(params:get('oct '..track) + bend)
        end

        params:add{
            id = 'oct '..track, type = 'number', min = -2, max = 3,
            action = update_transpose,
        }
        

        crow.input[2].mode('stream', 0.001)
        crow.input[2].stream = function(v)
            --convert to linear
            bend = math.log(
                math.max(0.00001, ((v / 5) + 1)) * math.exp(1)
            ) 
            -- bend = math.log(
            --     math.max(0.00001, ((v / 5) + 1)) * 2,
            --     2
            -- ) 
            --bend = v/5
            update_transpose()
        end


        local _oct = to.pattern(mpat[track], 'oct '..track, Grid.number, function()
            return {
                x = { 1, 6 }, y = 8, min = -2, max = 3, lvl = hl,
                state = of.param('oct '..track)
            }
        end)

        local pat = pattern[track]
        local _keymap_recorder = PatternRecorder()
        local _parameter_recorder = PatternRecorder()

        local time_factors = { 4, 3, 2, 1, 1/2, 1/3, 1/4 }
        local _pattern_rate = to.pattern(
            { mpat[track][5], mpat[track][6] }, 'pattern rate '..track, Grid.number, 
            function() 
                local p = pat[get_playing(track)]
                return {
                    x = { 2, 8 }, y = 2,
                    state = { 
                        p and tab.key(time_factors, p.time_factor) or 0,
                        function(v)
                            local pp = pat[get_playing(track)]
                            if pp then pp:set_time_factor(time_factors[v]) end
                        end
                    }
                }
            end
        )

        local _keymap, reset_keymap = to.pattern(
            mpat[track], 'keymap '..track, Grid.momentary, function()
                return {
                    x = { 1, 16 }, y = { 3, 7 }, count = 6,
                    lvl = function(_, x, y)
                        return tune.is_tonic(x, y, params:get('scale_preset')) 
                            and { 4, 15 } 
                            or { 0, 15 }
                    end,
                    action = function(v, t, d, add, rem)
                        local k = add or rem
                        local vel = math.random()*0.2 + 0.85
                        local volts = tune.volts(
                            k.x, k.y, nil, -3, params:get('scale_preset')
                        )

                        if add then 
                            crow.ii.jf.play_note(volts, 3.5 * vel)
                        elseif rem then 
                            crow.ii.jf.play_note(volts, 0)
                        end
                    end
                }
            end
        )

        local reset = function()
            reset_keymap()
            for i = 1,6 do
                crow.ii.jf.trigger(i, 0)
            end
        end
        reset_keys[track] = reset
        reset()
        
        return function()
            _mode{
                x = 1, y = 2,
                state = of.param('jf synth mode')
            }
            _keymap_recorder{
                x = { 5, 7 }, y = 1, count = 1,
                pattern = { pat[1], pat[2], pat[3] }, 
                state = { pattern_states[track].keymap },
                varibright = varibright,
                action = function(v, t, d, add, rem, l)
                    reset()
                end
            }

            _one{
                x = 12, y = { 1, 2 }, lvl = 4
            }
            _numerator()
            _denominator()

            if get_playing(track) then
                _pattern_rate()
            end

            _keymap()

            _oct()
            _parameter_recorder{
                x = { 7, 8 }, y = 8,
                pattern = { pat[5], pat[6] }, 
                state = { pattern_states[track].parameter },
                varibright = varibright,
            }
        end
    end

    Pages[4] = function()
        local _scale_degrees = Tune.grid.scale_degrees{ left = 1, top = 4 }
        local _tonic = Tune.grid.tonic{ left = 1, top = 7 }

        return function()
            _scale_degrees{ preset = params:get('scale_preset') }
            _tonic{ preset = params:get('scale_preset') }
        end
    end

    local _pages = {}; for i, Page in ipairs(Pages) do _pages[i] = Page() end

    local _tab = Grid.number()
    local _tab_bg = Grid.fill()

    return function(props)
        _tab_bg{
            x = { 1, 3 }, y = 1, lvl = 4,
        }
        _tab{
            x = { 0 + 1, 0 + #_pages }, y = 1, --lvl = hl,
            state = { 
                page, 
                function(v) 
                    page = v 
                    nest.screen.make_dirty()

                    for i,res in ipairs(reset_keys) do 
                        if not get_playing(i) then res() end
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

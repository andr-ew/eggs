local App = {}

local page = 1
local reset_keys = {}
            
local modes = { 'transient', 'sustain', 'cycle' }
local shapes = {
    'linear',
    'sine',
    'logarithmic',
    'exponential',
    'now',
    'wait',
    'over',
    'under',
    'rebound',
}

local function update_gate(track, v)
    local off = track==2 and 2 or 0
    local out = 2+off
    --crow.output[outs.gate].volts = gate * 5
    local mode = modes[params:get('mode '..track)]

    if mode == 'sustain' then
        crow.output[out](v > 0)
    else
        if v > 0 then crow.output[out]() end
    end
end


function App.norns(args)
    local x,y = {}, {}

    local mar = { left = 2, top = 4, right = 2, bottom = 0 }
    local w = 128 - mar.left - mar.right
    local h = 64 - mar.top - mar.bottom

    x[1] = mar.left
    x[2] = 128/2
    y[1] = mar.top
    y[2] = nil
    y[3] = mar.top + h*(5.5/8)
    y[4] = mar.top + h*(7/8)

    local e = {
        { x = x[1], y = y[1] },
        { x = x[1], y = y[3] },
        { x = x[2], y = y[3] },
        { x = x[2], y = y[1] },
    }
    local k = {
        {  },
        { x = x[1], y = y[4] },
        { x = x[2], y = y[4] },
    }
    
    local Pages = {}

    local out_volts = { 0, 0, 0, 0 }
    do
        --output queries

        local event_id = norns.crow.register_event(function(...) 
            --print('received', ...)
            out_volts = { ... }
            nest.screen.make_dirty()
        end)
        local function query()
            local msg ="tell('"..event_id..[[', 
                output[1].volts,
                output[2].volts,
                output[3].volts,
                output[4].volts
            )]]
            --print('msg', msg)
            crow.send(msg)
        end

        local fps = 40
        clock.run(function() 
            while true do
                query()
                clock.sleep(1/fps)
            end
        end)
    end

    for track = 1,2 do
        local off = track==2 and 2 or 0
        local outs = { cv = 1+off, gate = 2+off }

        Pages[track] = function()
            params:add_separator('env '..track)

            local function update_dyn()
                local time = params:get('time '..track)
                local ramp = params:get('ramp '..track)
                local l = params:get('level '..track)
                local a, r

                if ramp > 0 then
                    r = time * (0.5 + ramp/2)
                    a = time * (0.5 - ramp/2)
                else
                    r = time * (0.5 - -ramp/2)
                    a = time * (0.5 + -ramp/2)
                end

                crow.output[outs.gate].dyn.l = l
                crow.output[outs.gate].dyn.a = a
                crow.output[outs.gate].dyn.r = r

                nest.screen.make_dirty()
            end
            local function update_asl()
                local mode = modes[params:get('mode '..track)]
                local shape = "'"..shapes[params:get('shape '..track)].."'"
                local retrig = params:get('retrigger '..track) > 0
                local lock = retrig and "" or "lock{"
                local end_lock = retrig and "" or "}"

                if mode == 'transient' then
                    local action = "{"..
                        "to(dyn{ l = 7 }, dyn{a = 1}, "..shape.."),"..
                            lock..
                                "to(0, dyn{r = 1}, "..shape..")"..
                            end_lock..
                        "}"
                    crow.output[outs.gate].action = action
                elseif mode == 'sustain' then
                    crow.output[outs.gate].action = "{"..
                        "held{ to(dyn{ l = 7 }, dyn{a = 1}, "..shape..") },"..
                        lock..
                            "to(0, dyn{r = 1}, "..shape..")"..
                        end_lock..
                    "}"
                elseif mode == 'cycle' then
                    crow.output[outs.gate].action = "{"..
                        lock..
                            "loop{"..
                                "to(dyn{ l = 7 }, dyn{a = 1}, "..shape.."),"..
                                "to(0, dyn{r = 1}, "..shape.."),"..
                            "}"..
                        end_lock..
                    "}"
                end

                update_dyn()
            end

            params:add{
                id = 'shape '..track, name = 'shape',
                type = 'option', options = shapes,
                action = update_asl,
            }
            params:add{
                id = 'mode '..track, name = 'mode',
                type = 'option', options = modes,
                action = update_asl,
            }
            params:add{
                id = 'retrigger '..track, name = 'retrigger',
                type = 'binary', 
                behavior = 'toggle', default = 0,
                action = update_asl,
            }
            params:add{
                id = 'time '..track, name = 'time', type = 'control',
                controlspec = cs.new(0.001, 16, 'exp', 0, 0.04, "s"),
                action = update_dyn,
            }
            params:add{
                id = 'ramp '..track, name = 'ramp', type = 'control',
                controlspec = cs.def { min = -1, max = 1, default = 0 },
                action = update_dyn,
            }
            params:add{
                id = 'level '..track, name = 'level', type = 'control',
                controlspec = cs.def{ min = 0, max = 10, default = 7 },
                action = update_dyn,
            }

            local _time = to.pattern(mpat[track], 'time '..track, Text.enc.control, function() 
                return {
                    n = 1, x = e[1].x, y = e[1].y, label = 'time',
                    state = of.param('time '..track), 
                    controlspec = of.controlspec('time '..track)
                }
            end)
            local _shape = to.pattern(mpat[track], 'shape '..track, Text.enc.number, function() 
                return {
                    x = e[2].x, y = e[2].y, n = 2, wrap = false,
                    min = 1, step = 1, inc = 1, max = #shapes,
                    label = 'shape',
                    formatter = function(v) 
                        local shape = shapes[v]
                        if shape == 'logarithmic' then shape = 'log' end
                        if shape == 'exponential' then shape = 'expo' end
                        return shape
                    end,
                    state = of.param('shape '..track)
                }
            end)
            local _ramp = to.pattern(mpat[track], 'ramp '..track, Text.enc.control, function() 
                return {
                    n = 3, x = e[3].x, y = e[3].y, label = 'ramp',
                    state = of.param('ramp '..track), 
                    controlspec = of.controlspec('ramp '..track)
                }
            end)
            local _mode = to.pattern(mpat[track], 'mode '..track, Text.key.option, function() 
                return {
                    n = { 2, 3 }, x = k[2].x, y = k[2].y, wrap = true,
                    options = { 'trns', 'sus', 'cyc' },
                    --state = of.param('mode '..track),
                    state = {
                        params:get('mode '..track),
                        function(v)
                            params:set('mode '..track, v)
                        end
                    }
                }
            end)

            return function()
                _shape()
                _time()
                _ramp()
                _mode()

                --draw output volts
                if nest.screen.is_drawing() then
                    for i = 1,4 do
                        screen.level(
                            ((i == outs.cv) or (i == outs.gate)) and 8 or 2
                        )
                        --screen.move(x[1] + w*(1/11), 15 + i*5)
                        screen.move(x[1], 12 + i*6)
                        screen.line_width(1)
                        screen.line_rel(out_volts[i] * w * (1/10) * 1.5 + 1, 0)
                        screen.stroke()
                    end
                end
            end
        end
    end

    Pages[3] = function()
        local track = 3

        params:add_separator('jf')

        params:add{
            id = 'jf synth mode', name = 'synth mode',
            type = 'binary', 
            behavior = 'toggle', default = 1,
            action = function(v)
                crow.ii.jf.mode(v)

                nest.screen.make_dirty()
                nest.grid.make_dirty()
            end
        }

        local nums = { -5, -4, -3, -2, 1, 2, 3, 4, 5 }
        local function update_run()
            local num = nums[params:get('jf fm numerator')] 
            local r = num/params:get('jf fm denominator')
            if num > 0 then r = r - 1 end
            if num < 0 then r = r + 1 end
            crow.ii.jf.run_mode(1)
            crow.ii.jf.run(r * 5)

            nest.grid.make_dirty()
            nest.screen.make_dirty()
        end

        local bend = 0
        local function update_transpose()
            crow.ii.jf.transpose(params:get('oct '..track) + bend)
        end

        params:add{
            id = 'oct '..track, name = 'oct',
            type = 'number', min = -2, max = 3,
            action = update_transpose,
        }
        
        crow.input[2].mode('stream', 0.001)
        crow.input[2].stream = function(v)
            --convert to linear
            bend = math.log(
                math.max(0.00001, ((v / 5) * 5/12) + 1) * math.exp(1)
            ) - 1
            -- bend = math.log(
            --     math.max(0.00001, ((v / 5) * 5/12) + 1) * 2,
            --     2
            -- )  - 1
            --bend = v/5
            update_transpose()
        end

        params:add{
            id = 'jf level', name = 'note level',
            type = 'control', 
            controlspec = cs.def{ min = 0, max = 5, default = 3.5 }
        }
        params:add{
            id = 'jf fm numerator', name = 'fm numerator',
            type = 'option', options = nums, action = update_run
        }
        params:add{
            id = 'jf fm denominator', name = 'fm denominator',
            type = 'number', min = 1, max = 5, action = update_run
        }
        params:add{
            id = 'jf panic!', name = 'panic!',
            type = 'binary', behavior = 'trigger',
            action = function()
                reset_keys[3]()
            end
        }

        local _numerator = to.pattern(mpat[track], 'jf fm numerator', Text.enc.number, function() 
            return {
                x = e[2].x, y = e[2].y, n = 2, wrap = false,
                min = 1, step = 1, inc = 1, max = #nums,
                --label = 'fm num',
                label = 'numerator',
                formatter = function(v) 
                    return nums[v]
                end,
                state = of.param('jf fm numerator')
            }
        end)
        local _denominator = to.pattern(
            mpat[track], 'jf fm denominator', Text.enc.number, function() 
                return {
                    x = e[3].x, y = e[3].y, n = 3, wrap = false,
                    min = 1, step = 1, inc = 1, max = 5,
                    --label = 'fm denom',
                    label = 'denominator',
                    state = of.param('jf fm denominator')
                }
            end
        )
        local _level = to.pattern(mpat[track], 'jf level', Text.enc.control, function() 
            return {
                n = 1, x = e[1].x, y = e[1].y, label = 'note lvl',
                state = of.param('jf level'), 
                controlspec = of.controlspec('jf level')
            }
        end)
        local _mode = Text.key.toggle()
        local _panic = Text.key.trigger()

        return function()
            _mode{
                n = 2, x = k[2].x, y = k[2].y, label = 'synth mode',
                state = of.param('jf synth mode'),
            }
            if params:get('jf synth mode') > 0 then
                _level()
                _numerator()
                _denominator()

                _panic{
                    n = 3, x = k[3].x, y = k[3].y, label = 'panic!',
                    state = of.param('jf panic!'),
                }
            end
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

    local _tab = Text.enc.option()
    local _pages = {}; for i, Page in ipairs(Pages) do _pages[i] = Page() end

    return function(props)
        _tab{
            x = e[4].x, y = e[4].y, n = 4, options = { 1, 2, 'jf', 'scale' }, 
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

function App.grid(args)
    local hl = { 4, 15 }
    
    local Pages = {}
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
            params:add_separator('cv '..track)

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
                id = 'slew time '..track, name = 'slew time',
                type = 'option',
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
                id = 'oct '..track, name = 'oct',
                type = 'number', min = -2, max = 3,
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
                                update_gate(track, gate)
                            else
                                gate = 0; update_gate(track, gate)
                            end
                        end
                    }
                end
            )

            local reset = function()
                reset_keymap()
                gate = 0; update_gate(track, gate)
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

        --local _mode = Grid.toggle()

        -- local numerator = tab.key(nums, 1)
        -- local denominator = 1

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
                        local lvl = params:get('jf level')

                        if add then 
                            crow.ii.jf.play_note(volts, lvl * vel)
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
            -- _mode{
            --     x = 1, y = 2, lvl = hl,
            --     state = of.param('jf synth mode')
            -- }
            if params:get('jf synth mode') > 0 then
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
    local _tab_bg2 = Grid.fill()

    return function(props)
        _tab_bg{
            x = { 1, 3 }, y = 1, lvl = 4,
        }
        _tab_bg2{
            x = 4, y = 1, lvl = 1,
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

return App

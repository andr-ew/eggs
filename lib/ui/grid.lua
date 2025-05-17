local function Frets()
    return function(props)
        if crops.mode == 'redraw' and crops.device == 'grid' then
            local g = crops.handler

            local ivs = props.intervals
            local rows = props.rows
            local columns = props.columns
            local view_width = props.view_width
            local offset = props.offset

            local count = math.ceil(columns / ivs)
            local lvl = props.level
            -- print('rows, count, ivs', rows, count, ivs)

            if lvl>0 then for i = 1, count do
                local x = props.x + ((i - 1) * ivs) - props.offset

                if x >= props.x and x <= props.x + view_width - 1 then
                    for ii = 1, rows do
                        local y = props.y - ii + 1
                        g:led(x, y, lvl)
                    end
                end
            end
        end end
    end
end

local function Keymaps(args)
    local track = args.track
    local arq = eggs.arqs[track]

    local _frets = Frets()

    local _keymap = {
        mono = Keymap.grid.mono(),
        poly = Keymap.grid.poly(),
        arq = Arqueggiator.grid.keymap()
    }

    return function(props)
        local mode = params:get('mode_'..track)
        local out = eggs.track_dest[track]
        local voicing = out.voicing
        local typ = mode==eggs.ARQ and 'arq' or voicing

        _frets{
            x = 1, y = 8, 
            rows = eggs.keymap_view_height, columns = eggs.keymap_columns, 
            view_width = eggs.keymap_view_width,
            intervals = params:get('intervals_'..track), offset = eggs.get_view(track),
            -- flow = 'right', flow_wrap = 'up',
            level = mode==eggs.ARQ and 1 or props.levels[1],
        }
        do
            local keymap_props = {
                x = 1, y = 8, 
                view_width = eggs.keymap_view_width,
                view_height = eggs.keymap_view_height,
                view_x = eggs.get_view(track),
                view_y = 0,
                size = eggs.keymap_size, wrap = eggs.keymap_wrap,
                flow = 'right', flow_wrap = 'up', 
                levels = mode==eggs.ARQ and props.levels or { 0, props.levels[3] },  
                step = arq.step, gate = arq.gate,
                mode = eggs.mode_names[mode],
                action_latch = function()
                end,
                state = mode==eggs.ARQ 
                            and crops.of_variable(arq.sequence, eggs.arq_setters[track]) 
                            or eggs.keymaps[track]:get_state(mode==LATCH)
                        ,
                -- action_replace = function() arq:restart() end
            }

            _keymap[typ](keymap_props)
        end
    end
end

local function Arq(args)
    -- local _frets = Tune.grid.fretboard()
    local _keymap = Arqueggiator.grid.keymap()

    local arq = args.arq
    local mute_group = args.mute_group
    local pattern_group = args.pattern_group
    local snapshot_count = args.snapshot_count
    --TODO: mulipattern alongside div & reverse (?)
    local function process_arq(new)
        arq:set_sequence(new)

        crops.dirty.grid = true;
    end
    mute_group.process = process_arq

    local function set_arq(new)
        process_arq(new)
        mute_group:watch(new)
    end

    local _patrecs = {}
    for i = 1, #pattern_group do
        _patrecs[i] = Patcher.grid.destination(Produce.grid.pattern_recorder())
    end

    local _snapshots = {}
    for i = 1, eggs.snapshot_count do
        _snapshots[i] = Patcher.grid.destination(Produce.grid.triggerhold())
    end
    
    -- local _rate_mark = Patcher.grid.destination(Grid.fill())
    local _rate = Patcher.grid.destination(Grid.integer(), { levels = { nil, { 4, 8 } } })
    local _rate_small = Patcher.grid.destination(Produce.grid.integer_trigger())
    local _reverse = Patcher.grid.destination(Grid.toggle())
    local _loop = Patcher.grid.destination(Grid.toggle())
    local _pulse = Patcher.grid.destination(Grid.trigger())

    return function(props)
        local ss = props.snapshots
        local wide = props.wide
        local nudge = wide and -2 or 0

        if eggs.view_focus == eggs.NORMAL then
            for i = 1, wide and #pattern_group or 1 do
                _patrecs[i](nil, eggs.mapping, {
                    x = nudge + 4 + i - 1, y = 1,
                    pattern = pattern_group[i],
                })
            end

            -- if #arq.sequence > 0 then
            if true then
                do
                    local id = arq:pfix('pulse')
                    _pulse(id, eggs.mapping, {
                        x = nudge + 3, y = 2, levels = { 4, 15 },
                        input = function()
                            eggs.set_param(id, params:get(id) ~ 1)
                        end
                    })
                end
                do
                    local id = arq:pfix('reverse')
                    _reverse(id, eggs.mapping, {
                        x = nudge + 4, y = 2, levels = { 4, 15 },
                        state = eggs.of_param(id, true)
                    })
                end
                if wide then
                    -- _rate_mark(nil, eggs.mapping, {
                    --     x = 8, y = 2, level = 4,
                    -- })
                    do
                        local id = arq:pfix('division')
                        local stopped = params:get(id) == 1
                        _rate(id, eggs.mapping, {
                            x = nudge + 5, y = 2, size = 7, levels = { 0, stopped and 4 or 15 },
                            state = eggs.of_param(id, true)
                        })
                    end
                    do
                        local id = arq:pfix('loop')
                        _loop(id, eggs.mapping, {
                            x = nudge + 12, y = 2, levels = { 4, 15 },
                            state = eggs.of_param(id, true)
                        })
                    end
                else
                    local id = arq:pfix('division')
                    _rate_small(id, eggs.mapping, {
                        x = nudge + 5, y = 2, size = 2,
                        levels = { 0, 15 }, wrap = false,
                        min = 1, max = 7,
                        state = eggs.of_param(id, true)
                    })
                end
            end
        end

        if wide or props.view_scroll == 0 then
            for i = 1, wide and eggs.snapshot_count or 2 do
                local filled = (ss[i] and #ss[i] > 0)

                local function snapshot()
                    ss[i] = arq.sequence
                end
                local function clear_snapshot()
                    ss[i] = {}
                    -- arq.sequence = {}
                end
                local function recall()
                    if #(ss[i] or {}) > 0 then 
                        set_arq(ss[i])
                    end
                end
                _snapshots[i](nil, eggs.mapping, {
                    x = nudge + (wide and 9 or 6) + i - 1, y = 1,
                    levels = { filled and 4 or 0, filled and 15 or 8 },
                    action_tap = filled and recall or snapshot,
                    action_hold = clear_snapshot,
                })
            end
        end
    end
end

local function Rate_reverse()
    local _reverse = Patcher.grid.destination(Grid.toggle())
    -- local _rate_mark = Patcher.grid.destination(Grid.fill())
    local _rate = Patcher.grid.destination(Grid.integer())
    local _loop = Patcher.grid.destination(Grid.toggle())
    local _rate_small = Patcher.grid.destination(Produce.grid.integer_trigger())

    return function(props)
        local wide = props.wide
        local prefix = 'pattern_track_'..props.track..'_'..props.voicing
        local nudge = wide and -2 or 0

        _reverse(prefix..'_reverse', eggs.mapping, {
            x = nudge + 4, y = 2, levels = { 4, 15 },
            state = eggs.of_param(prefix..'_reverse')
        })
        do
            if wide then
                -- _rate_mark(nil, eggs.mapping, {
                --     x = 8, y = 2, level = 4,
                -- })
                _rate(prefix..'_time_factor', eggs.mapping, {
                    x = nudge + 5, y = 2, size = 7, min = -3,
                    state = eggs.of_param(prefix..'_time_factor')
                })
                _loop(prefix..'_loop', eggs.mapping, {
                    x = nudge + 12, y = 2, levels = { 4, 15 },
                    state = eggs.of_param(prefix..'_loop')
                })
            else
                _rate_small(prefix..'_time_factor', eggs.mapping, {
                    x = nudge + 5, y = 2, size = 2,
                    levels = { 0, 15 }, wrap = false,
                    min = -8, max = 8,
                    state = eggs.of_param(prefix..'_time_factor')
                })
            end
        end
    end
end

local function Scale_key()
    local chans = eggs.channels

    local _grouper = Patcher.grid.destination(Grid.toggle())
    
    local _mode = Patcher.grid.destination(Grid.integer())
    local _intervals = Patcher.grid.destination(Components.grid.fader())

    local _transpose = Patcher.grid.destination(Produce.grid.integer_trigger())
    local _offset = Patcher.grid.destination(Produce.grid.integer_trigger())
    local _modulate = Patcher.grid.destination(Produce.grid.integer_trigger())

    return function(props)
        local i = props.track
        local out = eggs.track_dest[i]

        if eggs.view_focus ~= eggs.NORMAL then
            _grouper(nil, eggs.mapping, {
                x = 14, y = 2, levels = { 4, 15 },
                state = crops.of_param('grouper_'..i)
            })
        end

        if eggs.view_focus == eggs.KEY then
            do
                local id = chans:get_param_id(i, 'transposition', true)
                _transpose(id, eggs.mapping, {
                    x = 1, y = 1, size = 2, flow = 'right',
                    levels = { 4, 15 }, wrap = false,
                    min = params:lookup_param(id).min,
                    max = params:lookup_param(id).max,
                    state = eggs.of_param(id)
                })
            end
            do
                local id = chans:get_param_id(i, 'offset', true)
                _offset(id, eggs.mapping, {
                    x = 3, y = 1, size = 2, flow = 'right',
                    levels = { 2, 15 }, wrap = false,
                    min = params:lookup_param(id).controlspec.minval,
                    max = params:lookup_param(id).controlspec.maxval,
                    step = eggs.offset_volts_per_step,
                    state = eggs.of_param(id)
                })
            end
            do
                local id = chans:get_param_id(i, 'modulation', true)
                _modulate(id, eggs.mapping, {
                    x = 5, y = 1, size = 2, flow = 'right',
                    levels = { 4, 15 }, wrap = false,
                    min = params:lookup_param(id).min,
                    max = params:lookup_param(id).max,
                    state = eggs.of_param(id)
                })
            end
        elseif eggs.view_focus == eggs.SCALE then
            if crops.device == 'grid' and crops.mode == 'redraw' then
                local g = crops.handler

                local ivs = chans[i].intervals
                for i = channels.intervals_min,channels.intervals_max do
                    if not channels.base_exists[ivs][i] then
                        g:led(i, 1, 4)
                    end
                end
            end

            do
                local id = chans:get_param_id(i, 'mode', true)
                _mode(id, eggs.mapping, {
                    x = 1, y = 1, size = channels.intervals_max, min = 1, flow = 'right',
                    state = eggs.of_param(id, true)
                })
            end
            do
                local id = 'intervals_'..i
                _intervals(id, eggs.mapping, {
                    x = 1, y = 2, size = 7, levels = { 4, 15, 15 }, 
                    state = eggs.of_param(id, true)
                })
            end
        end
    end
end

local function Page(args)
    local track = args.track
    local _view_scale = Grid.momentary()
    local _view_key = Grid.momentary()
    
    local _mode_arq = Patcher.grid.destination(Grid.toggle())
    local _mode_latch = Patcher.grid.destination(Grid.toggle())

    local _slew_enable, _slew_time
    -- if out.param_ids.slew_enable then
        _slew_enable = Grid.momentary()
        _slew_time = Patcher.grid.destination(Grid.integer())
    -- end

    local _patrecs = { manual = {}, aux = {} }
    for i = 1, #eggs.pattern_groups[track].poly do
        _patrecs.manual[i] = Patcher.grid.destination(Produce.grid.pattern_recorder())
    end
    for i = 1, #eggs.pattern_groups[track].aux do
        _patrecs.aux[i] = Patcher.grid.destination(Produce.grid.pattern_recorder())
    end
    
    local _snapshots = {}
    for i = 1, eggs.snapshot_count do
        _snapshots[i] = {}
        _snapshots[i].latch = Patcher.grid.destination(Produce.grid.triggerhold())
        _snapshots[i].normal = Patcher.grid.destination(Grid.momentary())
    end
    local snapshots_normal_held = {}

    local _rate_rev = Rate_reverse()

    local _arq = Arq{
        arq = eggs.arqs[track],
        pattern_group = eggs.pattern_groups[track].arq,
        mute_group = eggs.pattern_keymap_shims[track].arq,
        snapshot_count = eggs.snapshot_count,
    }

    --TODO: becomes view transport
    local view_scroll = 0
    -- local _view_scroll = Grid.momentary()
    
    -- local _frets = Tune.grid.fretboard()
    local _tonic = Patcher.grid.destination(Tune.grid.tonic())
    
    local _fill = {
        slew_pulse = Grid.fill(), rev = Grid.fill(),
        rate_mark = Grid.fill(), loop = Grid.fill()
    }

    local _view = Patcher.grid.destination(Produce.grid.integer_trigger())

    local _scale_key = Scale_key()

    return function(props)
        local out = eggs.track_dest[track]
        local voicing = out.voicing
        local wide = props.wide
        local nudge = wide and -2 or 0

        if wide or view_scroll == 0 then
            _view_scale{
                x = wide and 13 or 8, y = 1, levels = { 4, 15 },
                state = crops.of_variable(
                    eggs.view_focus==eggs.SCALE and 1 or 0,
                    function(v)
                        eggs.view_focus = v>0 and eggs.SCALE or eggs.NORMAL
                        crops.dirty.grid = true
                        crops.dirty.screen = true
                    end
                )
            }
            _view_key{
                x = (wide and 14 or 8), y = wide and 1 or 2, levels = { 4, 15 },
                state = crops.of_variable(
                    eggs.view_focus==eggs.KEY and 1 or 0,
                    function(v)
                        eggs.view_focus = v>0 and eggs.KEY or eggs.NORMAL
                        crops.dirty.grid = true
                        crops.dirty.screen = true
                    end
                )
            }
        end

        local mode = params:get('mode_'..track)

        if eggs.view_focus == eggs.NORMAL then
            _mode_arq('mode_'..track, eggs.mapping, {
                x = wide and 6 or 3, y = 1, levels = { 4, 15 },
                state = crops.of_variable(
                    mode==eggs.ARQ and 1 or 0,
                    function(v)
                        params:set('mode_'..track, v==1 and eggs.ARQ or eggs.NORMAL)
                    end
                )
            })
            _mode_latch('mode_'..track, eggs.mapping, {
                x = wide and 7 or 5, y = 1, levels = { 4, 15 },
                state = crops.of_variable(
                    mode==eggs.LATCH and 1 or 0,
                    function(v)
                        params:set('mode_'..track, v==1 and eggs.LATCH or eggs.NORMAL)
                    end
                )
            })
            if wide then
                for i = 1, #eggs.pattern_groups[track].aux do
                    _patrecs.aux[i](nil, eggs.mapping, {
                        x = 12 + i - 1, y = 2,
                        pattern = eggs.pattern_groups[track].aux[i],
                    })
                end
            end

            --TODO: support view in mono keymap
            if mode==eggs.ARQ or voicing=='poly' then
                local id = 'view_'..track
                _view(nil, eggs.mapping, {
                    x = wide and 13 or 5, y = 2, size = 2, flow = 'right',
                    levels = { 0, 15 }, wrap = false,
                    min = params:lookup_param(id).min,
                    max = params:lookup_param(id).max,
                    state = crops.of_param(id, true)
                })
            end
        end

        if mode==eggs.ARQ then
            _fill.slew_pulse{ x = nudge + 3, y = 2, level = 4 }
            _fill.rev{ x = nudge + 4, y = 2, level = 4 }
            if wide then
                _fill.rate_mark{ x = nudge + 8, y = 2, level = 4 }
                _fill.loop{ x = nudge + 12, y = 2, level = 4 }
            end

            _arq{ 
                track = track, snapshots = eggs.snapshots[track].arq,
                wide = wide, view_scroll = view_scroll, out = out, rows = props.rows,
            }
        else
            local ss = eggs.snapshots[track][voicing] or {}

            if eggs.view_focus == eggs.NORMAL then
                if out.param_ids.slew_enable then
                    _slew_enable{
                        x = nudge + 3, y = 2, levels = { 4, 15 },
                        state = eggs.of_param(out.param_ids.slew_enable)
                    }
                end
                    

                for i = 1, wide and #eggs.pattern_groups[track].poly or 1 do
                    _patrecs.manual[i](nil, eggs.mapping, {
                        x = wide and (i) or 4, y = wide and 1 or 2,
                        pattern = eggs.pattern_groups[track][voicing][i],
                    })
                end
                
                if out.param_ids.slew_enable and params:get(out.param_ids.slew_enable) > 0 then
                    local id = out.param_ids.slew_time
                    _slew_time(id, eggs.mapping, {
                        x = nudge + 4, y = 2, size = wide and 8 or 4, min = 1,
                        state = wide and eggs.of_param(id, true) or crops.of_variable(
                            patcher.get_value(id) // 2 + 1,
                            function(v)
                                params:set(id, (v*2 - 1))
                            end
                        ),
                    })
                else
                    _fill.slew_pulse{ x = nudge + 3, y = 2, level = 2 }
                    _fill.rev{ x = nudge + 4, y = 2, level = 4 }
                    if wide then
                        _fill.rate_mark{ x = nudge + 8, y = 2, level = 4 }
                        _fill.loop{ x = nudge + 12, y = 2, level = 4 }
                    end

                    _rate_rev{
                        track = track, voicing = voicing, wide = wide,
                    }
                    -- if not wide then
                    --     _view_scroll{
                    --         x = nudge + 7, y = 2, levels = { 4, 15 },
                    --         state = crops.of_variable(view_scroll, function(v) 
                    --             view_scroll = v
                    --             crops.dirty.grid = true
                    --         end)
                    --     }
                    -- end
                end
            end

            if wide or props.view_scroll == 0 then
                for i = 1, wide and eggs.snapshot_count or 3 do
                    local filled = (ss[i] and next(ss[i]))

                    local function snapshot()
                        ss[i] = eggs.keymaps[track]:get()
                    end
                    local function clear_snapshot()
                        ss[i] = {}
                        -- eggs.keymaps[track]:clear()
                    end
                    local function recall()
                        eggs.keymaps[track]:set(ss[i] or {})
                    end

                    local xx = (wide and 8 or 5) + i - 1
                    
                    if mode==eggs.LATCH then
                        _snapshots[i].latch(nil, eggs.mapping, {
                            x = xx, y = 1,
                            levels = { filled and 4 or 0, filled and 15 or 8 },
                            action_tap = filled and recall or snapshot,
                            action_hold = clear_snapshot,
                        })
                    else
                        _snapshots[i].normal(nil, eggs.mapping, {
                            x = xx, y = 1,
                            levels = { filled and 4 or 0, filled and 15 or 8 },
                            state = crops.of_variable(snapshots_normal_held[i], function(v)
                                snapshots_normal_held[i] = v

                                if v > 0 then
                                    if filled then recall() 
                                    elseif next(eggs.keymaps[track]:get()) then snapshot() end
                                else
                                    eggs.keymaps[track]:set({})
                                end

                                crops.dirty.grid = true
                            end)
                        })
                    end
                end
            end
        end

        _scale_key{ track = track }
    end
end

local function UI(args)
    local wide = args.wide

    local _track = Grid.integer()

    local _pages = {}
    for track = 1,eggs.track_count do
        _pages[track] = Page{ track = track }
    end
    
    local _keymaps = {}
    for track = 1,eggs.track_count do
        _keymaps[track] = Keymaps{ track = track }
    end


    -- local _fill = {
    --     slew_pulse = Grid.fill(), rev = Grid.fill(),
    --     rate_mark = Grid.fill(), loop = Grid.fill()
    -- }

    return function(props)
        if wide or eggs.view_focus == eggs.NORMAL then 
            _track{
                x = wide and 15 or 1, y = 1, size = #_pages, 
                levels = { 2, props.focused and 15 or 4 },
                wrap = 2,
                state = { 
                    eggs.track_focus, 
                    function(v) 
                        eggs.track_focus = v

                        crops.dirty.grid = true 
                        crops.dirty.screen = true 
                    end
                },
                input = function(v, z)
                    if z==1 then
                        script_focus = 'eggs'

                        crops.dirty.screen = true
                        crops.dirty.grid = true
                    end
                end
            }
        end

        -- _fill.slew_pulse{ x = 3, y = 2, level = 4 }
        -- _fill.rev{ x = 4, y = 2, level = 4 }
        -- if wide then
        --     _fill.rate_mark{ x = 8, y = 2, level = 4 }
        --     _fill.loop{ x = 12, y = 2, level = 4 }
        -- end
        
        _keymaps[eggs.track_focus]{ levels = { 4, 8, 15 } }
    
        _pages[eggs.track_focus]{ wide = args.wide, rows = props.rows }
    end
end

local function App(args)
    local _ui = UI(args)

    return function()
        _ui{ focused = true, rows = 6 }
    end
end
    
return App, UI

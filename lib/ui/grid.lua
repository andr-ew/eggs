local function Arq(args)
    local _frets = Tune.grid.fretboard()
    local _keymap = Arqueggiator.grid.keymap()

    local arq = args.arq
    local mute_group = args.mute_group
    local pattern_group = args.pattern_group
    local snapshot_count = args.snapshot_count
    local out = args.out
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
    
    local _rate_mark = Patcher.grid.destination(Grid.fill())
    local _rate = Patcher.grid.destination(Grid.integer(), { levels = { nil, { 4, 8 } } })
    local _rate_small = Patcher.grid.destination(Produce.grid.integer_trigger())
    local _reverse = Patcher.grid.destination(Grid.toggle())
    local _loop = Patcher.grid.destination(Grid.toggle())
    local _pulse = Patcher.grid.destination(Grid.trigger())

    return function(props)
        local ss = props.snapshots
        local tune = props.tune
        local wide = props.wide

        if eggs.view_focus == eggs.NORMAL then
            for i = 1, wide and #pattern_group or 1 do
                _patrecs[i](nil, eggs.mapping, {
                    x = 4 + i - 1, y = 1,
                    pattern = pattern_group[i],
                })
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
                        x = (wide and 9 or 6) + i - 1, y = 1,
                        levels = { filled and 4 or 0, filled and 15 or 8 },
                        action_tap = filled and recall or snapshot,
                        action_hold = clear_snapshot,
                    })
                end
            end
            
            if #arq.sequence > 0 then
                do
                    local id = arq:pfix('pulse')
                    _pulse(id, eggs.mapping, {
                        x = 3, y = 2, levels = { 4, 15 },
                        input = function()
                            eggs.set_param(id, params:get(id) ~ 1)
                        end
                    })
                end
                do
                    local id = arq:pfix('reverse')
                    _reverse(id, eggs.mapping, {
                        x = 4, y = 2, levels = { 4, 15 },
                        state = eggs.of_param(id, true)
                    })
                end
                if wide then
                    _rate_mark(nil, eggs.mapping, {
                        x = 8, y = 2, level = 4,
                    })
                    do
                        local id = arq:pfix('division')
                        local stopped = params:get(id) == 1
                        _rate(id, eggs.mapping, {
                            x = 5, y = 2, size = 7, levels = { 0, stopped and 4 or 15 },
                            state = eggs.of_param(id, true)
                        })
                    end
                    do
                        local id = arq:pfix('loop')
                        _loop(id, eggs.mapping, {
                            x = 12, y = 2, levels = { 4, 15 },
                            state = eggs.of_param(id, true)
                        })
                    end
                else
                    local id = arq:pfix('division')
                    _rate_small(id, eggs.mapping, {
                        x = 5, y = 2, size = 2,
                        levels = { 0, 15 }, wrap = false,
                        min = 1, max = 7,
                        state = eggs.of_param(id, true)
                    })
                end
            end
        end

        _frets{
            x = 1, y = 8, size = eggs.keymap_size, wrap = eggs.keymap_wrap,
            flow = 'right', flow_wrap = 'up',
            levels = { 0, 1 },
            tune = tune,
            toct = 0, --?
            column_offset = out.column,
            row_offset = out.row,
        }
        _keymap{
            x = 1, y = 8, size = eggs.keymap_size, wrap = eggs.keymap_wrap,
            flow = 'right', flow_wrap = 'up', levels = { 4, 8, 15 }, 
            step = arq.step, gate = arq.gate,
            state = crops.of_variable(arq.sequence, set_arq),
            -- action_replace = function() arq:restart() end
        }
    end
end

local function Rate_reverse()
    local _reverse = Patcher.grid.destination(Grid.toggle())
    local _rate_mark = Patcher.grid.destination(Grid.fill())
    local _rate = Patcher.grid.destination(Grid.integer())
    local _loop = Patcher.grid.destination(Grid.toggle())
    local _rate_small = Patcher.grid.destination(Produce.grid.integer_trigger())

    return function(props)
        local pattern = props.mute_group:get_playing_pattern()
        local wide = props.wide

        if pattern then
            _reverse(nil, eggs.mapping, {
                x = 4, y = 2, levels = { 4, 15 },
                state = {
                    pattern.reverse and 1 or 0,
                    function(v)
                        pattern:set_reverse(v == 1)

                        crops.dirty.grid = true
                    end
                }
            })
            do
                local tf = pattern.time_factor
                local state_rate = {
                    (tf < 1) and ((1/tf) - 1) or ((-tf) + 1),
                    function(v)
                        pattern.time_factor = (v >= 0) and (1/(v + 1)) or (-(v - 1))

                        crops.dirty.grid = true
                    end
                }

                if wide then
                    _rate_mark(nil, eggs.mapping, {
                        x = 8, y = 2, level = 4,
                    })
                    _rate(nil, eggs.mapping, {
                        x = 5, y = 2, size = 7, min = -3,
                        state = state_rate
                    })
                    _loop(nil, eggs.mapping, {
                        x = 12, y = 2, levels = { 4, 15 },
                        state = {
                            pattern.loop and 1 or 0,
                            function(v)
                                pattern:set_loop(v == 1)

                                crops.dirty.grid = true
                            end
                        }
                    })
                else
                    _rate_small(nil, eggs.mapping, {
                        x = 5, y = 2, size = 2,
                        levels = { 0, 15 }, wrap = false,
                        min = -8, max = 8,
                        state = state_rate,
                    })
                end
            end
        end
    end
end

local function Page(args)
    local track = args.track
    local out = eggs.outs[track]
    local voicing = out.voicing
    local _view_scale = Grid.momentary()
    local _view_key = Grid.momentary()
    
    local _mode_arq = Patcher.grid.destination(Grid.toggle())
    local _mode_latch = Patcher.grid.destination(Grid.toggle())

    local _slew_enable, _slew_time
    if out.param_ids.slew_enable then
        _slew_enable = Grid.momentary()
        _slew_time = Patcher.grid.destination(Grid.integer())
    end

    local _patrecs = { manual = {}, aux = {} }
    for i = 1, #eggs.pattern_groups[track].manual do
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
        mute_group = eggs.pattern_shims[track].arq,
        snapshot_count = eggs.snapshot_count,
        out = out
    }

    local view_scroll = 0
    local _view_scroll = Grid.momentary()
    
    local _column = Patcher.grid.destination(Produce.grid.integer_trigger())
    local _row = Patcher.grid.destination(Produce.grid.integer_trigger())

    local _frets = Tune.grid.fretboard()
    local _keymap = Keymap.grid[voicing]()

    local _tonic = Patcher.grid.destination(Tune.grid.tonic())
    
    local _degs_bg = Patcher.grid.destination(Tune.grid.scale_degrees_background())
    local _degs = {}
    for i = 1, 12 do 
        _degs[i] = Patcher.grid.destination(Tune.grid.scale_degree())
    end

    return function(props)
        local tune = eggs.tunes[params:get(out.param_ids.tuning_preset)]
        local wide = props.wide

        if wide or view_scroll == 0 then
            _view_scale{
                x = wide and 15 or 8, y = 1, levels = { 2, 15 },
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
                x = wide and 15 or 8, y = 2, levels = { 2, 15 },
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
                x = 3, y = 1, levels = { 4, 15 },
                state = crops.of_variable(
                    mode==eggs.ARQ and 1 or 0,
                    function(v)
                        params:set('mode_'..track, v==1 and eggs.ARQ or eggs.NORMAL)
                    end
                )
            })
            _mode_latch('mode_'..track, eggs.mapping, {
                x = wide and 8 or 5, y = 1, levels = { 4, 15 },
                state = crops.of_variable(
                    mode==eggs.LATCH and 1 or 0,
                    function(v)
                        params:set('mode_'..track, v==1 and eggs.LATCH or eggs.NORMAL)
                    end
                )
            })
        end

        if mode==eggs.ARQ then
            _arq{ 
                track = track, snapshots = eggs.snapshots[track].arq, tune = tune, 
                wide = wide, view_scroll = view_scroll,
            }
        else
            if eggs.view_focus == eggs.NORMAL then
                if _slew_enable then
                    _slew_enable{
                        x = 3, y = 2, levels = { 4, 15 },
                        state = eggs.of_param(out.param_ids.slew_enable)
                    }
                end
                    
                local ss = eggs.snapshots[track].manual

                for i = 1, wide and #eggs.pattern_groups[track].manual or 1 do
                    _patrecs.manual[i](nil, eggs.mapping, {
                        x = 4 + i - 1, y = 1,
                        pattern = eggs.pattern_groups[track].manual[i],
                    })
                end
                
                if out.param_ids.slew_enable and params:get(out.param_ids.slew_enable) > 0 then
                    local id = out.param_ids.slew_time
                    _slew_time(id, eggs.mapping, {
                        x = 4, y = 2, size = wide and 8 or 4, min = 1,
                        state = wide and eggs.of_param(id, true) or crops.of_variable(
                            patcher.get_value(id) // 2 + 1,
                            function(v)
                                params:set(id, (v*2 - 1))
                            end
                        ),
                    })
                else
                    _rate_rev{
                        mute_group = eggs.mute_groups[track].manual, wide = wide,
                    }
                    if not wide then
                        _view_scroll{
                            x = 7, y = 2, levels = { 4, 15 },
                            state = crops.of_variable(view_scroll, function(v) 
                                view_scroll = v
                                crops.dirty.grid = true
                            end)
                        }
                    end
                end

                if wide or view_scroll == 0 then
                    for i = 1, wide and eggs.snapshot_count or 2 do
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
                        
                        if mode==eggs.LATCH then
                            _snapshots[i].latch(nil, eggs.mapping, {
                                x = (wide and 9 or 6) + i - 1, y = 1,
                                levels = { filled and 4 or 0, filled and 15 or 8 },
                                action_tap = filled and recall or snapshot,
                                action_hold = clear_snapshot,
                            })
                        else
                            _snapshots[i].normal(nil, eggs.mapping, {
                                x = (wide and 9 or 6) + i - 1, y = 1,
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

            _frets{
                x = 1, y = 8, size = eggs.keymap_size, wrap = eggs.keymap_wrap,
                flow = 'right', flow_wrap = 'up',
                levels = { 0, 4 },
                tune = tune,
                toct = 0, --?
                column_offset = out.column,
                row_offset = params:get(out.param_ids.row),
            }
            _keymap{
                x = 1, y = 8, size = eggs.keymap_size, wrap = eggs.keymap_wrap,
                flow = 'right', flow_wrap = 'up',
                levels = { 0, 15 },
                state = eggs.keymaps[track]:get_state(),
                mode = eggs.mode_names[mode]
            }
        end

        if wide or view_scroll > 0 then
            local id = out.param_ids.row
            _row(id, eggs.mapping, {
                x = wide and 16 or 8, y = 2, flow = 'up', size = 2,
                levels = { 4, 15 }, wrap = false,
                min = params:lookup_param(id).min,
                max = params:lookup_param(id).max,
                state = eggs.of_param(id)
            })
        end

        if eggs.view_focus == eggs.NORMAL then 
            if (wide or view_scroll > 0) then
                local id = out.param_ids.column
                _column(id, eggs.mapping, {
                    x = wide and 13 or 6, y = 1, size = 2,
                    levels = { 4, 15 }, wrap = false,
                    min = params:lookup_param(id).controlspec.minval,
                    max = params:lookup_param(id).controlspec.maxval,
                    step = eggs.volts_per_column,
                    state = eggs.of_param(id)
                })
            end
            if wide then
                for i = 1, #eggs.pattern_groups[track].aux do
                    _patrecs.aux[i](nil, eggs.mapping, {
                        x = 13 + i - 1, y = 2,
                        pattern = eggs.pattern_groups[track].aux[i],
                    })
                end
            end
        elseif eggs.view_focus == eggs.SCALE then
            _degs_bg(nil, eggs.mapping, {
                left = wide and 3 or 1, top = 1, level = 4,
                -- width = 7, nudge = 6, -- 8x8 sizing
                width = wide and 12 or 7, nudge = wide and 3 or 6,
            })
            for i,_deg in ipairs(_degs) do
                local id = tune:get_param_id('enable_'..i)
                _deg(id, eggs.mapping, {
                    left = wide and 3 or 1, top = 1, levels = { 8, 15 },
                    tune = tune, degree = i, 
                    -- width = 7, nudge = 6, -- 8x8 sizing
                    width = wide and 12 or 7, nudge = wide and 3 or 6,
                    state = eggs.of_param(id),
                })
            end
        elseif eggs.view_focus == eggs.KEY then
            --TODO: support pattern recording & retriggers as I did in ndls
            local id = tune:get_param_id('tonic')
            _tonic(id, eggs.mapping, {
                left = wide and 3 or 1, top = 1, levels = { 4, 15 },
                -- width = 7, nudge = 6, -- 8x8 sizing
                width = wide and 12 or 7, nudge = wide and 3 or 6,
                -- state = Tune.of_param(eggs.get_tune(track), 'tonic'), 
                state = crops.of_variable(
                    params:get(id), 
                    function(v)
                        params:set(id, v, true) 
                        params:lookup_param(id):bang()
                    end
                ),
                tune = tune,
            })
        end
    end
end

local function App(args)
    local _track = Grid.integer()

    local _pages = {}
    for track = 1,eggs.track_count do
        _pages[track] = Page{ track = track }
    end

    return function()
        if wide or eggs.view_focus == eggs.NORMAL then 
            _track{
                x = 1, y = 1, size = #_pages, levels = { 0, 15 },
                wrap = 2,
                state = { 
                    eggs.track_focus, 
                    function(v) 
                        eggs.track_focus = v

                        crops.dirty.grid = true 
                        crops.dirty.screen = true 
                    end
                }
            }
        end
    
        _pages[eggs.track_focus]{ wide = args.wide }
    end
end
    
return App

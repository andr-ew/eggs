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
        _patrecs[i] = Produce.grid.pattern_recorder()
    end

    local _snapshots = {}
    for i = 1, eggs.snapshot_count do
        _snapshots[i] = Produce.grid.triggerhold()
    end
    
    local _rate_mark = Grid.fill()
    local _rate = Grid.integer()
    local _rate_small = Produce.grid.integer_trigger()
    local _reverse = Grid.toggle()
    local _loop = Grid.toggle()

    return function(props)
        local ss = props.snapshots
        local tune = props.tune
        local wide = props.wide

        if eggs.view_focus == eggs.NORMAL then
            for i = 1, wide and #pattern_group or 1 do
                _patrecs[i]{
                    x = 4 + i - 1, y = 1,
                    pattern = pattern_group[i],
                }
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
                    _snapshots[i]{
                        x = (wide and 9 or 6) + i - 1, y = 1,
                        levels = { filled and 4 or 0, filled and 15 or 8 },
                        action_tap = filled and recall or snapshot,
                        action_hold = clear_snapshot,
                    }
                end
            end
            
            if #arq.sequence > 0 then
                _reverse{
                    x = 4, y = 2, levels = { 4, 15 },
                    state = eggs.of_param(arq:pfix('reverse'))
                }
                if wide then
                    _rate_mark{
                        x = 8, y = 2, level = 4,
                    }
                    _rate{
                        x = 5, y = 2, size = 7,
                        state = eggs.of_param(arq:pfix('division'))
                    }
                    _loop{
                        x = 12, y = 2, levels = { 4, 15 },
                        state = eggs.of_param(arq:pfix('loop'))
                    }
                else
                    _rate_small{
                        x_next = 6, y_next = 2,
                        x_prev = 5, y_prev = 2,
                        levels = { 0, 15 }, wrap = false,
                        min = 1, max = 7,
                        state = eggs.of_param(arq:pfix('division'))
                    }
                end
            end
        end

        _frets{
            x = 1, y = 8, size = eggs.keymap_size, wrap = eggs.keymap_wrap,
            flow = 'right', flow_wrap = 'up',
            levels = { 0, 1 },
            tune = tune,
            toct = params:get(out.param_ids.oct),
            column_offset = params:get(out.param_ids.column),
            row_offset = params:get(out.param_ids.row),
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
    local _reverse = Grid.toggle()
    local _rate_mark = Grid.fill()
    local _rate = Grid.integer()
    local _loop = Grid.toggle()
    local _rate_small = Produce.grid.integer_trigger()

    return function(props)
        local pattern = props.mute_group:get_playing_pattern()
        local wide = props.wide

        if pattern then
            _reverse{
                x = 4, y = 2, levels = { 4, 15 },
                state = {
                    pattern.reverse and 1 or 0,
                    function(v)
                        pattern:set_reverse(v == 1)

                        crops.dirty.grid = true
                    end
                }
            }
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
                    _rate_mark{
                        x = 8, y = 2, level = 4,
                    }
                    _rate{
                        x = 5, y = 2, size = 7, min = -3,
                        state = state_rate
                    }
                    _loop{
                        x = 12, y = 2, levels = { 4, 15 },
                        state = {
                            pattern.loop and 1 or 0,
                            function(v)
                                pattern:set_loop(v == 1)

                                crops.dirty.grid = true
                            end
                        }
                    }
                else
                    _rate_small{
                        x_next = 6, y_next = 2,
                        x_prev = 5, y_prev = 2,
                        levels = { 0, 15 }, wrap = false,
                        min = -8, max = 8,
                        state = state_rate,
                    }
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
    
    local _mode_arq = Grid.toggle()
    local _mode_latch = Grid.toggle()

    local _slew_enable, _slew_time
    if out.param_ids.slew_enable then
        _slew_enable = Grid.momentary()
        _slew_time = Grid.integer()
    end

    local _patrecs = {}
    for i = 1, #eggs.pattern_groups[track].manual do
        _patrecs[i] = Produce.grid.pattern_recorder()
    end
    
    local _snapshots = {}
    for i = 1, eggs.snapshot_count do
        _snapshots[i] = {}
        _snapshots[i].latch = Produce.grid.triggerhold()
        _snapshots[i].normal = Grid.momentary() 
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
    
    local _column = Produce.grid.integer_trigger()
    local _row = Produce.grid.integer_trigger()

    local _frets = Tune.grid.fretboard()
    local _keymap = Keymap.grid[voicing]()

    local _tonic = Tune.grid.tonic()
    
    local _degs_bg = Tune.grid.scale_degrees_background()
    local _degs = {}
    for i = 1, 12 do 
        _degs[i] = Tune.grid.scale_degree()
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
            _mode_arq{
                x = 3, y = 1, levels = { 4, 15 },
                state = crops.of_variable(
                    mode==eggs.ARQ and 1 or 0,
                    function(v)
                        params:set('mode_'..track, v==1 and eggs.ARQ or eggs.NORMAL)
                    end
                )
            }
            _mode_latch{
                x = wide and 8 or 5, y = 1, levels = { 4, 15 },
                state = crops.of_variable(
                    mode==eggs.LATCH and 1 or 0,
                    function(v)
                        params:set('mode_'..track, v==1 and eggs.LATCH or eggs.NORMAL)
                    end
                )
            }
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
                    _patrecs[i]{
                        x = 4 + i - 1, y = 1,
                        pattern = eggs.pattern_groups[track].manual[i],
                    }
                end
                
                if out.param_ids.slew_enable and params:get(out.param_ids.slew_enable) > 0 then
                    local id = out.param_ids.slew_time
                    _slew_time{
                        x = 4, y = 2, size = wide and 8 or 4, min = 1,
                        state = wide and eggs.of_param(id) or crops.of_variable(
                            params:get(id) // 2 + 1,
                            function(v)
                                params:set(id, (v*2 - 1))
                            end
                        ),
                    }
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
                            _snapshots[i].latch{
                                x = (wide and 9 or 6) + i - 1, y = 1,
                                levels = { filled and 4 or 0, filled and 15 or 8 },
                                action_tap = filled and recall or snapshot,
                                action_hold = clear_snapshot,
                            }
                        else
                            _snapshots[i].normal{
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
                            }
                        end
                    end
                end
            end

            _frets{
                x = 1, y = 8, size = eggs.keymap_size, wrap = eggs.keymap_wrap,
                flow = 'right', flow_wrap = 'up',
                levels = { 0, 4 },
                tune = tune,
                toct = params:get(out.param_ids.oct),
                column_offset = params:get(out.param_ids.column),
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
            _row{
                x_next = wide and 16 or 8, y_next = 1,
                x_prev = wide and 16 or 8, y_prev = 2,
                levels = { 4, 15 }, wrap = false,
                min = params:lookup_param(id).min,
                max = params:lookup_param(id).max,
                state = eggs.of_param(id)
            }
        end

        if eggs.view_focus == eggs.NORMAL then 
            if (wide or view_scroll > 0) then
                local id = out.param_ids.column
                _column{
                    x_next = wide and 14 or 7, y_next = 1,
                    x_prev = wide and 13 or 6, y_prev = 1,
                    levels = { 4, 15 }, wrap = false,
                    min = params:lookup_param(id).min,
                    max = params:lookup_param(id).max,
                    state = eggs.of_param(id)
                } 
            end
        elseif eggs.view_focus == eggs.SCALE then
            _degs_bg{
                left = wide and 3 or 1, top = 1, level = 4,
                -- width = 7, nudge = 6, -- 8x8 sizing
                width = wide and 12 or 7, nudge = wide and 3 or 6,
            }
            for i,_deg in ipairs(_degs) do
                _deg{
                    left = wide and 3 or 1, top = 1, levels = { 8, 15 },
                    tune = tune, degree = i, 
                    -- width = 7, nudge = 6, -- 8x8 sizing
                    width = wide and 12 or 7, nudge = wide and 3 or 6,
                    state = eggs.of_param(tune:get_param_id('enable_'..i)),
                }
            end
        elseif eggs.view_focus == eggs.KEY then
            --TODO: support pattern recording & retriggers as I did in ndls
            _tonic{
                left = wide and 3 or 1, top = 1, levels = { 4, 15 },
                -- width = 7, nudge = 6, -- 8x8 sizing
                width = wide and 12 or 7, nudge = wide and 3 or 6,
                -- state = Tune.of_param(eggs.get_tune(track), 'tonic'), 
                state = crops.of_variable(
                    params:get(tune:get_param_id('tonic')), 
                    function(v)
                        params:set(tune:get_param_id('tonic'), v, true) 
                        params:lookup_param(tune:get_param_id('tonic')):bang()
                    end
                ),
                tune = tune,
            }
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

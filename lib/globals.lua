local eggs = {}                                               

do
    local mar = { left = 2, top = 1, right = 6, bottom = 2 }
    local top, bottom = mar.top, 64-mar.bottom
    local left, right = mar.left, 128-mar.right
    local w = 128 - mar.left - mar.right
    local h = 64 - mar.top - mar.bottom
    local mul = { x = (right - left) / 2, y = (bottom - top) / 2 }
    local x = { left, 128/2, [1.5] = 24, right  }
    local y = { top, bottom - 22, bottom, [1.5] = 20, }
    eggs.x, eggs.y, eggs.w, eggs.h = x, y, w, h

    eggs.e = {
        { x = x[1], y = y[1] + 5 },
        { x = x[1], y = mar.top + h*(6.75/8) },
        { x = x[2], y = mar.top + h*(6.75/8) },
    }
    eggs.k = {
        {},
        { x = x[1], y = mar.top + h*(8/8) },
        { x = x[2], y = mar.top + h*(8/8) },
    }
end

eggs.track_count = 4
eggs.track_focus = 1

eggs.mapping = false

eggs.NORMAL, eggs.SCALE, eggs.KEY = 1, 2, 3
eggs.view_focus = eggs.NORMAL

eggs.change_engine_modal = false
eggs.current_engine = nil

local macros_per_page = 3
eggs.macro_page_count = 3
eggs.macro_count = eggs.macro_page_count * macros_per_page

local ccs_per_page = 2
eggs.cc_page_count = 3
eggs.cc_count = eggs.cc_page_count * ccs_per_page

-- eggs.engine_loaded = false

local tune_count = 8
eggs.tunes = {}

--TODO: byebye
for i = 1,tune_count do
    eggs.tunes[i] = tune.new{ 
        tunings = tunings, id = i,
        scale_groups = scale_groups,
        add_param_separator = false,
        add_param_group = true,
        action = function() 
            crops.dirty.grid = true 
            crops.dirty.screen = true
        end
    }
end

local function process_param(id, v) 
    params:set(id, v) 
end

eggs.set_param = function(id, v)
    local t = { 'param', id, v }
    process_param(id, v)

    -- for i,mute_groups in ipairs(eggs.mute_groups) do
    --     for k,mute_group in pairs(mute_groups) do
    --         mute_group:watch(t)
    --     end
    -- end
    for i = 1,eggs.track_count do
        for k,_ in pairs(eggs.pattern_groups[i]) do
            for ii,pat in ipairs(eggs.pattern_groups[i][k]) do
                pat:watch(t)
            end
        end
    end
end

local pat_count = { mono = 4, poly = 4, arq = 4, aux = 1 }
eggs.pattern_groups = {}
-- eggs.pattern_param_shims = {}
eggs.pattern_factories = {}
eggs.mute_groups = {}
eggs.pattern_keymap_shims = {}
eggs.arq_setters = {}

for i = 1,eggs.track_count do
    eggs.pattern_groups[i] = { mono = {}, poly = {}, arq = {}, aux = {} }
    for k,_ in pairs(eggs.pattern_groups[i]) do
        for ii = 1,pat_count[k] do
            eggs.pattern_groups[i][k][ii] = pattern_time.new()
        end
    end
    
    eggs.pattern_factories[i] = {}
    for _,k in ipairs({ 'mono', 'poly', 'arq' }) do
        eggs.pattern_factories[i][k] = pattern_param_factory:new(
            'pattern_track_'..i..'_'..k, 'group', eggs.pattern_groups[i][k]
        )
    end
    eggs.pattern_factories[i].aux = {}
    for ii = 1,pat_count.aux do
        eggs.pattern_factories[i].aux[ii] = pattern_param_factory:new(
            'pattern_track_'..i..'_aux_'..ii, 'single', eggs.pattern_groups[i].aux[ii]
        )
    end

    -- eggs.pattern_param_shims[i] = {}
    -- for _,k in ipairs({ 'mono', 'poly', 'arq' }) do
    --     eggs.pattern_param_shims[i][k] = eggs.pattern_factories[i][k]:get_shim(eggs.set_param)
    -- end

    eggs.mute_groups[i] = {}
    for _,k in ipairs({ 'mono', 'poly', 'arq' }) do
        eggs.mute_groups[i][k] = mute_group.new(eggs.pattern_groups[i][k])
        -- eggs.mute_groups[i][k] = mute_group.new(eggs.pattern_param_shims[i][k])
    end

    eggs.pattern_keymap_shims[i] = {}
    --TODO: bye
    --TODO: bye
    for k,mute_group in pairs(eggs.mute_groups[i]) do
        local shim = {}

        shim.watch = function(shim, value)
            mute_group:watch({ 'keymap', value })
        end
        shim.set_all_hooks = function(shim, ...)
            mute_group:set_all_hooks(...)
        end
        shim.stop = function(shim, ...)
            mute_group:stop(...)
        end

        mute_group.process = function(t)
            if t[1] == 'param' then process_param(t[2], t[3])
            elseif t[1] == 'keymap' then shim.process(t[2]) end
        end

        eggs.pattern_keymap_shims[i][k] = shim
    end

    for _,pat in ipairs(eggs.pattern_groups[i].aux) do
        pat.process = function(t)
            if t[1] == 'param' then process_param(t[2], t[3]) end
        end
    end

    do
        local track = i

        local mute_group = eggs.pattern_keymap_shims[track].arq
        local function process_arq(new)
            eggs.arqs[track]:set_sequence(new)

            crops.dirty.grid = true;
        end
        mute_group.process = process_arq

        eggs.arq_setters[track] = function(new)
            process_arq(new)
            mute_group:watch(new)
        end
    end
end

function eggs.of_param(id, sum_dest)
    return {
        sum_dest and patcher.get_value(id) or params:get(id),
        eggs.set_param, id,
    }
end

-- eggs.keymap_size = 128-16-16
-- eggs.keymap_wrap = 16
eggs.keymap_view_width = 16
eggs.keymap_columns = eggs.keymap_view_width * 3
eggs.keymap_rows = 8 - 2
eggs.keymap_view_height = eggs.keymap_rows
eggs.keymap_wrap = eggs.keymap_columns
eggs.keymap_size = eggs.keymap_columns * eggs.keymap_rows

eggs.max_intervals = 7

eggs.NORMAL, eggs.LATCH, eggs.ARQ = 1, 2, 3
eggs.mode_names = { 'normal', 'latch', 'arq' }

eggs.snapshot_count = 4

eggs.offset_volts_per_step = 1/8

eggs.img_path = norns.state.lib..'img/'
    
eggs.arqs = {}
eggs.snapshots = {}
for i = 1,eggs.track_count do
    local arq = arqueggiator.new(i)

    eggs.arqs[i] = arq

    eggs.snapshots[i] = { mono = {}, poly = {}, arq = {} }
end

eggs.channels = channels.new(eggs.track_count)


function eggs.noteOn(note_number, hz) end
function eggs.noteOff(note_number) end

eggs.track_dest = {}
eggs.keymaps = {}

function eggs.get_view(track)
    -- return util.clamp(5 + params:get('view_'..track), 0, eggs.keymap_columns - eggs.keymap_view_width)
    return util.clamp(params:get('intervals_'..track) + params:get('view_'..track), 0, eggs.keymap_columns - eggs.keymap_view_width)
end

function eggs.set_dest(track, v)
    local i = track
    
    if eggs.keymaps[i] then eggs.keymaps[i]:clear() end

    eggs.track_dest[i] = eggs.dests[i][v]
    eggs.track_dest[i].track = i

    local out = eggs.track_dest[i]
    local voicing = out.voicing
    local poly = voicing == 'poly'
    local mono = voicing == 'mono'

    local function poly_note_on(idx)
        local semitones = eggs.channels:get_semitones(i, idx)
        eggs.track_dest[i]:note_on(idx, semitones)
    end
    local function poly_note_off(idx)
        local semitones = eggs.channels:get_semitones(i, idx)
        eggs.track_dest[i]:note_off(idx, semitones) 
    end
    local function mono_setter(idx, gate)
        eggs.channels:set_note(i, idx, gate)
    end

    eggs.keymaps[i] = keymap[voicing].new{
        action_on = poly and poly_note_on,
        action_off = poly and poly_note_off,
        action = mono and mono_setter,
        pattern = eggs.pattern_keymap_shims[i][voicing],
        size = eggs.keymap_size,
    }

    eggs.arqs[i].action_on = poly and poly_note_on or (
        function(idx) mono_setter(idx, 1) end
    )
    eggs.arqs[i].action_off = poly and poly_note_off or (
        function(idx) mono_setter(idx, 0) end
    )

    eggs.channels[i].action = poly and function()
        eggs.keymaps[i]:clear()
        eggs.track_dest[i]:kill_all()
    end or function(semitones, gate)
        eggs.track_dest[i]:set_note(semitones, gate)
    end
end

return eggs

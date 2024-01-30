local eggs = {}                                               

do
    local mar = { left = 2, top = 7, right = 2, bottom = 2 }
    local top, bottom = mar.top, 64-mar.bottom
    local left, right = mar.left, 128-mar.right
    local w = 128 - mar.left - mar.right
    local h = 64 - mar.top - mar.bottom
    local mul = { x = (right - left) / 2, y = (bottom - top) / 2 }
    local x = { left, left + 128/2, [1.5] = 24  }
    local y = { top, bottom - 22, bottom, [1.5] = 20, }
    eggs.x, eggs.y, eggs.w, eggs.h = x, y, w, h

    eggs.e = {
        { x = x[1], y = y[1] },
        { x = x[1], y = mar.top + h*(5.5/8) },
        { x = x[2], y = mar.top + h*(5.5/8) },
    }
    eggs.k = {
        {},
        { x = x[1], y = mar.top + h*(7/8) },
        { x = x[2], y = mar.top + h*(7/8) },
    }
end

eggs.track_count = 4
eggs.track_focus = 1

eggs.mapping = false

eggs.NORMAL, eggs.SCALE, eggs.KEY = 1, 2, 3
eggs.view_focus = eggs.NORMAL

local tune_count = 8
eggs.tunes = {}

for i = 1,tune_count do
    eggs.tunes[i] = tune.new{ 
        tunings = tunings, id = i,
        scale_groups = scale_groups,
        add_param_separator = false,
        add_param_group = true,
        visibility_condition = function() 
            local visible = false

            for track = 1,eggs.track_count do
                if params:get(eggs.outs[track].param_ids.tuning_preset) == i then
                    visible = true
                    break
                end
            end

            return visible
        end,
        action = function() 
            crops.dirty.grid = true 
            crops.dirty.screen = true
        end
    }
end

local function process_param(id, v) 
    params:set(id, v) 
end

local pat_count = 4
eggs.pattern_groups = {}
eggs.mute_groups = {}
eggs.pattern_shims = {}

for i = 1,eggs.track_count do
    eggs.pattern_groups[i] = { manual = {}, arq = {} }
    for k,_ in pairs(eggs.pattern_groups[i]) do
        for ii = 1,pat_count do
            eggs.pattern_groups[i][k][ii] = pattern_time.new()
        end
    end

    eggs.mute_groups[i] = {
        manual = mute_group.new(eggs.pattern_groups[i].manual),
        arq = mute_group.new(eggs.pattern_groups[i].arq),
    }

    eggs.pattern_shims[i] = {}
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

        eggs.pattern_shims[i][k] = shim
    end
end

eggs.set_param = function(id, v)
    local t = { 'param', id, v }
    process_param(id, v)

    for i,mute_groups in ipairs(eggs.mute_groups) do
        for k,mute_group in pairs(mute_groups) do
            mute_group:watch(t)
        end
    end
end

function eggs.of_param(id, is_dest)
    return {
        params:get(id),
        eggs.set_param, id,
    }
end

eggs.keymap_size = 128-16-16
eggs.keymap_wrap = 16

eggs.NORMAL, eggs.LATCH, eggs.ARQ = 1, 2, 3
eggs.mode_names = { 'normal', 'latch', 'arq' }

eggs.snapshot_count = 4
    
eggs.arqs = {}
eggs.snapshots = {}
for i = 1,eggs.track_count do
    local arq = arqueggiator.new(i)

    eggs.arqs[i] = arq

    eggs.snapshots[i] = { manual = {}, arq = {} }
end

return eggs

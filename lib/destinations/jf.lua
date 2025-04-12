local dest = {}
        
local NOTE, PITCH = 1, 2
local note_mode_names = { 'note', 'pitch' }

dest.preset = 2
dest.oct = 0
dest.column = 0
dest.row = -2

local shift = 0
local level = 3.5
local robin = 1
local note_mode = NOTE
local held = {}

dest.voicing = 'poly'

local function get_volts(idx)
    local semitones = eggs.channels:get_semitones(dest.track, idx, dest.column)
    return semitones/12 - 2
end

dest.note_on = function(_, idx)
    local volts = get_volts(idx)
    local vel = math.random()*0.2 + 0.85

    if note_mode == NOTE then
        table.insert(held, { idx = idx, volts = volts, vel = vel })
        crow.ii.jf.play_note(volts, level * vel)
    elseif note_mode == PITCH then
        crow.ii.jf.pitch(robin, volts)
        robin = robin%6 + 1
    end
end
dest.note_off = function(_, idx) 
    local volts = get_volts(idx)

    for i,h in ipairs(held) do if h.volts==volts then
        table.remove(held, i)
        break
    end end

    crow.ii.jf.play_note(volts, 0)
end

local function update_notes()
    for i,h in ipairs(held) do
        crow.ii.jf.play_note(h.volts, 0)

        local new_volts = get_volts(h.idx)
        h.volts = new_volts
        crow.ii.jf.play_note(new_volts, level * h.vel)
    end
end

dest.update_notes = update_notes

-- local function setup()
--     crow.ii.jf.event = function(e, value)
--         tab.print(e)
--         print('value', value)
--     end
-- end
-- setup()

local param_ids = {
    tuning_preset = 'tuning_preset_jf_dest',
    oct = 'oct_jf_dest',
    row = 'row_jf_dest',
    column = 'column_jf_dest',
    mode = 'mode_jf_dest',
    level = 'level_jf_dest',
    shift = 'shift_jf_dest',
    run = 'run_jf_dest',
    run_mode = 'run_mode_jf_dest',
    god_mode = 'god_mode_jf_dest',
    note_mode = 'note_mode_jf_dest',
    panic = 'panic_jf_dest',
}
dest.param_ids = param_ids
        
dest.name = 'just friends'
dest.shortname = 'jf'

dest.params_count = 12

dest.add_params = function(_)
    patcher.add_destination_and_param{
        id = param_ids.shift, name = 'shift',
        type = 'control', 
        controlspec = cs.def{ min = -5, max = 5, default = 0 },
        action = function(v)
            shift = math.log(math.max(0.00001, ((v / 5) * 5/12) + 1) * math.exp(1)) - 1

            crow.ii.jf.transpose(shift)
            crops.dirty.screen = true
        end
    }
    patcher.add_destination_and_param{
        id = param_ids.level, name = 'lvl',
        type = 'control', 
        controlspec = cs.def{ min = 0, max = 5, default = level },
        action = function(v)
            level = v
            crops.dirty.screen = true
        end
    }
    patcher.add_destination_and_param{
        id = param_ids.run, name = 'run',
        type = 'control', 
        controlspec = cs.def{ min = -5, max = 5, default = 0, quantum = 1/100/10 },
        action = function(v)
            crow.ii.jf.run(v)
            
            crops.dirty.screen = true
        end
    }
    params:add{
        id = param_ids.run_mode, name = 'run mode',
        type = 'binary', 
        behavior = 'toggle', default = 1,
        action = function(v)
            crow.ii.jf.run_mode(v)
            crops.dirty.screen = true
        end
    }
    params:add{
        id = param_ids.mode, name = 'synth',
        type = 'binary', 
        behavior = 'toggle', default = 1,
        action = function(v)
            crow.ii.jf.mode(v)
            crops.dirty.screen = true
        end
    }
    params:add{
        id = param_ids.god_mode, name = 'god mode',
        type = 'binary', 
        behavior = 'toggle', default = 0,
        action = function(v)
            crow.ii.jf.god_mode(v)
            crops.dirty.screen = true
        end
    }
    --TODO: clear held{} table ???
    params:add{
        id = param_ids.panic, name = 'panic !',
        type = 'binary', behavior = 'trigger',
        action = function()
            for i = 1,6 do crow.ii.jf.trigger(i, 0) end

            crops.dirty.screen = true
        end
    }
    params:add{
        id = param_ids.note_mode, name = 'note mode',
        type = 'option', options = note_mode_names, default = NOTE,
        action = function(v)
            note_mode = v
            crops.dirty.screen = true
        end,
    }
    
    params:add{
        type = 'number', id = param_ids.tuning_preset, name = 'tuning preset',
        min = 1, max = #eggs.tunes, default = dest.preset, 
        action = function(v) 
            dest.preset = v; update_notes()

            for _,t in ipairs(eggs.tunes) do
                t:update_tuning()
            end 
        end,
    }
    params:add{
        type = 'number', id = param_ids.oct, name = 'oct',
        min = -5, max = 5, default = dest.oct,
        action = function(v) 
            dest.oct = v; update_notes()

            crops.dirty.grid = true 
        end
    }
    do
        local min, max = -12, 12
        patcher.add_destination_and_param{
            type = 'control', id = param_ids.column, name = 'column',
            controlspec = cs.def{ 
                min = min, max = max, default = dest.column * eggs.volts_per_column, 
                quantum = (1/(max - min)) * eggs.volts_per_column, units = 'v',
            },
            action = function(v) 
                local last = dest.column
                dest.column = v // eggs.volts_per_column

                if last ~= dest.column then update_notes() end

                crops.dirty.grid = true 
                crops.dirty.screen = true 
            end
        }
    end
    patcher.add_destination_and_param{
        type = 'number', id = param_ids.row, name = 'row',
        min = -16, max = 16, default = dest.row,
        action = function(v) 
            local last = dest.row
            dest.row = v
                
            if last ~= dest.row then update_notes() end

            crops.dirty.grid = true 
            crops.dirty.screen = true 
        end
    }
end
        
dest.Components = { norns = {} }

dest.Components.norns.page = function()
    local _e1 = Components.enc_screen.param()
    local _e2 = Components.enc_screen.param()
    local _e3 = Components.enc_screen.param()

    local _k2 = Components.key_screen.param()
    local _k3 = Components.key_screen.param()

    return function()
        _e1{ id = param_ids.shift, n = 1 }
        _e2{ id = param_ids.level, n = 2 }
        _e3{ id = param_ids.run, n = 3 }
        
        _k2{ id = param_ids.mode, id_hold = param_ids.run_mode, n = 2, is_dest = false }
        _k3{ id = param_ids.panic, id_hold = param_ids.god_mode, n = 3, is_dest = false }
    end
end

return dest

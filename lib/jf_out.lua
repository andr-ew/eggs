local jf_out = {}
        
local NOTE, PITCH = 1, 2
local note_mode_names = { 'note', 'pitch' }

local preset = 2
local oct = 0
local column = 0
local row = -2
local shift = 0
local level = 3.5
local robin = 1
local note_mode = NOTE
local held = {}

jf_out.voicing = 'poly'

local function get_volts(idx)
    local x = (idx-1)%eggs.keymap_wrap + 1 + column 
    local y = (idx-1)//eggs.keymap_wrap + 1 + row 
    return eggs.tunes[preset]:volts(x, y, nil, oct - 2) - 3/12
end

jf_out.note_on = function(idx)
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
jf_out.note_off = function(idx) 
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

-- local function setup()
--     crow.ii.jf.event = function(e, value)
--         tab.print(e)
--         print('value', value)
--     end
-- end
-- setup()

local param_ids = {
    tuning_preset = 'tuning_preset_jf_out',
    oct = 'oct_jf_out',
    row = 'row_jf_out',
    column = 'column_jf_out',
    mode = 'mode_jf_out',
    level = 'level_jf_out',
    shift = 'shift_jf_out',
    run = 'run_jf_out',
    run_mode = 'run_mode_jf_out',
    god_mode = 'god_mode_jf_out',
    note_mode = 'note_mode_jf_out',
}
jf_out.param_ids = param_ids
        
jf_out.name = 'just friends'

jf_out.params_count = 11

jf_out.add_params = function()
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
        min = 1, max = presets, default = preset, 
        action = function(v) 
            preset = v; update_notes()

            for _,t in ipairs(eggs.tunes) do
                t:update_tuning()
            end 
        end,
    }
    params:add{
        type = 'number', id = param_ids.oct, name = 'oct',
        min = -5, max = 5, default = oct,
        action = function(v) 
            oct = v; update_notes()

            crops.dirty.grid = true 
        end
    }
    patcher.add_destination_and_param{
        type = 'number', id = param_ids.column, name = 'column',
        min = -16, max = 16, default = column,
        action = function(v) 
            column = v; update_notes()

            crops.dirty.grid = true 
        end
    }
    patcher.add_destination_and_param{
        type = 'number', id = param_ids.row, name = 'row',
        min = -16, max = 16, default = row,
        action = function(v) 
            row = v; update_notes()

            crops.dirty.grid = true 
        end
    }
end
        
jf_out.Components = { norns = {} }

jf_out.Components.norns.page = function()
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
        _k3{ id = param_ids.note_mode, id_hold = param_ids.god_mode, n = 3, is_dest = false }
    end
end

return jf_out

local midi_outs = {}

midi_outs.devices = {}
midi_outs.device_names = { 'engine' }
local ENGINE = 1
for i = 1,#midi.vports do
    midi_outs.devices[i + 1] = midi.connect(i)
    midi_outs.device_names[i + 1] = util.trim_string_to_width(midi_outs.devices[i+1].name,80)
end

function midi_outs.init(count)
    for i = 1,count do
        out = {}

        local target = tab.key(midi_outs.device_names, 'engine')

        out.preset = i
        out.oct = 0
        out.column = 0
        out.row = -2
    
        out.voicing = 'poly'

        out.note_on = function(idx)
            local x = (idx-1)%eggs.keymap_wrap + 1 + out.column 
            local y = (idx-1)//eggs.keymap_wrap + 1 + out.row 
            local hz = eggs.tunes[out.preset]:hz(x, y, nil, out.oct) * 55
            local note = eggs.tunes[out.preset]:midi(x, y, nil, out.oct) + 33

            if target == ENGINE then
                eggs.noteOn(note, hz)
            else
                midi_outs.devices[target]:note_on(note)
            end
        end
        out.note_off = function(idx) 
            local x = (idx-1)%eggs.keymap_wrap + 1 + out.column 
            local y = (idx-1)//eggs.keymap_wrap + 1 + out.row 
            local note = eggs.tunes[out.preset]:midi(x, y, nil, out.oct) + 33

            if target == ENGINE then
                eggs.noteOff(note)
            else
                midi_outs.devices[target]:note_off(note)
            end
        end

        out.params_count = 5
    
        local param_ids = {
            target = 'target_midi_outs_'..i,
            tuning_preset = 'tuning_preset_midi_outs_'..i,
            oct = 'oct_midi_outs_'..i,
            row = 'row_midi_outs_'..i,
            column = 'column_midi_outs_'..i,
        }
        out.param_ids = param_ids
    
        out.name = 'midi out '..i

        out.add_params = function()
            params:add{
                type = 'option', id = param_ids.target, name = 'destination',
                options = midi_outs.device_names, default = target,
                action = function(v)
                    target = v
                    crops.dirty.screen = true
                end
            }
            params:add{
                type = 'number', id = param_ids.tuning_preset, name = 'tuning preset',
                min = 1, max = #eggs.tunes, default = out.preset, 
                action = function(v) 
                    out.preset = v

                    for _,t in ipairs(eggs.tunes) do
                        t:update_tuning()
                    end 
                end,
            }
            params:add{
                type = 'number', id = param_ids.oct, name = 'oct',
                min = -5, max = 5, default = out.oct,
                action = function(v) 
                    out.oct = v

                    crops.dirty.grid = true 
                end
            }
            do
                local min, max = -12, 12
                params:add{
                    type = 'control', id = param_ids.column, name = 'column',
                    controlspec = cs.def{ 
                        min = min, max = max, default = out.column * eggs.volts_per_column, 
                        quantum = (1/(max - min)) * eggs.volts_per_column, units = 'v',
                    },
                    action = function(v) 
                        out.column = v // eggs.volts_per_column

                        crops.dirty.grid = true 
                    end
                }
            end
            params:add{
                type = 'number', id = param_ids.row, name = 'row',
                min = -16, max = 16, default = out.row,
                action = function(v) 
                    out.row = v

                    crops.dirty.grid = true 
                end
            }
        end

        out.Components = { norns = {} }

        out.Components.norns.page = function()
            local _target = Components.enc_screen.param()

            return function()
                _target{ id = param_ids.target, n = 1, is_dest = false }
            end
        end

        midi_outs[i] = out
    end
end

return midi_outs

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
        midi_outs[i] = {}

        local target = tab.key(midi_outs.device_names, 'engine')
        local preset = i
        local oct = 0
        local column = 0
        local row = -2
    
        midi_outs[i].voicing = 'poly'

        midi_outs[i].note_on = function(idx)
            local x = (idx-1)%eggs.keymap_wrap + 1 + column 
            local y = (idx-1)//eggs.keymap_wrap + 1 + row 
            local hz = eggs.tunes[preset]:hz(x, y, nil, oct) * 55
            local note = eggs.tunes[preset]:midi(x, y, nil, oct) + 33

            if target == ENGINE then
                eggs.noteOn(note, hz)
            else
                midi_outs.devices[target]:note_on(note)
            end
        end
        midi_outs[i].note_off = function(idx) 
            local x = (idx-1)%eggs.keymap_wrap + 1 + column 
            local y = (idx-1)//eggs.keymap_wrap + 1 + row 
            local note = eggs.tunes[preset]:midi(x, y, nil, oct) + 33

            if target == ENGINE then
                eggs.noteOff(note)
            else
                midi_outs.devices[target]:note_off(note)
            end
        end

        midi_outs[i].params_count = 5
    
        local param_ids = {
            target = 'target_midi_outs_'..i,
            tuning_preset = 'tuning_preset_midi_outs_'..i,
            oct = 'oct_midi_outs_'..i,
            row = 'row_midi_outs_'..i,
            column = 'column_midi_outs_'..i,
        }
        midi_outs[i].param_ids = param_ids
    
        midi_outs[i].name = 'midi out '..i

        midi_outs[i].add_params = function()
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
                min = 1, max = presets, default = preset, 
                action = function(v) 
                    preset = v

                    for _,t in ipairs(eggs.tunes) do
                        t:update_tuning()
                    end 
                end,
            }
            params:add{
                type = 'number', id = param_ids.oct, name = 'oct',
                min = -5, max = 5, default = oct,
                action = function(v) 
                    oct = v

                    crops.dirty.grid = true 
                end
            }
            params:add{
                type = 'number', id = param_ids.column, name = 'column',
                min = -16, max = 16, default = column,
                action = function(v) 
                    column = v

                    crops.dirty.grid = true 
                end
            }
            params:add{
                type = 'number', id = param_ids.row, name = 'row',
                min = -16, max = 16, default = row,
                action = function(v) 
                    row = v

                    crops.dirty.grid = true 
                end
            }
        end

        midi_outs[i].Components = { norns = {} }

        midi_outs[i].Components.norns.page = function()
            local _target = Components.enc_screen.param()

            return function()
                _target{ id = param_ids.target, n = 1, is_dest = false }
            end
        end
    end
end

return midi_outs

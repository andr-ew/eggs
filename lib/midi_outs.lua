local midi_outs = {}

midi_outs.devices = {}
midi_outs.device_names = { 'engine' }
local ENGINE = 1
for i = 1,#midi.vports do
    midi_outs.devices[i + 1] = midi.connect(i)
    midi_outs.device_names[i + 1] = util.trim_string_to_width(midi_outs.devices[i+1].name,80)
end

function midi_outs.init(track_ids)
    for i, track in ipairs(track_ids) do
        midi_outs[i] = {}

        local target = tab.key(midi_outs.device_names, 'engine')

        midi_outs[i].note_on = function(idx)
            local column = (idx-1)%eggs.keymap_wrap + 1 + params:get('column_'..track)
            local row = (idx-1)//eggs.keymap_wrap + 1 + params:get('row_'..track)
            local oct = params:get('oct_'..track)

            if target == ENGINE then
                local hz = eggs.get_tune(track):hz(column, row, nil, oct) * 55
                engine.start(idx, hz)
            else
                local note = eggs.get_tune(track):midi(column, row, nil, oct) + 33
                midi_outs.devices[target]:note_on(note)
            end
        end
        midi_outs[i].note_off = function(idx) 
            if target == ENGINE then
                engine.stop(idx) 
            else
                local column = (idx-1)%eggs.keymap_wrap + 1 + params:get('column_'..track)
                local row = (idx-1)//eggs.keymap_wrap + 1 + params:get('row_'..track)
                local oct = params:get('oct_'..track)

                local note = eggs.get_tune(track):midi(column, row, nil, oct) + 33
                midi_outs.devices[target]:note_off(note)
            end
        end

        midi_outs.param_count = 1

        midi_outs[i].add_params = function()
            params:add{
                type = 'option', id = 'target_'..track, name = 'track '..track..' destination',
                options = midi_outs.device_names, default = target,
                action = function(v)
                    target = v
                    crops.dirty.screen = true
                end
            }
        end
    end
end

return midi_outs

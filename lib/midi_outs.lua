local midi_outs = {}

midi_outs.devices = {}
midi_outs.device_names = { 'engine', 'nb' }
local ENGINE, NB = 1, 2
for i = 1,#midi.vports do
    midi_outs.devices[i + 2] = midi.connect(i)
    midi_outs.device_names[i + 2] = util.trim_string_to_width(midi_outs.devices[i+2].name,80)
end

function midi_outs.init(count)
    for i = 1,count do
        local out = {}

        local target = tab.key(midi_outs.device_names, 'engine')

        out.preset = i
        out.oct = 0
        out.column = 0
        out.row = -2
        out.macro_ids = {}
        out.cc_value = {}
        out.cc_index = {}

        out.voicing = 'poly'

        local held = {}

        local function update_cc(idx)
            if target == ENGINE then
            elseif target == NB then
            else
                midi_outs.devices[target]:cc(out.cc_index[idx], out.cc_value[idx], 1)
            end

            crops.dirty.screen = true
        end

        local function get_note_hz(idx)
            local x = (idx-1)%eggs.keymap_wrap + 1 + out.column 
            local y = (idx-1)//eggs.keymap_wrap + 1 + out.row 
            local note = eggs.tunes[out.preset]:midi(x, y, nil, out.oct) + 33
            local hz = eggs.tunes[out.preset]:hz(x, y, nil, out.oct) * 55

            return note, hz
        end
        local function note_on(note, hz)
            if target == ENGINE then
                eggs.noteOn(note, hz)
            elseif target == NB then
                local player = params:lookup_param('voice_'..i):get_player()
                player:note_on(note, 1)
            else
                midi_outs.devices[target]:note_on(note)
            end
        end
        local function note_off(note)
            if target == ENGINE then
                eggs.noteOff(note)
            elseif target == NB then
                local player = params:lookup_param('voice_'..i):get_player()
                player:note_off(note)
            else
                midi_outs.devices[target]:note_off(note)
            end
        end

        out.note_on = function(idx)
            local note, hz = get_note_hz(idx)
            note_on(note, hz)

            table.insert(held, { idx = idx, note = note })
        end
        out.note_off = function(idx) 
            local note = get_note_hz(idx)
            note_off(note)

            for i,h in ipairs(held) do if h.note==note then
                table.remove(held, i)
                break
            end end
        end

        local function update_notes()
            for i,h in ipairs(held) do
                note_off(h.note)

                local new_note, new_hz = get_note_hz(h.idx)
                h.note = new_note
                note_on(new_note, new_hz)
            end
        end

        local param_ids = {
            target = 'target_midi_outs_'..i,
            tuning_preset = 'tuning_preset_midi_outs_'..i,
            oct = 'oct_midi_outs_'..i,
            row = 'row_midi_outs_'..i,
            column = 'column_midi_outs_'..i,
            cc_value = {},
            cc_index = {},
            macro = {},
        }
        out.param_ids = param_ids
        
        out.params_count = tab.count(param_ids) - 3 + 2 + (3 * eggs.macro_count) + 1
    
        out.name = 'midi out '..i
            
        local cc_value_names = {}
                
        for ii = 1,eggs.macro_count do
            param_ids.cc_index[ii] = 'cc_index_'..ii..'_midi_outs_'..i
            param_ids.cc_value[ii] = 'cc_value_'..ii..'_midi_outs_'..i
            cc_value_names[ii] = 'CC '..ii
            out.macro_ids[ii] = param_ids.cc_value[ii]
        end
            

        out.add_params = function()
            params:add{
                type = 'option', id = param_ids.target, name = 'destination',
                options = midi_outs.device_names, default = target,
                action = function(v)
                    target = v
                    crops.dirty.screen = true
                end
            }

            params:add_separator('macros')
            do
                for ii = 1,eggs.macro_count do
                    local dest_names = { cc_value_names[ii] }
                    local dest_ids = { param_ids.cc_value[ii] }
                
                    for ii,v in ipairs(params.params) do
                        if v.t == params.tCONTROL then
                            table.insert(dest_names, v.name or v.id)
                            table.insert(dest_ids, v.id)
                        end
                    end

                    param_ids.macro[ii] = 'macro_'..ii..'_midi_outs_'..i

                    params:add {
                        type = 'option', id = param_ids.macro[ii], name = 'macro '..ii,
                        options = dest_names, action = function(v)
                            out.macro_ids[ii] = dest_ids[v]
                            crops.dirty.screen = true
                        end
                    }
                end
            end
            
            params:add_separator('midi CCs')
            do
                local cc_spec = cs.def{ default = 0, min = 0, max = 127, step = 1 }

                for ii = 1,eggs.macro_count do
                    params:add{
                        type = 'number', id = param_ids.cc_index[ii], name = 'CC address '..ii,
                        min = 0, max = 127, default = ii,
                        action = function(v)
                            out.cc_index[ii] = v; update_cc(ii)
                        end
                    }
                    patcher.add_destination_and_param{
                        type = 'control', id = param_ids.cc_value[ii], name = cc_value_names[ii],
                        controlspec = cc_spec,
                        action = function(v)
                            out.cc_value[ii] = v; update_cc(ii)
                        end
                    }
                    params:hide(param_ids.cc_value[ii])
                end
            end

            params:add_separator('keymap')

            params:add{
                type = 'number', id = param_ids.tuning_preset, name = 'tuning preset',
                min = 1, max = #eggs.tunes, default = out.preset, 
                action = function(v) 
                    out.preset = v; update_notes()

                    for _,t in ipairs(eggs.tunes) do
                        t:update_tuning()
                    end 
                end,
            }
            params:add{
                type = 'number', id = param_ids.oct, name = 'oct',
                min = -5, max = 5, default = out.oct,
                action = function(v) 
                    out.oct = v; update_notes()

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
                        local last = out.column
                        out.column = v // eggs.volts_per_column
                
                        if last ~= out.column then update_notes() end

                        crops.dirty.grid = true 
                        crops.dirty.screen = true 
                    end
                }
            end
            params:add{
                type = 'number', id = param_ids.row, name = 'row',
                min = -16, max = 16, default = out.row,
                action = function(v) 
                    local last = out.row
                    out.row = v
            
                    if last ~= out.row then update_notes() end

                    crops.dirty.grid = true 
                    crops.dirty.screen = true 
                end
            }
        end

        out.Components = { norns = {} }
    
        local x, y, e, k = eggs.x, eggs.y, eggs.e, eggs.k

        out.Components.norns.page = function()
            local _target = Components.enc_screen.param()

            local dots = {}
            for i = 1,eggs.macro_page_count do
                table.insert(dots, ".")
            end

            local macro_focus = 1
            local _macro_focus = {
                key = Key.integer(),
                screen = Screen.list(),
            }

            local _macros = {}
            for ii = 1,2 do
                _macros[ii] = Components.enc_screen.param()
            end

            return function()
                _target{ id = param_ids.target, n = 1, is_dest = false }

                _macro_focus.key{
                    n_next = 3, n_prev = 2, min = 1, max = eggs.macro_page_count,
                    state = crops.of_variable(macro_focus, function(v) 
                        macro_focus = v; crops.dirty.screen = true
                    end)
                }
                _macro_focus.screen{
                    x = k[2].x, y = k[2].y, text = dots, focus = macro_focus,
                    font_size = 16, margin = 3,
                }

                for ii = 1,2 do
                    local i_macro = (macro_focus - 1)*2 + ii
                    local id = out.macro_ids[i_macro]
                    local is_cc = id == param_ids.cc_value[i_macro]

                    _macros[ii]{
                        id = id, n = 1 + ii, is_dest = is_cc,
                    }

                    if not is_cc then
                        crops.dirty.screen = true --hahahah well there's not really a better solution
                    end
                end
            end
        end

        midi_outs[i] = out
    end
end

return midi_outs

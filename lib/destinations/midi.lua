local midi_dest = destination:new()

midi_dest.devices = {}
midi_dest.device_names = {}
for i = 1,#midi.vports do
    midi_dest.devices[i] = midi.connect(i)
    midi_dest.device_names[i] = util.trim_string_to_width(midi_dest.devices[i].name,80)
end

local alph = { 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H' }

function midi_dest:new(id)
    local id_postfix = '_midi_dest_'..id

    local o = destination.new(self, id_postfix)

    o.id = id
    o.preset = id
    o.target = 1 
    o.param_ids.target = 'target'..id_postfix
    o.param_ids.cc_value = {}
    o.param_ids.cc_index = {}
    
    o.params_count = tab.count(o.param_ids) - 3 + 2 + (2 * eggs.cc_count) + 1

    o.name = 'midi dest '..id
        
    o.cc_value_names = {}
            
    for ii = 1,eggs.cc_count do
        o.param_ids.cc_index[ii] = 'cc_index_'..alph[ii]..id_postfix
        o.param_ids.cc_value[ii] = 'cc_value_'..alph[ii]..id_postfix        
        o.cc_value_names[ii] = 'CC '..alph[ii]
    end

    return o
end
    
function midi_dest:update_cc(idx)
    midi_dest.devices[self.target]:cc(self.cc_index[idx], self.cc_value[idx], 1)

    crops.dirty.screen = true
end

function midi_dest:action_on(note, hz)
    midi_dest.devices[self.target]:note_on(note)
end

function midi_dest:action_off(note)
    midi_dest.devices[self.target]:note_off(note)
end
    
function midi_dest:add_params()
    local param_ids = self.param_ids

    params:add{
        type = 'option', id = param_ids.target, name = 'destination',
        options = midi_dest.device_names, default = self.target,
        action = function(v)
            self.target = v
            crops.dirty.screen = true
        end
    }

    params:add_separator('midi CCs')
    do
        local cc_spec = cs.def{ default = 0, min = 0, max = 127, step = 1 }

        for ii = 1,eggs.cc_count do
            patcher.add_destination_and_param{
                type = 'control', id = param_ids.cc_value[ii], name = self.cc_value_names[ii],
                controlspec = cc_spec,
                action = function(v)
                    self.cc_value[ii] = v; self:update_cc(ii)
                end
            }
            params:add{
                type = 'number', id = param_ids.cc_index[ii], name = 'CC# '..alph[ii],
                min = 0, max = 127, default = ii,
                action = function(v)
                    self.cc_index[ii] = v; self:update_cc(ii)
                end
            }
        end
    end

    destination.add_params(self)
end

midi_dest.Components = { norns = {} }

local x, y, e, k = eggs.x, eggs.y, eggs.e, eggs.k

midi_dest.Components.norns.page = function()
    local _target = Components.enc_screen.param()

    local dots = {}
    for i = 1,eggs.cc_page_count do
        table.insert(dots, ".")
    end

    local subpage_focus = 1
    local _subpage_focus = {
        key = Key.integer(),
        screen = Screen.list(),
    }

    local _ccs = {}
    for ii = 1,2 do
        _ccs[ii] = Components.enc_screen.param()
    end

    return function(props)
        local param_ids = props.dest.param_ids

        _target{ id = param_ids.target, n = 1, is_dest = false }

        _subpage_focus.key{
            n_next = 3, n_prev = 2, min = 1, max = eggs.cc_page_count, wrap = true,
            state = crops.of_variable(subpage_focus, function(v)
                subpage_focus = v; crops.dirty.screen = true
            end)
        }
        _subpage_focus.screen{
            x = k[2].x, y = k[2].y, text = dots, focus = subpage_focus,
            font_size = 16, margin = 3,
        }

        for ii = 1,2 do
            local id = props.dest.param_ids.cc_value[(subpage_focus - 1)*2 + ii]
            _ccs[ii]{
                id = id, n = 1 + ii,
            }
        end
    end
end

return midi_dest

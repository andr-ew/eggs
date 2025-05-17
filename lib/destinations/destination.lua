local destination = {}

function destination:new(id_postfix)
    local o = setmetatable({}, self)
    self.__index = self
    
    o.id_postfix = id_postfix or ''
    o.macro_ids = {}
    o.cc_value = {}
    o.cc_index = {}

    o.name = ''
    o.shortname = ''
    o.voicing = 'poly'

    o.held = {}

    o.param_ids = {}

    return o
end

function destination:note_on(idx, semitones)
    local note = semitones + 48
    local hz = musicutil.note_num_to_freq(note)
    self:action_on(note, hz)

    table.insert(self.held, { idx = idx, note = note })
end
function destination:note_off(idx, semitones) 
    local note = semitones + 48
    self:action_off(note)

    for i,h in ipairs(self.held) do if h.idx==idx then
        table.remove(self.held, i)
        break
    end end
end
function destination:kill_all()
    for i,h in ipairs(self.held) do
        self:action_off(h.note)
    end
    self.held = {}
end
    
function destination:add_params()
    local param_ids = self.param_ids

    params:add_separator('keymap')

    params:add{
        type = 'number', id = param_ids.tuning_preset, name = 'tuning preset',
        min = 1, max = #eggs.tunes, default = self.preset, 
        action = function(v) 
            self.preset = v; self:update_notes()

            for _,t in ipairs(eggs.tunes) do
                t:update_tuning()
            end 
        end,
    }
end

function destination:add_macro_params(id_start, id_end)
    local param_ids = self.param_ids

    params:add_separator('macros')
    do
        local dest_names = {}
        local dest_ids = {}
        local adding = false
            
        for ii,p in ipairs(params.params) do
            if adding then
                if p.id == id_end then
                    adding = false
                elseif p.t == params.tCONTROL then
                    table.insert(dest_names, p.name or p.id)
                    table.insert(dest_ids, p.id)
                end
            elseif p.id == id_start then
                adding = true
            end
        end

        for ii = 1,eggs.macro_count do
            params:add {
                type = 'option', id = param_ids.macro[ii], name = 'macro '..ii,
                options = dest_names, default = 1,
                action = function(v)
                    self.macro_ids[ii] = dest_ids[v]
                    crops.dirty.screen = true
                end
            }
        end
    end
end

destination.Components = { norns = {} }

local x, y, e, k = eggs.x, eggs.y, eggs.e, eggs.k

destination.Components.norns.page_macros = function()
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
    for ii = 1,3 do
        _macros[ii] = Components.enc_screen.param()
    end

    return function(props)
        local param_ids = props.dest.param_ids

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

        for ii = 1,3 do
            local i_macro = (macro_focus - 1)*3 + ii
            local id = props.dest.macro_ids[i_macro] or props.dest.macro_ids[1] -- ???

            _macros[ii]{
                id = id, n = ii, is_dest = false,
            }
        end
            
        crops.dirty.screen = true --ahahahah
    end
end

return destination

local destination = {}

function destination:new(id_postfix)
    local o = setmetatable({}, self)
    self.__index = self
    
    o.id_postfix = id_postfix or ''
    o.preset = 1
    o.oct = 0
    o.column = 0
    o.row = -2
    o.macro_ids = {}
    o.cc_value = {}
    o.cc_index = {}

    o.name = ''
    o.shortname = ''
    o.voicing = 'poly'

    o.held = {}

    o.param_ids = {
        tuning_preset = 'tuning_preset_'..o.id_postfix,
        oct = 'oct_'..o.id_postfix,
        row = 'row_'..o.id_postfix,
        column = 'column_'..o.id_postfix,
    }

    return o
end

function destination:get_note_hz(idx)
    local x = (idx-1)%eggs.keymap_wrap + 1 + self.column 
    local y = (idx-1)//eggs.keymap_wrap + 1 + self.row 
    local note = eggs.tunes[self.preset]:midi(x, y, nil, self.oct) + 33
    local hz = eggs.tunes[self.preset]:hz(x, y, nil, self.oct) * 55

    return note, hz
end

function destination:note_on(idx)
    local note, hz = self:get_note_hz(idx)
    self:action_on(note, hz)

    table.insert(self.held, { idx = idx, note = note })
end
function destination:note_off(idx) 
    local note = self:get_note_hz(idx)
    self:action_off(note)

    for i,h in ipairs(self.held) do if h.note==note then
        table.remove(self.held, i)
        break
    end end
end
function destination:update_notes()
    for i,h in ipairs(self.held) do
        self:action_off(h.note)

        local new_note, new_hz = self:get_note_hz(h.idx)
        h.note = new_note
        self:action_on(new_note, new_hz)
    end
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
    params:add{
        type = 'number', id = param_ids.oct, name = 'oct',
        min = -5, max = 5, default = self.oct,
        action = function(v) 
            self.oct = v; self:update_notes()

            crops.dirty.grid = true 
        end
    }
    do
        local min, max = -12, 12
        params:add{
            type = 'control', id = param_ids.column, name = 'column',
            controlspec = cs.def{ 
                min = min, max = max, default = self.column * eggs.volts_per_column, 
                quantum = (1/(max - min)) * eggs.volts_per_column, units = 'v',
            },
            action = function(v) 
                local last = self.column
                self.column = v // eggs.volts_per_column
        
                if last ~= self.column then self:update_notes() end

                crops.dirty.grid = true 
                crops.dirty.screen = true 
            end
        }
    end
    params:add{
        type = 'number', id = param_ids.row, name = 'row',
        min = -16, max = 16, default = self.row,
        action = function(v) 
            local last = self.row
            self.row = v
    
            if last ~= self.row then self:update_notes() end

            crops.dirty.grid = true 
            crops.dirty.screen = true 
        end
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

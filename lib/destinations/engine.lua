local engine_dest = destination:new()

function engine_dest:new(id)
    local id_postfix = '_engine_dest_'..id

    local o = destination.new(self, id_postfix)

    o.id = id
    o.preset = id
    o.param_ids.macro = {}
    
    o.params_count = tab.count(o.param_ids) - 1 + (1 * eggs.macro_count) + 2

    o.name = 'engine dest '..id
        
    for ii = 1,eggs.macro_count do
        o.param_ids.macro[ii] = 'macro_'..ii..id_postfix
    end

    return o
end
    
function engine_dest:action_on(note, hz) eggs.noteOn(note, hz) end

function engine_dest:action_off(note) eggs.noteOff(note) end
    
function engine_dest:add_params()
    local param_ids = self.param_ids

    params:add_separator('macros')
    do
        local id_start = 'engine_eggs'
        local id_end = 'engine_dests_1'

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
                options = dest_names, action = function(v)
                    self.macro_ids[ii] = dest_ids[v]
                    crops.dirty.screen = true
                end
            }
        end
    end
    
    destination.add_params(self)
end

engine_dest.Components = { norns = {} }

local x, y, e, k = eggs.x, eggs.y, eggs.e, eggs.k

engine_dest.Components.norns.page = function()
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
            local id = props.dest.macro_ids[i_macro]

            _macros[ii]{
                id = id, n = ii, is_dest = false,
            }
        end
            
        crops.dirty.screen = true --ahahahah
    end
end

return engine_dest

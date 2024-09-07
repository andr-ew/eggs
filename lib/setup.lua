local setup = {}

function setup.destinations()
    eggs.midi_dests = {}
    eggs.engine_dests = {}
    eggs.nb_dests = {}

    for i = 1,eggs.track_count do
        eggs.midi_dests[i] = midi_dest:new(i)
        eggs.engine_dests[i] = engine_dest:new(i)
        eggs.nb_dests[i] = nb_dest:new(i)
    end
    eggs.crow_dests = crow_dests
    eggs.jf_dest = jf_dest

    eggs.dests = {
        { eggs.engine_dests[1], eggs.midi_dests[1], eggs.nb_dests[1] },
        { jf_dest, eggs.engine_dests[2], eggs.midi_dests[2], eggs.nb_dests[2] },
        { crow_dests[1], eggs.engine_dests[3], eggs.midi_dests[3], eggs.nb_dests[3] },
        { crow_dests[2], eggs.engine_dests[4], eggs.midi_dests[4], eggs.nb_dests[4] },
    }
    eggs.dest_names = {
        { 'engine', 'midi', 'nb' },
        { 'jf', 'engine', 'midi', 'nb' },
        { 'crow 1+2', 'engine', 'midi', 'nb' },
        { 'crow 3+4', 'engine', 'midi', 'nb' },
    }

    for i = 1,eggs.track_count do
        eggs.set_dest(i, 1)
    end
end

function setup.modulation_sources()
    local add_actions = {}
    for i = 1,2 do
        add_actions[i] = patcher.crow.add_source(i)
    end

    do
        local stream = patcher.add_source{ name = 'crow out 1', id = 'crow_out_1' }
        crow_dests[1].cv_callback = stream
    end
    do
        local stream, change

        local function assignment_callback(mode)
            if mode == 'stream' then
                crow_dests[1].gate_callback = function(state)
                    stream(state and 5 or 0)
                end
            elseif mode == 'change' then
                crow_dests[1].gate_callback = change
            end
        end

        stream, change = patcher.add_source{ 
            name = 'crow out 2', id = 'crow_out_2',
            assignment_callback = assignment_callback,
        }
    end

    return add_actions
end

function setup.crow(add_actions)
    local function crow_add()
        for _,dest in ipairs(crow_dests) do
            dest.add()
        end
        for _,action in ipairs(add_actions) do action() end
    end
    norns.crow.add = crow_add

    return crow_add
end

function setup.init()
    for i = 1,eggs.track_count do
        local arq = eggs.arqs[i]:start()
    end
end

return setup

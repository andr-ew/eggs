local src = {}

--TODO: update to latest patcher
do
    src.crow = {}

    local streams = {}
    for i = 1,2 do
        streams[i] = patcher.add_source('crow_'..i, 'crow '..i, 0)
    end
    -- src.crow.streams = streams

    -- src: https://github.com/monome/norns/blob/e8ae36069937df037e1893101e73bbdba2d8a3db/lua/core/crow.lua#L14
    local function re_enable_clock_source_crow()
        if params.lookup["clock_source"] then
            if params:string("clock_source") == "crow" then
                norns.crow.clock_enable()
            end
        end
    end
    
    local already_mapped = { false, false }
    function src.crow.update()
        local mapped = { false, false }

        for i = 1,2 do
            if #patcher.get_assignments_source('crow_'..i) > 0 then mapped[i] = true end
        end
        
        for i, map in ipairs(mapped) do 
            if map then 
                if not already_mapped[i] then
                    crow.input[i].mode('stream', 0.01)
                end
            else
                crow.input[i].mode('none')
            end 
        end
        if not mapped[1] and already_mapped[1] then re_enable_clock_source_crow() end

        already_mapped = mapped
    end

    function src.crow.add()
        for i = 1,2 do
            crow.input[i].stream = streams[i] 
        end

        src.crow.update()
    end
end

-- do
--     src.lfos = {}
    
--     for i = 1,2 do
--         local action = patcher.add_source('lfo '..i, 0)

--         src.lfos[i] = lfos:add{
--             min = -5,
--             max = 5,
--             depth = 0.1,
--             mode = 'free',
--             period = 0.25,
--             baseline = 'center',
--             action = action,
--         }
--     end

--     src.lfos.reset_params = function()
--         for i = 1,2 do
--             params:set('lfo_mode_lfo_'..i, 2)
--             -- params:set('lfo_max_lfo_'..i, 5)
--             -- params:set('lfo_min_lfo_'..i, -5)
--             params:set('lfo_baseline_lfo_'..i, 2)
--             params:set('lfo_lfo_'..i, 2)
--         end
--     end
-- end


return src

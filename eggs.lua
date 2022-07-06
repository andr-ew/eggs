-- eggs before brds

--global variables

g = grid.connect()
varibright = (g and g.device and g.device.cols >= 16) and true or false

--external libs

tab = require 'tabutil'
cs = require 'controlspec'
mu = require 'musicutil'
pattern_time = require 'pattern_time'

--git submodule libs

nest = include 'lib/nest/core'
Key, Enc = include 'lib/nest/norns'
Text = include 'lib/nest/text'
Grid = include 'lib/nest/grid'

multipattern = include 'lib/nest/util/pattern-tools/multipattern'
of = include 'lib/nest/util/of'
to = include 'lib/nest/util/to'
PatternRecorder = include 'lib/nest/examples/grid/pattern_recorder'

tune, Tune = include 'lib/tune/tune' 
tune.setup { presets = 8, scales = include 'lib/tune/scales' }

--script lib files

include 'eggs/lib/params'
Eggs = include 'eggs/lib/ui'

--set up global patterns

function pattern_time:resume()
    if self.count > 0 then
        self.prev_time = util.time()
        self.process(self.event[self.step])
        self.play = 1
        self.metro.time = self.time[self.step] * self.time_factor
        self.metro:start()
    end
end

pattern, mpat = {}, {}
for i = 1,3 do
    pattern[i] = {}
    mpat[i] = {}
    for ii = 1,6 do
        pattern[i][ii] = pattern_time.new() 
        mpat[i][ii] = multipattern.new(pattern[i][ii])
    end
end

--set up nest v2 UI

local _app = {
    grid = Eggs.grid(),
    norns = Eggs.norns(),
}

nest.connect_grid(_app.grid, g, 240)
nest.connect_enc(_app.norns)
nest.connect_key(_app.norns)
nest.connect_screen(_app.norns, 24)

--init/cleanup

--TODO: pattern save/load
function init()
    tune.read()
    params:read()
    params:bang()

    -- do
    --     local data = tab.load(norns.state.data..'patterns.data')
    --     if data then
    --         for i,pats in ipairs(data) do
    --             for ii, pat in ipairs(pats) do
    --                 for k,v in pairs(pat) do
    --                     pattern[i][ii][k] = v
    --                 end
    --             end
    --         end
    --     end
    -- end
end

function cleanup() 
    tune.write()
    params:write()

    -- do
    --     local data = {}
    --     for i,pats in ipairs(pattern) do
    --         data[i] = {}
    --         for ii, pat in ipairs(pats) do
    --             local d = data[i][ii]
    --             d.time = pat.time
    --             d.count = pat.count
    --             d.time_factor = pat.time_factor
    --         end
    --     end

    --     tab.save(data, norns.state.data..'patterns.data')
    -- end
end

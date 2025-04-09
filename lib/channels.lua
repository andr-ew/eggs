local channels = {}
channels.__index = channels

local VOLTS, HZ, MIDI = 'volts', 'hz', 'midi'

local intervals_min, intervals_max = 1, 7

channels.intervals_min, channels.intervals_max = intervals_min, intervals_max

local mode_names = {
    [7] = {
        -- 'lydian', 'myxlyd', 'aeoln', 'locrn', 'ionian', 'dorian', 'phrygn', 
        'lydian', 'myxolydian', 'aeolean', 'locrean', 'ionian', 'dorian', 'phrygian', 
    },
    [5] = { 
        'gong', 'shang', 'jue', 'zhi', 'yu',
    },
}

local modulation_names = {
    [-11] = 'A𝄫',
    [-10] = 'E𝄫',
    [-9] = 'B𝄫',
    [-8] = 'F♭',
    [-7] = 'C♭',
    [-6] = 'G♭',
    [-5] = 'D♭',
    [-4] = 'A♭',
    [-3] = 'E♭',
    [-2] = 'B♭',
    [-1] = 'F',
    [0] = 'C',
    [1] = 'G',
    [2] = 'D',
    [3] = 'A',
    [4] = 'E',
    [5] = 'B',
    [6] = 'F♯',
    [7] = 'C♯',
    [8] = 'G♯',
    [9] = 'D♯',
    [10] = 'A♯',
    [11] = 'E♯',
}
channels.modulation_names = modulation_names

local key_names = {
    sharp = { [0] = 'C', 'C♯', 'D', 'D♯', 'E', 'F', 'F♯', 'G', 'G♯', 'A', 'A♯', 'B' },
    flat =  { [0] = 'C', 'D♭', 'D', 'E♭', 'E', 'F', 'G♭', 'G', 'A♭', 'A', 'B♭', 'B' },
}
channels.key_names = key_names

function channels.new(count)
    local self = setmetatable({}, channels)

    self.count = count

    self.grouper = {}
    for i = 1,count do
        self.grouper[i] = i % 2
    end

    for i = 1,count do
        self[i] = {}

        --params
        self[i].intervals = 5
        self[i].modulation = 0 
        self[i].transposition_semitones = 0
        self[i].mode = 1-- 1==lydian

        --private
        self[i].scale = { 0, 2, 4, 7, 9, }
        self[i].modulation_semitones = 0
        self[i].current_key_action = nil
        self[i].last_transposition_semitones = 0
    end
    
    self.param_ids = {}

    for x = 1,count do
        self.param_ids[x] = {}

        local pfx = x
        self.param_ids[x] = {
            modulation = 'modulation_'..pfx,
            transposition = 'transposition_'..pfx,
            mode = 'musical_mode_'..pfx,
            ['scale degrees'] = 'intervals_'..pfx,
            -- tuning_preset = 'tuning_preset_'..pfx,
        }
    end

    self.channel_params_count = tab.count(self.param_ids[1]) * count
    self.params_count = 1 + (self.count) --?

    return self
end

function channels:group_index(channel)
    local i = channel
    while self.grouper[i] == self.grouper[i + 1] do
        i = i + 1
    end
    
    return i
end

function channels:export(channel, track)
    local data = {}
    local ids = self.param_ids[channel][track]

    -- for _,id in pairs(self.param_ids[channel][track]) do
    --     data[id] = params:get(id)
    -- end

    data[ids.mode] = params:get(ids.mode)
    -- data.transposition = params:get(ids.transposition)

    return data
end
function channels:import(channel, track, data)
    for id,v in pairs(data) do
        params:set(id, v)
    end
end

--[[

0, 2, 4,    7, 9,
0, 2, 4, 5, 7, 9, 11

0
7
2
9
4
11
6
pattern: (i * 7) % 12

maj pent turns into the lydian !!!!! so it kinda makes things asymetrical but i like it

--]]
--[[

0, 2, 4, 5, 7, 9, 11  --ionian

0, 2, 4,    7, 9,     --gong (major)
0, 2, 4, 6, 7, 9, 11  --lydian

0,    3, 5, 7,    10  --yu (minor)
0, 2, 3, 5, 7, 9, 10  --dorian

0, 2, 3, 5, 7, 8, 10  --aeolian

lydian     |  gong
myxolydian |  shang
aeolean    |  jue
locrian    |  --
ionian     |  zhi
dorian     |  yu
phrygian   |  --

0, 2, 4, 6, 7, 9, 11  -- 4
0, 2, 4,    7, 9, 11  -- 7
0, 2, 4,    7, 9      -- 3
0, 2,       7, 9      -- 6
0, 2,       7         -- 2
0,          7         -- 5
0                     -- 1
pattern: ((i - 1) + 4)%7 + 1

--]]
--[[

tests:
table.concat(mode(build_scale(5), lookup_base[5][tab.key(base_names[5], 'gong')]), ', ')
table.concat(mode(build_scale(5), lookup_base[5][tab.key(base_names[5], 'yu')]), ', ')
table.concat(mode(build_scale(7), lookup_base[7][tab.key(base_names[7], 'ionian')]), ', ')
table.concat(mode(build_scale(7), lookup_base[7][tab.key(base_names[7], 'aeolian')]), ', ')

--]]

local base_exists = {}
local lookup_base = {}
local base_names = {}

channels.base_exists, channels.lookup_base, channels.base_names 
    = 
base_exists, lookup_base, base_names

for i = intervals_min, intervals_max do
    base_exists[i] = {}
    lookup_base[i] = {}
    base_names[i] = {}

    local ii = 1
    for degree = 1, i do
        base_exists[i][ii] = true

        ii = ((ii - 1) + 4)%7 + 1
    end

    local degree = 0
    for ii = intervals_min, intervals_max do
        if base_exists[i][ii] then
            degree = degree + 1
            
            base_names[i][ii] = mode_names[i] and mode_names[i][degree] or 'base:'..degree
        else
            base_names[i][ii] = '-'
        end
            
        lookup_base[i][ii] = degree
    end
end

local function mode(scale, base)
    local m = {}

    for i = 1,#scale do
        local iv = util.wrap(i + base - 1, 1, #scale)
        local offset = scale[base]

        table.insert(m, util.wrap(scale[iv] - offset, 0, 11))
    end

    return m
end

local function build_scale(intervals)
    local scl = {}

    --progressively build scale in fifths
    for i = 0, intervals-1 do
        table.insert(scl, (i * 7) % 12)
    end
    table.sort(scl)

    return scl
end

local scales = {} --[intervals][mode]

channels.scales = scales

for ivs = intervals_min, intervals_max do
    scales[ivs] = {} 
    for md = 1,intervals_max do
        scales[ivs][md] = mode(build_scale(ivs), lookup_base[ivs][md])
    end
end

function channels:get_param_id(channel, name, grouped)
    local i = grouped and self:group_index(channel) or channel
    return self.param_ids[i][name]
end

function channels:add_params()
    params:add_separator('grouper')

    for i = 1,self.count do
        params:add{
            type = 'binary', behavior = 'toggle', id = 'grouper_'..i, name = 'channel '..i,
            default = self.grouper[i], action = function(v) 
                self.grouper[i] = v

                crops.dirty.grid = true
                crops.dirty.screen = true
            end
        }
    end
end

function channels:add_channel_params(i)
    local ids = self.param_ids[i]

    do
        local max_intervals = eggs.max_intervals
        local name = 'scale degrees'
        patcher.add_destination_and_param{
            type = 'number', name = name, id = ids[name], 
            min = 1, max = max_intervals, default = 5,
            action = function(v)
                self[i].intervals = v

                crops.dirty.grid = true 
            end
        }
    end

    local min, max = -12, 12
    do
        local name = 'modulation'
        patcher.add_destination_and_param{
            type = 'number', name = name, id = ids[name], 
            min = -math.huge, max = math.huge, default = self[i][name],
            action = function(v)
                self[i][name] = v

                self[i].current_key_action = name
                self:update_modulation(i)

                crops.dirty.grid = true
                crops.dirty.screen = true
            end,
            -- formatter = function() return self:get_key_name() end
            -- formatter = function(p)
            --     return modulation_names[util.wrap(params:get('base_key') + p:get(), -11,  11)]
            -- end
        }
    end
    do
        local name = 'transposition'
        patcher.add_destination_and_param{
            type = 'number', name = name, id = ids[name], 
            min = -math.huge, max = math.huge, default = self[i][name],
            action = function(v)
                self[i].last_transposition_semitones = self[i].transposition_semitones
                self[i].transposition_semitones = v
                self[i].current_key_action = name

                crops.dirty.grid = true
                crops.dirty.screen = true
            end,
            -- formatter = function() return self:get_key_name() end
        }
    end
    do
        local name = 'mode'
        patcher.add_destination_and_param{
            type = 'number', name = name, id = ids[name], 
            min = 1, max = intervals_max, default = self[i][name], wrap = true,
            action = function(v)
                self[i][name] = v
                -- self:update_scale(i)
                crops.dirty.grid = true
                crops.dirty.screen = true
            end,
            formatter = function(p)
                local ivs = self[i].intervals

                return base_names[ivs][p:get()]
            end
        }
    end
    
end

function channels:update_modulation(i)
    local mod_key = params:get('base_key') + self[i].modulation
    self[i].modulation_semitones = ((mod_key * 7) + 1848) % 12
end

function channels:get_key_names(i)
    local grp = self:group_index(i)

    local current, nxt, prev = nil, nil, nil

    local accidental = nil
    local accidental_mod = (self[grp].modulation >= 0) and 'sharp' or 'flat'
    if self[grp].transposition_semitones==0 or self[grp].current_key_action == 'modulation' then
        accidental = accidental_mod
    else
        accidental = (
            (self[grp].transposition_semitones - self[grp].last_transposition_semitones) > 0
        ) and 'sharp' or 'flat'
    end

    current = key_names[accidental][
        (self[grp].modulation_semitones + self[grp].transposition_semitones) % 12
    ]
    nxt = key_names[accidental_mod][
        (self[grp].modulation_semitones + self[grp].transposition_semitones + 7) % 12
    ]
    prev = key_names[accidental_mod][
        (self[grp].modulation_semitones + self[grp].transposition_semitones - 7) % 12
    ]

    return current, nxt, prev
end

function channels:idx_to_deg_oct(i, idx)
    local ivs = self[i].intervals
    local x = (idx-1)%eggs.keymap_wrap
    local y = (idx-1)//eggs.keymap_wrap
    local oct = y + x//ivs + 1 - 1
    local deg = x%ivs + 1

    return deg, oct
end

function channels:get_semitones(i, idx, column)
    local deg, oct = self:idx_to_deg_oct(i, idx)

    local deg = (self[i].degree + column - 1)
    local scale = scales[self[i].intervals][self[grp].mode]
    local st = scale[(deg + (self[i].intervals * 48)) % self[i].intervals + 1]
    local off_oct = deg // self[i].intervals
    local note = st + self[grp].modulation_semitones 
                    + self[grp].transposition_semitones 
                    + ((off_oct) * 12)
    return note
end

return channels

-- I am SOOOOO lost, VS code is yelling at me that theres problems but like... IDK

local THIS_MOD = SMODS.current_mod
local cfg = THIS_MOD.config

if cfg.enabled == nil then cfg.enabled = true end
if cfg.test_mode == nil then cfg.test_mode = false end

local CONFIG_VERSION = 1
if cfg.cfg_version ~= CONFIG_VERSION then cfg.cfg_version = CONFIG_VERSION end

local BOSS_RED = HEX('AD5353')
local RED_DARK = HEX('7A3A3A')

local BB = {
    order = {},
    by_blind = {},
    blind_of = {},
    label = {},
    saved = true, shop_ready = false, shop_loading = false,
    open = nil, deferred_shop = false,
}
THIS_MOD.BB = BB
local function log(msg) sendInfoMessage(msg,'BossBounties') end

local function run_state()
    local g = G.GAME
    g.ntgbb = g.ntgbb or {}
    local st = g.ntgbb
    st.queue = st.queue or {}
    st.arm_pending = st.arm_pending or 0
    st.arm_active = st.arm_active or 0
    st.tooth_taken = st.tooth_taken or 0
    st.wall = st.wall or 0
    st.interest_bonus = st.interest_bonus or 0
    st.count = st.count or {}
    st.taken = st.taken or {}
    return st
end

SMODS.Atlas { key = 'bounties', path = 'bounties.png', px = 71, py = 95 }

SMODS.ConsumableType {
    key = 'BossBounty',
    primary_colour = BOSS_RED,
    secondary_colour = BOSS_RED,
    collection_rows = { 7, 7 },
    loc_txt = {
        name = 'Boss Bounty',
        collection = 'Boss Bounties',
        undiscovered = { name = 'Not Discovered', text = { 'Beat this Boss Blind', 'to see its bounty' } },
    },
}
local function juice(card, sound)
    G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.4, func = function ()
        play_sound(sound or 'tarot1')
        card:juice_up(0.3, 0.5)
        return true
    end}))
end

local CHIP_Y = {hook = 17, club = 17, goad = 17, head = 17, window = 17, manacle = 17, psychic = 17, pillar = 17, house = 17, wall = 17, wheel = 17, arm = 17, fish = 17, water = 17, mouth = 17, needle = 17, flint = 17, mark = 17, tooth = 17, eye = 17, plant = 17, serpent = 17, ox = 17, acorn = 17, bell = 28, heart = 28, leaf = 17, vessel = 28 }
BB.chips = {}

local function chip_sprite(blind)
    local atlas = G.ANIMATION_ATLAS and G.ANIMATION_ATLAS.blind_chips
    local b = G.P_BLINDS and G.P_BLINDS[blind]
    if not (atlas and b and b.pos) then return nil end
    local s = BB.chips[blind]
    if s and s.atlas == atlas and not s.REMOVED then return s end 
    s = AnimatedSprite(0, 0, 1, 1, atlas, b.pos)
    s.states.hover.can = false
    s.states.click.can = false
    s.states.drag.can = false
    s.states.collide.can = false
    BB.chips[blind] = s
    return s
end

function bb.draw_chip(card, blind, key)
    local center = card and card.children and card.children.center
    local s = center and chip_sprite(blind)
    if not s then return end
    local vt = center.vt
    local k = vt.scale or 1 
    local mx = k * vt.w * (71 - 34) / 2 / 71
    local my = k * vt.h * (CHIP_Y[key] or 17) / 95
    local r = vt.r or 0
    if r ~= 0 then
        local c, sn = math.cos(r), math.sin(r)
        mx, my = mx * c - my * sn, mx * sn + my * c
    end
    s.roll.draw_major = card
    s:draw_shader('dissolve', nil, nil, nil, center, 0, 0, mx, my)
end
local function  bounty(def)
    local key = 'mc_ntgbb_' .. def.key
    SMODS.Consumable{
        key = def.key,
        set = 'BossBounty',
        atlas = 'bounties',
        pos = def.pos,
        name = 'Bounty: ' .. def.boss,
        loc_txt = { name = def.boss .. ' Bounty', text = def.text},
        config = {},
        cost = 0,
        unlocked = true,
        Discovered = true,
        in_pool = function(self, args) return false end,
        can_use = def.can_use or function(self, card) return true end,
        loc_vars = def.loc_vars,
        draw = function(self, card, layer) BB.draw_chip(card, def.blind, def.key) end,

    }
    
end
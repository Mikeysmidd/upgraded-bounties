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

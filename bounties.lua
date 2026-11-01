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

local CHIP_Y = { hook = 17, club = 17, goad = 17, head = 17, window = 17, manacle = 17, psychic = 17, pillar = 17, house = 17, wall = 17, wheel = 17, arm = 17, fish = 17, water = 17, mouth = 17, needle = 17, flint = 17, mark = 17, tooth = 17, eye = 17, plant = 17, serpent = 17, ox = 17, acorn = 17, bell = 28, heart = 28, leaf = 17, vessel = 28 }
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

function BB.draw_chip(card, blind, key)
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

local function bounty(def)
    local key = 'c_ntgbb_' .. def.key
    SMODS.Consumable {
        key = def.key,
        set = 'BossBounty',
        atlas = 'bounties',
        pos = def.pos,
        name = 'Bounty: ' .. def.boss,   -- what the RunLogger writes
        loc_txt = { name = def.boss .. ' Bounty', text = def.text },
        config = {},
        cost = 0,
        unlocked = true,
        discovered = true,
        in_pool = function(self, args) return false end,
        can_use = def.can_use or function(self, card) return true end,
        loc_vars = def.loc_vars,
        draw = function(self, card, layer) BB.draw_chip(card, def.blind, def.key) end,
        use = function(self, card, area, copier)
            local entry = BB.take(self.key) or {}
            def.use(self, card, entry.data or {})
        end,
    }
    BB.order[#BB.order + 1] = key
    BB.pos = BB.pos or {}
    BB.pos[key] = def.pos.y * 7 + def.pos.x
    BB.by_blind[def.blind] = key
    BB.blind_of[key] = def.blind
    BB.label[key] = def.boss
end

local function printed_suit(c)
    if SMODS.has_no_suit(c) then return nil end
    return c.base and c.base.suit 
end

local function face_by_rank(c)
    if SMODS.has_no_rank(c) then return false end
    local r = c.base and SMODS.Ranks[c.base.value]
    return r and r.face and true or false
end

local function buff_cards(match, field, amount, colour)
    local n = 0
    for _,c in ipairs(G.playing_cards or {}) do
        if match(c) then
            c.ability[field] = (c.ability[field] or 0) + amount
            n = n + 1
        end
    end
    return n 
end

local function suit_bounty(def)
    bounty {
        key = def.key, blind = def.blind, boss = def.boss, pos = def.pos,
        text = {
            'Every {C:' .. def.colour .. '}' .. def.single .. '{} in your deck',
            'gains {C:chips}+20{} Chips, permanently',
            '{C:inactive}(Cards you own now, by printed suit){}',
        },
        use = function (self, card)
            juice(card)
            local n = buff_cards(function (c) return printed_suit(c) == def.suit end, 'perma_bonus', 20)
            log(def.boss .. ' bounty: +20 chips on ' .. n .. ' ' .. def.suit)
            delay(0.6)
            
        end,
    }
end

suit_bounty { key = 'club',   blind = 'bl_club',   boss = 'The Club',   pos = { x = 1, y = 0 }, suit = 'Clubs',    single = 'Club',    colour = 'clubs' }
suit_bounty { key = 'goad',   blind = 'bl_goad',   boss = 'The Goad',   pos = { x = 2, y = 0 }, suit = 'Spades',   single = 'Spade',   colour = 'spades' }
suit_bounty { key = 'head',   blind = 'bl_head',   boss = 'The Head',   pos = { x = 3, y = 0 }, suit = 'Hearts',   single = 'Heart',   colour = 'hearts' }
suit_bounty { key = 'window', blind = 'bl_window', boss = 'The Window', pos = { x = 4, y = 0 }, suit = 'Diamonds', single = 'Diamond', colour = 'diamonds' }

bounty {
    key = 'manacle', blind = 'bl_manacle', boss = 'The Manacle', pos = { x = 5, y = 0},
    text = { '{C:attention}+1{} hand size' }, 
    use = function(self, card) juice(card); G.hand:change_size(1); delay(0.6) end,
}

bounty{
    key = 'psychic', blind = 'bl_psychic', boss = 'The Psychic', pos = { x = 6, y = 0 },
    text = { '{C:attention}+1{} card slot', 'available in the shop' },
    use = function (self, card)
        juice(card)
        local n = buff_cards(function (c) return c.ability.ntgbb_pillar end, 'perma_bonus' , 20)
        for _, c in ipairs(G.playing_cards or {}) do c.ability.ntgbb_pillar = nil end
        log('The Pillar bounty: +20 chips on ' .. n .. 'cards')
        delay(0.6)
    end,
}

bounty {
    key = 'pillar', blind = 'bl_pillar', boss = 'The Pillar', pos = { x = 0, y = 1 },
    text = {
        'Every card you played against',
        'The Pillar gains {C:chips}+20{} Chips, permanently',
    },
    use = function(self, card)
        juice(card)
        local n = buff_cards(function(c) return c.ability.ntgbb_pillar end, 'perma_bonus', 20)
        for _, c in ipairs(G.playing_cards or {}) do c.ability.ntgbb_pillar = nil end
        log('The Pillar bounty: +20 chips on ' .. n .. ' cards')
        delay(0.6)
    end,
}

local function queue_sub(kind)
    local st = run_state()
    table.insert(st.queue, 1, { kind = kind })
    BB.saved = false
    log( 'Pack queued: ' .. kind)
end

bounty {
    key = 'house', blind = 'bl_house', boss = 'The House', pos = { x = 1, y = 1 },
    text = { 'Open a free', '{C:attention}Mega Standard Pack{}' },
    use = function(self, card) juice(card); queue_sub('standard') end,
}

bounty {
    key = 'wall', blind = 'bl_wall', boss = 'The Wall', pos = { x = 2, y = 1 },
    text = { 'Every future blind needs', '{C:attention}10%{} fewer chips', '{C:inactive}(Repeats multiply){}' },
    use = function(self, card)
        juice(card)
        local st = run_state()
        G.GAME.starting_params.ante_scaling = (G.GAME.starting_params.ante_scaling or 1) * 0.9
        st.wall = st.wall + 1
        log('The Wall bounty: ante_scaling now ' .. tostring(G.GAME.starting_params.ante_scaling))
        delay(0.6)
    end,
}

bounty {
    key = 'wheel', blind = 'bl_wheel', boss = 'The Wheel', pos = { x = 3, y = 1 },
    text = {'Gain a {C:dark_edition}Negative{}', '{C:attention}Oops! All 6s{}' },
    use = function (self, card)
        G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.4, func = function ()
            play_sound('timpani')
            SMODS.add_card({ key = 'j_oops', area = G.jokers, edition = 'e_negative' })
            card:juice_up(0.3, 0.5)
            return true
        end}))
        delay(0.6)
    end
}

bounty {
    key = 'arm', blind = 'bl_arm', boss = 'The Arm', pos = { x = 4, y = 1 },
    text = {
        'In the next blind you play,',
        'every hand you play gains',
        '{C:attention}+1{} level for its type',
    },
    use =function (self, card)
        juice(card)
        local st = run_state()
        st.arm_pending = st.arm_pending + 1
        log('The Arm bounty: ' .. st.arm_pending .. ' level(s) per hand next blind')
        delay(0.6)
    end,
}

bounty {
    key = 'fish', blind = 'bl_fish', boss = 'The Fish', pos = { x = 5, y = 1 },
    text = { '{C:red}+1{} discard, permanently'},
    use = function (self, card) juice(card); queue_sub('arcana') end,
}

bounty {
    key = 'water', blind = 'bl_water', boss = 'The Water', pos = { x = 6, y = 1 },
    text = { '{C:red}+1{} discard, permanently' },
    use = function(self, card)
        juice(card)
        G.GAME.round_resets.discards = G.GAME.round_resets.discards + 1
        ease_discard(1)
        delay(0.6)
    end,
}

bounty {
    key = 'mouth', blind = 'bl_mouth', boss = 'The Mouth', pos = { x = 0, y = 2 },
    text = { 'The hand type you played', 'gains {C:attention}+2{} levels' },
    use = function(self, card, data)
        local hand = data.hand
        if not (hand and G.GAME.hands[hand]) then hand = G.GAME.last_hand_played end
        if hand and G.GAME.hands[hand] then
            level_up_hand(card, hand, nil, 2)
            log('The Mouth bounty: ' .. hand .. ' +2 levels')
        end
    end,
}

bounty {
    key = 'needle', blind = 'bl_needle', boss = 'The Needle', pos = { x = 1, y = 2 },
    text = { '{C:blue}+1{} hand, permanently' }, 
    use = function (self, card)
        juice(card)
        G.GAME
        
    end
}
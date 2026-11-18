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
--- Manacle
bounty {
    key = 'manacle', blind = 'bl_manacle', boss = 'The Manacle', pos = { x = 5, y = 0},
    text = { '{C:attention}+1{} hand size' }, 
    use = function(self, card) juice(card); G.hand:change_size(1); delay(0.6) end,
}
--- Psychic
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
--- Pillar
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
--- House
bounty {
    key = 'house', blind = 'bl_house', boss = 'The House', pos = { x = 1, y = 1 },
    text = { 'Open a free', '{C:attention}Mega Standard Pack{}' },
    use = function(self, card) juice(card); queue_sub('standard') end,
}
--- Wall
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
--- Wheel
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
--- Arm
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
--- Fish
bounty {
    key = 'fish', blind = 'bl_fish', boss = 'The Fish', pos = { x = 5, y = 1 },
    text = { '{C:red}+1{} discard, permanently'},
    use = function (self, card) juice(card); queue_sub('arcana') end,
}
--- Water
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
--- Mouth
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
--- Needle
bounty {
    key = 'needle', blind = 'bl_needle', boss = 'The Needle', pos = { x = 1, y = 2 },
    text = { '{C:blue}+1{} hand, permanently' }, 
    use = function (self, card)
        juice(card)
        G.GAME.round_resets.hands = G.GAME.round_resets.hands + 1 
        ease_hands_played(1)
        delay(0.6)
    end,
}
--- Mark
bounty {
    key = 'mark', blind = 'bl_mark', boss = 'The Mark', pos = { x = 3, y = 2 },
    text = { 'Every Jack, Queen and King', 'in your deck gains {C:mult}+2{}', 'permanently' },
    use = function (self, card)
        juice(card)
        local n = buff_cards(face_by_rank, 'perma_mult', 2)
        log('The Mark bounty: +2 Mult on ' .. n .. ' face cards')
        delay(0.6)
    end,
}
--- Tooth
bounty {
    key = 'tooth', blind = 'bl_tooth', boss = 'The Tooth', pos = { x = 4, y = 2},
    text = { 'Get back {C:money}double{} what', 'The Tooth took from you' },
    use = function (self, card, data)
        local n = tonumber(data.tooth) or 0
        G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.4, func = function ()
            play_sound('timpani')
            card:juice_up(0.3, 0.5)
            if n > 0 then ease_dollars(2 * n, true) end
            return true
        end}))
        log('The Tooth bounty: took $' .. n .. ', pays $' .. 2* n)
        delay(0.6)
    end,
}
--[[ Eye
this is basically just a copy of the black hole, planet card
]]
bounty {
    key = 'eye', blind = 'bl_eye', boss = 'The Eye', pos = { x = 5, y = 2},
    text = { '{C:attention}+1{} level to', 'every poker hand' },
    use = function (self, card)
        update_hand_text({ sound = 'button', volume = 0.7, pitch = 0.8, delay = 0.3 }, { handname = localize('k_all_hands'), chips = '...', mult = '...', level = '' })
        G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.2, func = function()
            play_sound('tarot1'); card:juice_up(0.8, 0.5); G.TAROT_INTERRUPT_PULSE = true; return true end }))
        update_hand_text({ delay = 0 }, { mult = '+', StatusText = true })
        G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.9, func = function()
            play_sound('tarot1'); card:juice_up(0.8, 0.5); return true end }))
        update_hand_text({ delay = 0 }, { chips = '+', StatusText = true })
        G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.9, func = function()
            play_sound('tarot1'); card:juice_up(0.8, 0.5); G.TAROT_INTERRUPT_PULSE = nil; return true end }))
        update_hand_text({ sound = 'button', volume = 0.7, pitch = 0.9, delay = 0 }, { level = '+1' })
        delay(1.3)
        for k, _ in pairs(G.GAME.hands) do level_up_hand(card, k, true) end
        update_hand_text({ sound = 'button', volume = 0.7, pitch = 1.1, delay = 0 }, { mult = 0, chips = 0, handname = '', level = '' })
    end,
}
--- Plant
bounty {
    key = 'plant', blind = 'bl_plant', boss = 'The Plant', pos = { x = 6, y = 2},
    text = { 'Every Jack, Queen, and King', 'in your deck gains {C:chips}+20{} Chips', 'permanently' }, 
    use = function (self, card)
        juice(card)
        local n = buff_cards(face_by_rank, 'perma_bonus', 20)
        log('The Plant bounty: +20 chips on ' .. n .. ' face cards')
        delay(0.6)
    end,
}
--- Ox
bounty {
    key = 'ox', blind = 'bl_ox', boss = 'The Ox', pos = { x = 1, y = 3}, 
    text = { '{C:money}+$5{} maximum interest', 'per round', '{C:inactive}(Interest cap +$25){}' },
    use = function (self, card)
        juice(card, 'timpani')
        local st = run_state()
        st.interest_bonus = st.interest_bonus + 25
        G.GAME.interest_cap = (G.GAME.interest_cap or 25) + 25
        log('The Ox bounty: interest cap now ' .. G.GAME.interest_cap)
        delay(0.6)
    end,
}
--[[ Leaf
basically another antimatter.
]]
bounty {
    key = 'leaf', blind = 'bl_final_leaf', boss = 'Verdant Leaf', pos = { x = 5, y = 3 },
    text = { '{C:dark_edition}+1{} Joker slot' },
    use = function (self, card)
        juice(card)
        G.E_MANAGER:add_event(Event({ func = function ()
           if G.jokers then G.jokers.config.card_limit = G.jokers.config.card_limit + 1 end
           return true
        end}))
        delay(0.6)
    end,
}
--[[ Vessel
gives a free soul card (aka legendary jonkler)
]]
bounty {
    key = 'vessel', blind = 'bl_final_vessel', boss = 'Violet Vessel', pos = { x = 6, y = 3 },
    text = {
        'Gain a {C:dark_edition}Negative{} {C:spectral} The Soul{}.',
        'Its {C:legendary,E:1}legendary{} is {C:dark_edition}Negative{} too', 
        '{C:inactive}(Usable with a full Joker){}',
    },
    use = function (self, card)
        G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.4, func = function ()
            play_sound('timpani')
            local soul = SMODS.add_card({ key = 'c_soul', area = G.consumables, edition = 'e_negative' })
            soul.ability.ntgbb_vessel = true
            card:juice_up(0.3, 0.5)
            return true
        end }))
        delay(0.6)
    end,
}

local LIGHT = HEX('F4C2C2')
local PICKERS = {}

local function hand_name(hand) return localize(hand, 'poker_hands') end

local function describe_front(key)
    local f = G.P_CARDS[key]
    if not f then return tostring(key) end
    local ok1, r = pcall(localize, f.value, 'ranks')
    local ok2, r = pcall(localize, f.suit, 'suits_plural')
    r = (ok1 and type(r) == 'string' and r ~= 'ERROR') and r or f.value
    s = (ok2 and type(s) == 'string' and s ~= 'ERROR') and s or f.suit
    return r .. ' of ' .. s
end

local function picker_status()
    local P = BB.picker
    if not P then return end
    local kind = P.spec.kind
    if kind == 'deck' then
        P.status = P.count .. ' / ' .. P.spec.max .. ' selected'
    elseif kind == 'hand' then
        local h = P.hand and G.GAME.hands[P.hand]
        P.status = h and (hand_name(P.hand) .. ': level ' .. (h.level or 1) .. ' -> ' .. 2 * (h.level or 1)) or 'Pick a poker hand'
    elseif kind == 'serpent' then
        local n = 0
        for i = 1, #P.fronts do if P.enh[i] then n = n + 1 end end
        P.status = n .. ' / ' .. #P.fronts .. ' chosen'
    end
end

local function picker_valid(P)
    if not P then return false end
    local kind = P.spec.kind
    if kind == 'deck' then return P.count >= P.spec.min and P.count <= P.spec.max end
    if kind == 'hand' then return P.hand ~= nil and G.GAME.hands[P.hand] ~= nil end
    if kind == 'serpent' then
        if #P.fronts == 0 then return false end
        for i = 1, #P.fronts do if not (P.enh[i] and G.P_CENTERS[P.enh[i]]) then return false end end
        return true
    end
    return false
end

local function row_can_highlight(self, card) return BB.picker ~= nil end
local function row_unhighlight_all(self) end

local function row_add(self, card, silent)
    local P = BB.picker
    local orig = card.ntgbb_orig
    if not (P and orig) or P.selected[orig] then return end
    if P.spec.max == 1 then
        for _, row in ipairs(P.rows or {}) do
            for i = #row.highlighted, 1, -1 do
                local h = row.highlighted[i]
                table.remove(row.highlighted, i)
                h:highlight(false)
            end
        end
        P.selected, P.count = {}, 0
    elseif P.count >= P.spec.max then
        card:highlight(false)
        return
    end
    self.highlighted[#self.highlighted + 1] = card
    card:highlight(true)
    P.selected[orig] = true
    P.count = P.count + 1
    picker_status()
    if not silent then play_sound('cardSlide1') end
end

local function row_remove(self, card, force)
    for i = #self.highlighted, 1, -1 do
        if self.highlighted[i] == card then table.remove(self.highlighted, i); break end
    end
    card:highlight(false)
    local P = BB.picker
    if not force and P and card.ntgbb_orig and P.selected[card.ntgbb_orig] then
        P.selected[card.ntgbb_orig] = nil
        P.count = P.count - 1
        picker_status()
    end
end

local function picker_rows()
    local P = BB.picker
    local by_suit, suit_order = {}, {}
    for i = #SMODS.Suit.obj_buffer, 1, -1 do
        local s = SMODS.Suit.obj_buffer[i]
        by_suit[s] = {}
        suit_order[#suit_order + 1] = s
    end
    local cards = {}
    for _, c in ipairs(G.playing_cards) do cards[#cards + 1] = c end
    table.sort(cards, function(a, b) return a:get_nominal('suit') > b:get_nominal('suit') end)
    for _, c in ipairs(cards) do
        if c.base.suit and by_suit[c.base.suit] then table.insert(by_suit[c.base.suit], c) end
    end
    local visible = {}
    for _, s in ipairs(suit_order) do if by_suit[s][1] then visible[#visible + 1] = s end end
    P.pages = math.max(1, math.ceil(#visible / 4))
    P.page = math.min(P.page or 1, P.pages)
    P.rows = {}
    local rows = {}
    for j = (P.page - 1) * 4 + 1, math.min(#visible, P.page * 4) do
        local list = by_suit[visible[j]]
        local area = CardArea(G.ROOM.T.x + 0.2 * G.ROOM.T.w / 2, G.ROOM.T.h, 6.5 * G.CARD_W, 0.6 * G.CARD_H, {
            card_limit = #list, type = 'title', view_deck = true, highlight_limit = P.spec.max,
            card_w = G.CARD_W * 0.7, draw_layers = { 'card' }, negative_info = 'playing_card',
        })
        area.can_highlight = row_can_highlight
        area.add_to_highlighted = row_add
        area.remove_from_highlighted = row_remove
        area.unhighlight_all = row_unhighlight_all
        for _, orig in ipairs(list) do
            local copy = copy_card(orig, nil, 0.7)
            copy.ntgbb_orig = orig
            copy.T.x = area.T.x + area.T.w / 2
            copy.T.y = area.T.y
            copy:hard_set_T()
            area:emplace(copy)
            if P.selected[orig] then
                area.highlighted[#area.highlighted + 1] = copy
                copy:highlight(true)
            end
        end
        P.rows[#P.rows + 1] = area
        rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0 }, nodes = { { n = G.UIT.O, config = { object = area } } } }
    end
    return rows
end

local function picker_body()
    local P = BB.picker
    local nodes = {
        { n = G.UIT.R, config = { align = 'cm' }, nodes = {
            { n = G.UIT.C, config = { align = 'cm', padding = 0.1, r = 0.1, colour = G.C.BLACK, emboss = 0.05 }, nodes = picker_rows() },
        } },
    }
    if P.pages > 1 then
        local options = {}
        for i = 1, P.pages do options[i] = localize('k_page') .. ' ' .. i .. '/' .. P.pages end
        nodes[#nodes + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
            create_option_cycle({
                options = options, w = 4.5, cycle_shoulders = true, opt_callback = 'ntgbb_picker_page',
                current_option = P.page, colour = BOSS_RED, no_pips = true, focus_args = { snap_to = true, nav = 'wide' },
            }),
        } }
    end
    return { n = G.UIT.ROOT, config = { align = 'cm', colour = G.C.CLEAR }, nodes = nodes }
end

local function idle_colour() return darken(G.C.JOKER_GREY, 0.1) end

local function visible_hands()
    local out = {}
    for _, h in ipairs(G.handlist or {}) do
        if G.GAME.hands[h] and SMODS.is_poker_hand_visible(h) then out[#out+1] = h end
    end
    return out
end

local function chips_mult(chips, mult)
    return { n = G.UIT.C, config = { align = 'cm', padding = 0.05, colour = G.C.BLACK, r = 0.1 }, nodes = {
        { n = G.UIT.C, config = { align = 'cr', padding = 0.01, r = 0.1, colour = G.C.CHIPS, minw = 1.1 }, nodes = {
            { n = G.UIT.T, config = { text = number_format(chips, 1000000), scale = 0.4, colour = G.C.UI.TEXT_LIGHT } },
            { n = G.UIT.B, config = { w = 0.08, h = 0.01 } },
        } },
        { n = G.UIT.T, config = { text = 'X', scale = 0.4, colour = G.C.MULT } },
        { n = G.UIT.C, config = { align = 'cl', padding = 0.01, r = 0.1, colour = G.C.MULT, minw = 1.1 }, nodes = {
            { n = G.UIT.B, config = { w = 0.08, h = 0.01 } },
            { n = G.UIT.T, config = { text = number_format(mult, 1000000), scale = 0.4, colour = G.C.UI.TEXT_LIGHT } },
        } },
    } }
end

local function level_pill(level)
    return { n = G.UIT.C, config = { align = 'cm', padding = 0.01, r = 0.1, minw = 1.1, outline = 0.8, outline_colour = G.C.WHITE,
        colour = G.C.HAND_LEVELS[math.max(0, math.min(7, level))] }, nodes = {
        { n = G.UIT.T, config = { text = localize('k_level_prefix') .. level, scale = 0.4, colour = G.C.UI.TEXT_DARK } },
    } }
end

local function hand_row(hand)
    local h = G.GAME.hands[hand]
    local level = h.level or 1
    return { n = G.UIT.R, config = { align = 'cm', padding = 0.05, r = 0.1, emboss = 0.05, hover = true, shadow = true,
        colour = idle_colour(), button = 'ntgbb_pick_hand', func = 'ntgbb_hand_row', ntgbb_hand = hand,
        on_demand_tooltip = { text = localize(hand, 'poker_hand_descriptions'), filler = { func = create_UIBox_hand_tip, args = hand } } }, nodes = {
        level_pill(level),
        { n = G.UIT.C, config = { align = 'cl', minw = 3.6, maxw = 3.6 }, nodes = {
            { n = G.UIT.T, config = { text = '  ' .. hand_name(hand), scale = 0.4, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
        } },
        chips_mult(h.chips, h.mult),
        { n = G.UIT.C, config = { align = 'cm', minw = 0.6 }, nodes = {
            { n = G.UIT.T, config = { text = '->', scale = 0.4, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
        } },
        level_pill(level * 2),
        chips_mult(h.chips * 2, h.mult * 2),
    } }
end

local function hand_body()
    local hands = visible_hands()
    local per_col = #hands > 12 and math.ceil(#hands / 2) or #hands
    local cols = {}
    for i, hand in ipairs(hands) do
        local c = math.ceil(i / per_col)
        cols[c] = cols[c] or { n = G.UIT.C, config = { align = 'tm', padding = 0.05 }, nodes = {} }
        table.insert(cols[c].nodes, hand_row(hand))
    end
    return { n = G.UIT.C, config = { align = 'cm', padding = 0.1, r = 0.1, colour = G.C.BLACK, emboss = 0.05 }, nodes = {
        { n = G.UIT.R, config = { align = 'cm' }, nodes = cols },
    } }
end

G.FUNCS.ntgbb_hand_row = function(e)
    local P = BB.picker
    e.config.colour = (P and P.hand == e.config.ntgbb_hand) and BOSS_RED or idle_colour()
end

G.FUNCS.ntgbb_pick_hand = function(e)
    local P = BB.picker
    if not (P and e.config.ntgbb_hand) then return end
    P.hand = e.config.ntgbb_hand
    picker_status()
end

local function enh_add(self, card, silent)
    local P = BB.picker
    if not (P and card.ntgbb_enh and card.ntgbb_row) then return end
    for i = #self.highlighted, 1, -1 do
        local h = self.highlighted[i]
        table.remove(self.highlighted, i)
        h:highlight(false)
    end
    self.highlighted[#self.highlighted+1] = card
    card:highlight(true)
    P.enh[card.ntgbb_row] = card.ntgbb_enh
    picker_status()
    if not silent then play_sound('cardSlide1') end
end

local function enh_remove(self, card, force)
    for i = #self.highlighted, 1, -1 do
        if self.highlighted[i] == card then table.remove(self.highlighted, i); break end
    end
    card:highlight(false)
    local P = BB.picker
    if not force and P and card.ntgbb_row and P.enh[card.ntgbb_row] == card.ntgbb_enh then
        P.enh[card.ntgbb_row] = nil
        picker_status()
    end
end

local function enhancement_keys()
    local t = {}
    for _, center in ipairs(G.P_CENTER_POOLS.Enhanced or {}) do
        if center.key and G.P_CENTERS[center.key] then t[#t + 1] = center.key end
    end
    return t
end

local function serpent_body()
    local P = BB.picker
    local enhs = enhancement_keys()
    local rows = {}
    P.rows = {}
    for i, fk in ipairs(P.fronts) do
        local area = CardArea(G.ROOM.T.x + 0.2 * G.ROOM.T.w / 2, G.ROOM.T.h, math.max(1, #enhs) * G.CARD_W * 0.75, 0.75 * G.CARD_H, {
            card_limit = math.max(1, #enhs), type = 'title', highlight_limit = 1,
            card_w = G.CARD_W * 0.7, draw_layers = { 'card' },
        })
        area.can_highlight = row_can_highlight
        area.add_to_highlighted = enh_add
        area.remove_from_highlighted = enh_remove
        area.unhighlight_all = row_unhighlight_all
        for _, ek in ipairs(enhs) do
            local c = Card(area.T.x + area.T.w / 2, area.T.y, G.CARD_W * 0.7, G.CARD_H * 0.7, G.P_CARDS[fk], G.P_CENTERS[ek])
            c.ntgbb_enh, c.ntgbb_row = ek, i
            area:emplace(c)
            if P.enh[i] == ek then
                area.highlighted[#area.highlighted + 1] = c
                c:highlight(true)
            end
        end
        P.rows[#P.rows + 1] = area
        rows[#rows + 1] = { n = G.UIT.R, config = { align = 'cm', padding = 0.03 }, nodes = {
            { n = G.UIT.C, config = { align = 'cm', minw = 2.2 }, nodes = {
                { n = G.UIT.T, config = { text = describe_front(fk), scale = 0.38, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
            } },
            { n = G.UIT.O, config = { object = area } },
        } }
    end
    return { n = G.UIT.C, config = { align = 'cm', padding = 0.1, r = 0.1, colour = G.C.BLACK, emboss = 0.05 }, nodes = rows }
end

local function text_row_light(text)
    return { n = G.UIT.R, config = { align = 'cm', padding = 0.02 }, nodes = {
        { n = G.UIT.T, config = { text = text, scale = 0.35, colour = G.C.UI.TEXT_LIGHT } },
    } }
end

local function picker_button(label, scale, minh, colour, button, func)
    return { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
        { n = G.UIT.C, config = { align = 'cm', minw = 2.8, minh = minh, padding = 0.1, r = 0.1, hover = true, shadow = true,
            colour = colour, button = button, func = func }, nodes = {
            { n = G.UIT.T, config = { text = label, scale = scale, colour = G.C.UI.TEXT_LIGHT, shadow = true } },
        } },
    } }
end

local function picker_definition()
    local P = BB.picker
    local info = { n = G.UIT.C, config = { align = 'cm', padding = 0.1, minw = 3.4 }, nodes = {
        { n = G.UIT.R, config = { align = 'cm', padding = 0.08 }, nodes = {
            { n = G.UIT.T, config = { text = P.spec.title, scale = 0.6, colour = G.C.WHITE, shadow = true } },
        } },
        text_row_light(P.spec.line1),
        text_row_light(P.spec.line2),
        { n = G.UIT.R, config = { align = 'cm', padding = 0.15 }, nodes = {
            { n = G.UIT.T, config = { ref_table = P, ref_value = 'status', scale = 0.4, colour = LIGHT, shadow = true } },
        } },
        --- v1: built WITH its button, cleared by the func while the choice is not valid
        --- (an element only becomes clickable if built with a button, dump/engine/ui.lua:391).
        picker_button('Confirm', 0.5, 0.75, G.C.UI.BACKGROUND_INACTIVE, 'ntgbb_picker_confirm', 'ntgbb_picker_can_confirm'),
        picker_button(localize('b_back'), 0.45, 0.6, G.C.ORANGE, 'ntgbb_picker_back', nil),
    } }
    local body
    if P.spec.kind == 'hand' then
        body = hand_body()
    elseif P.spec.kind == 'serpent' then
        body = serpent_body()
    else
        body = { n = G.UIT.O, config = { id = 'ntgbb_picker_body', object = UIBox {
            definition = picker_body(), config = { offset = { x = 0, y = 0 }, align = 'cm' },
        } } }
    end
    return create_UIBox_generic_options({
        no_back = true,
        outline_colour = BOSS_RED,
        contents = {
            { n = G.UIT.R, config = { align = 'cm' }, nodes = {
                info,
                { n = G.UIT.B, config = { w = 0.2, h = 0.1 } },
                { n = G.UIT.C, config = { align = 'cm' }, nodes = { body } },
            } },
        },
    })
end

-- continue of the serpent
local function roll_serpent()
    local t = {}
    for i = 1, 3 do
        local _, key = pseudorandom_element(G.P_CARDS, pseudoseed('ntgbb_serp'))
        t[#t + 1] = key
    end
    return t
end

function BB.open_picker(card, spec)
    BB.picker = { card = card, spec = spec, selected = {}, count = 0, page = 1, enh = {}, fronts = {} }
    if spec.kind == 'serpent' then
        local e = open_entry()
        if e then
            e.data = e.data or {}
            if not (type(e.data.fronts) == 'table' and e.data.fronts[1]) then e.data.fronts = roll_serpent() end
            for _, fk in ipairs(e.data.fronts) do
                if G.P_CARDS[fk] then BB.picker.fronts[#BB.picker.fronts + 1] = fk end
            end
            --- A saved card that no longer exists (a removed rank or suit mod) would leave
            --- a screen that can never confirm: roll again and keep the new roll.
            if #BB.picker.fronts == 0 then
                e.data.fronts = roll_serpent()
                for _, fk in ipairs(e.data.fronts) do BB.picker.fronts[#BB.picker.fronts + 1] = fk end
            end
        end
    end
    picker_status()
    G.SETTINGS.paused = true
    --- As View Deck does (smods/src/overrides.lua:908); closing clears it
    G.VIEWING_DECK = true
    G.FUNCS.overlay_menu { definition = picker_definition(), config = { no_esc = true } }
    log('Picker opened: ' .. spec.title)
end

G.FUNCS.ntgbb_picker_page = function(args)
    local P = BB.picker
    if not (P and args and args.to_key) then return end
    P.page = args.to_key
    local holder = G.OVERLAY_MENU and G.OVERLAY_MENU:get_UIE_by_ID('ntgbb_picker_body')
    if not holder then return end
    if holder.config.object then holder.config.object:remove() end
    holder.config.object = UIBox {
        definition = picker_body(), config = { offset = { x = 0, y = 0 }, align = 'cm', parent = holder },
    }
    holder.UIBox:recalculate()
end

G.FUNCS.ntgbb_picker_can_confirm = function(e)
    if picker_valid(BB.picker) then
        e.config.colour = BOSS_RED
        e.config.button = 'ntgbb_picker_confirm'
    else
        e.config.colour = G.C.UI.BACKGROUND_INACTIVE
        e.config.button = nil
    end
end

G.FUNCS.ntgbb_picker_back = function(e)
    BB.picker = nil
    G.FUNCS.exit_overlay_menu()
    log('Picker: Back')
end

G.FUNCS.ntgbb_picker_confirm = function(e)
    local P = BB.picker
    if not picker_valid(P) then return end
    local picked = { card = P.card }
    if P.spec.kind == 'deck' then
        picked.cards = {}
        for _, c in ipairs(G.playing_cards) do
            if P.selected[c] then picked.cards[#picked.cards + 1] = c end
        end
    elseif P.spec.kind == 'hand' then
        picked.hand = P.hand
    elseif P.spec.kind == 'serpent' then
        picked.fronts, picked.enh = {}, {}
        for i, fk in ipairs(P.fronts) do picked.fronts[i] = fk; picked.enh[i] = P.enh[i] end
    end
    local card = P.card
    BB.picker = nil
    G.FUNCS.exit_overlay_menu()
    if not (card and G.pack_cards and card.area == G.pack_cards) then
        log('Picker: the bounty card is gone, nothing applied')
        return
    end
    BB.picked = picked
    G.FUNCS.use_card({ config = { ref_table = card } })
end

--- The choice Confirm handed to this card's use(). 
local function take_pick(card)
    local p = BB.picked
    BB.picked = nil
    if p and p.card == card then return p end
end

local function take_picks(card)
    local p = take_pick(card)
    local alive = {}
    if not (p and p.cards) then return alive end
    for _, c in ipairs(p.cards) do
        if not c.removed then
            for _, pc in ipairs(G.playing_cards) do
                if pc == c then alive[#alive + 1] = c; break end
            end
        end
    end
    return alive
end

local function describe_cards(cards)
    local names = {}
    for i, c in ipairs(cards) do names[i] = tostring(c.base and c.base.value) .. ' of ' .. tostring(c.base and c.base.suit) end
    return table.concat(names, ', ')
end

function BB.wrap_use_card()
    if BB.use_card_wrapped then return end
    BB.use_card_wrapped = true
    local ref_use_card = G.FUNCS.use_card
    G.FUNCS.use_card = function(e, mute, nosave)
        local card = e and e.config and e.config.ref_table
        local spec = card and card.config and card.config.center and PICKERS[card.config.center.key]
        if spec and G.pack_cards and card.area == G.pack_cards and not (BB.picked and BB.picked.card == card) then
            --- The Use button is one-press; hand it back for after Back.
            e.disable_button = nil
            BB.open_picker(card, spec)
            return
        end
        return ref_use_card(e, mute, nosave)
    end
end

local PICKER_CAN_USE = {
    deck = function() return G.playing_cards and G.playing_cards[1] and true or false end,
    hand = function() return G.handlist and G.GAME and G.GAME.hands and true or false end,
    serpent = function() return true end,
}

local function picker_bounty(def)
    def.picker.kind = def.picker.kind or 'deck'
    PICKERS['c_ntgbb_' .. def.key] = def.picker
    local can = PICKER_CAN_USE[def.picker.kind]
    def.can_use = function(self, card) return can() end
    bounty(def)
end


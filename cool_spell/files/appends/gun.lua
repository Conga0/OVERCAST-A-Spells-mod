local EZWand = dofile_once("mods/cool_spell/lib/EZWand.lua")
local OVERDRAW_cooldown = false
local wand = nil
local charge_chance = 100 --100% chance to consume

local draw_action_old = draw_action

function draw_action( instant_reload_if_empty ) -- replacing this function
	local action = nil
	
	--GamePrint("draw_action()")
	
	wand = EZWand.GetHeldWand() --OVERCAST code
	
	local OVERDRAW = false
	
	local player_entity = EntityGetWithTag("player_unit")[1]
	
	if player_entity ~= nil then
		local children = EntityGetAllChildren(player_entity)
		if children ~= nil then
			for i,v in ipairs(children) do
				local comp = EntityGetComponent( v, "GameEffectComponent", "selection_overcast" )
				if comp ~= nil then
					OVERDRAW = true
					break
				end
			end
		end
	end
	if OVERDRAW == false then
		if wand ~= nil then
			local spells, attached_spells = wand:GetSpells()
			OVERDRAW = false
			if spells ~= nil then
				for i,v in ipairs(spells) do
					if tostring(v.action_id) == "OVERCAST_OVERCAST" then
						OVERDRAW = true
						break
					end
				end
			end
			if attached_spells ~= nil then
				for i,v in ipairs(attached_spells) do
					if tostring(v.action_id) == "OVERCAST_OVERCAST" then
						OVERDRAW = true
						break
					end
				end
			end
		end
	end
	
	if #deck > 0 then
		-- draw from the start of the deck
		action = deck[ 1 ]
		
		if tostring(action.id) == "OVERCAST_CONSERVE" then -- v1.2.0
			charge_chance = charge_chance * 0.5
			--GamePrint("conserving: " .. charge_chance)
		end
		
		if not OVERDRAW then
			return draw_action_old(instant_reload_if_empty)
		end

		
		-- update mana
		local action_mana_required = action.mana
		if action.mana == nil then
			action_mana_required = ACTION_MANA_DRAIN_DEFAULT
		end

		if action_mana_required > mana then
			if OVERDRAW then --basicly cancel the regular behavior and set a varible so we know do something later
				table.remove( deck, 1 )
				if mana > 0 then
					mana = -wand.manaChargeSpeed
				end
				if OVERDRAW_cooldown == false then
					GamePrint("OVERCAST")
					local x, y = EntityGetTransform(wand.entity_id)
					GamePlaySound( "data/audio/Desktop/projectiles.bank", "player_projectiles/fizzle/create", x, y)
					GamePlaySound( "data/audio/Desktop/explosion.bank", "explosions/revenge_perk", x, y)
					GamePlaySound( "data/audio/Desktop/projectiles.bank", "projectiles/orb_c/destroy ", x, y)
					EntityLoad("mods/cool_spell/files/actions/overcast_effect.xml", x, y)
					local targets = EntityGetInRadiusWithTag( x, y, 64, "overcast_puzzle_reciever" )
					if targets[1] ~= nil then
						GamePrint("overcast_puzzle thing succed")
					end
				end
				OVERDRAW_cooldown = true 
				if action.uses_remaining == 0 then
					table.insert( discarded, action )
					
					return false -- <------------------------------------------ RETURNS (also never excutes old function D:)
				end

				mana = mana - action_mana_required
				play_action( action )
				
				return true -- <------------------------------------------ RETURNS (also never excutes old function D:)
			end
		end
	end
	return draw_action_old(instant_reload_if_empty)
end

--[[local draw_actions_old = draw_actions

function draw_actions( how_many, instant_reload_if_empty ) -- replace function
	GamePrint("draw_actions(" .. how_many .. " " .. tostring(instant_reload_if_empty) .. ")")

	if ( dont_draw_actions == false ) then
		charge_chance = 100
		
		wand = EZWand.GetHeldWand() --OVERCAST code
		if wand ~= nil then
			if mana >= wand.manaMax then -- check if cooldown over
				OVERDRAW_cooldown = false
			end
		end
		
		if OVERDRAW_cooldown == false then
			draw_actions_old(how_many, instant_reload_if_empty)
		else --OVERCAST code
			if reloading then return end 
			OnNotEnoughManaForAction()
			table.insert( discarded, action )
			GamePrint("Recovering from OVERCAST...")
			local x, y = EntityGetTransform(wand.entity_id)
			GamePlaySound( "data/audio/Desktop/projectiles.bank", "player_projectiles/fizzle/create", x, y)
			start_reload = true
			_handle_reload()
			return
		end
	end
end]]--

local move_hand_to_discarded_old = move_hand_to_discarded() --v1.1.1

function move_hand_to_discarded()
	for i,action in ipairs(hand) do
		
		SetRandomSeed(GameGetFrameNum()-120, GameGetFrameNum()+i)
		
		local identify = false
		if got_projectiles or (action.type == ACTION_TYPE_OTHER) or (action.type == ACTION_TYPE_UTILITY) then -- ACTION_TYPE_MATERIAL, ACTION_TYPE_PROJECTILE are handled via got_projectiles
			if action.uses_remaining > 0 then
				if action.custom_uses_logic then
					-- do nothing
				elseif action.is_identified then
					-- consume consumable actions
					action.uses_remaining = action.uses_remaining - 1
					local reduce_uses = ActionUsesRemainingChanged( action.inventoryitem_id, action.uses_remaining )
					if not reduce_uses then
						action.uses_remaining = action.uses_remaining + 1 -- cancel the reduction
					elseif( tonumber(Random(1,100)) > charge_chance ) then
							--GamePrint("conserved!")
							action.uses_remaining = action.uses_remaining + 1 -- cancel the reduction
					end
				end
			end

			identify = true
		end

		if identify then
			ActionUsed( action.inventoryitem_id )
			action.is_identified = true
		end

		if use_game_log then
			if action.is_identified then
				LogAction( action.name )
			else
				LogAction( "?" )
			end
		end

		if action.uses_remaining ~= 0 or action.custom_uses_logic then
			if action.permanently_attached == nil then
				table.insert( discarded, action )
			end
		end
	end
	hand = { }
end

-- for some reason saving this old function cuases everything to break

--[[local shot = {}
shot.state = {}
shot.num_of_cards_to_draw = 0]]--

local draw_shot_old = draw_shot

function draw_shot( shot, instant_reload_if_empty )

	if shot == nil then
		print_error("shot is nil!")
		return
	end

	charge_chance = 100

	wand = EZWand.GetHeldWand() --OVERCAST code
	if wand ~= nil then
		if wand.mana >= wand.manaMax then -- check if cooldown over
			OVERDRAW_cooldown = false
		end
	end
	
	if wand.mana < 0 then -- extra check, since swapping wands can do funny stuff
		OVERDRAW_cooldown = true
	end
	
	--GamePrint(tostring(OVERDRAW_cooldown))
	
	if OVERDRAW_cooldown then --OVERCAST code
		if reloading then return end 
		OnNotEnoughManaForAction()
		table.insert( discarded, action )
		GamePrint("Recovering from OVERCAST...")
		local x, y = EntityGetTransform(wand.entity_id)
		GamePlaySound( "data/audio/Desktop/projectiles.bank", "player_projectiles/fizzle/create", x, y)
		start_reload = true
		_handle_reload()
		return
	else
		draw_shot_old(shot, instant_reload_if_empty)
	end
end

-- hope i dont break too many compats hehe
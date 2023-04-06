local playerAlreadyConnected = false
local ConnectedHydrantID = nil

----- DEVELOPER MODE -----
if Config.EnableDeveloperMode then
	RegisterCommand("weaponhash", function(source, args)
		local playerPed = GetPlayerPed(-1)
	
		-- Get the weapon hash of the weapon the player is holding
		local weaponHash = GetSelectedPedWeapon(playerPed)
	
		-- Print the weapon hash to the console
		print("Weapon hash for the player's current weapon: " .. tostring(weaponHash))
	end)
end

----- CONNECTION (NON- bt-target) -----
Citizen.CreateThread(function()
	while true do
		Citizen.Wait(1)
		for k,v in pairs(Config.HydrantModels) do
			local nearesthydrant = GetClosestObjectOfType(GetEntityCoords(PlayerPedId()), Config.ConnectionDistance, v, false, true, true)
			local hydrant = GetEntityModel(nearesthydrant)
			if hydrant == v and playerAlreadyConnected == false then
				while #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(nearesthydrant)) <= Config.ConnectionDistance and playerAlreadyConnected == false do
					Citizen.Wait(0)

					if Config.Use3DText then
						DrawText3D(GetEntityCoords(nearesthydrant), "Press ~y~[E]~s~ to connect to hydrant", 0.5, 0.2, 0.2)
					else
						ShowHelpNotification('Press ~INPUT_CONTEXT~ to connect to hydrant')
					end
					
					if IsControlJustReleased(0, 51) then
						TriggerEvent('FireHydrant:Connect', v)
					end
				end
			end
		end
	end
end)

----- Check the distance from the connected hydrant -----
Citizen.CreateThread(function()
	while not NetworkIsSessionStarted() do
		Wait(500)
	end

	while true do
		Citizen.Wait(1)
		if playerAlreadyConnected then
			-- Get the player
			local playerPed = GetPlayerPed(-1)

			-- Make sure they have the hydrant hose in their hand
			GiveWeaponToPed(playerPed, -1554970529, 1000, false, false)

			-- Set the player's current weapon to the new weapon
			SetCurrentPedWeapon(playerPed, -1554970529, true)

			-- Get info
			local playerCoords = GetEntityCoords(PlayerPedId())
			local hydrantCoords = GetEntityCoords(ConnectedHydrantID)
			
			-- Draw Distance Text
			SetTextFont(0)
        	SetTextScale(0.4, 0.4)
        	SetTextEntry("STRING")
        	AddTextComponentString('~y~Hose Distance: ~g~' .. math.floor(#(playerCoords - hydrantCoords)) .. '~w~/~r~' .. Config.MaxDistance) -- Main Text string
        	DrawText(0.1725, 0.8)
			-- End Draw Distance Text

			-- Auto Disconnect Warning
			if #(playerCoords - hydrantCoords) >= Config.MaxDistance - Config.DistanceWarningValue and Config.DistanceWarning == true then
				-- Show Notification
				ShowNotification('~y~[WARNING]~w~ You are 2.0 meters away from auto disconnect')
			end
			
			-- Auto Disconnect
			if #(playerCoords - hydrantCoords) >= Config.MaxDistance then
				-- Show Notification
				ShowNotification('~y~[WARNING]~w~ You have been auto-disconnected from the hydrant due to distance')
				
				-- Print to log
				if Config.EnableDebug then
					print('Disconnected from hydrant ID: ' .. tostring(ConnectedHydrantID))
				end
				
				-- Toggle hose
				ExecuteCommand('hose')
				
				-- Update information
				playerAlreadyConnected = false
				ConnectedHydrantID = nil
			end
		end
	end
end)

----- Give the option to disconnect from hydrant -----
Citizen.CreateThread(function()
	while not NetworkIsSessionStarted() do
		Wait(500)
	end

	while true do
		Citizen.Wait(1)
		if playerAlreadyConnected then
			while #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(ConnectedHydrantID)) <= 2.0 do
				Citizen.Wait(0)
				if playerAlreadyConnected then
					if Config.Use3DText then
						DrawText3D(GetEntityCoords(ConnectedHydrantID) + 1, "Press ~y~[E]~s~ to disconnect from hydrant", 0.5, 0.2, 0.2)
					else
						ShowHelpNotification('Press ~INPUT_CONTEXT~ to disconnect from hydrant')
					end
					if IsControlJustReleased(0, 51) then
						-- Toggle Hose
						--TriggerEvent('dubCase-HoseFix:Toggle')
						ExecuteCommand('hose')

						-- Update information
						playerAlreadyConnected = false
						ConnectedHydrantID = nil

						-- Show notification
						ShowNotification('~g~[SUCCESS]~w~ You have disconnected from the hydrant')
					end
				end
			end
		end
	end
end)

----- Make sure the player cannot hold the extinguisher if they are not connected -----
Citizen.CreateThread(function()
	while not NetworkIsSessionStarted() do
		Wait(500)
	end

	while true do
		Citizen.Wait(1)
		if not playerAlreadyConnected then
			local playerPed = GetPlayerPed(-1)
    		RemoveWeaponFromPed(playerPed, -1554970529)
		end
	end
end)

----- CONNECTION EVENT -----
RegisterNetEvent('FireHydrant:Connect')
AddEventHandler('FireHydrant:Connect', function(hydrantHash)
	if playerAlreadyConnected then
		ShowNotification('~r~[ERROR]~w~ You are already connected to a hydrant!')
	else
		-- Get the player coords
		local playerCoords = GetEntityCoords(PlayerPedId())

		-- Get the hydrant handle
		local hydrantHandle = GetClosestObjectOfType(playerCoords.x, playerCoords.y, playerCoords.z, Config.ConnectionDistance, hydrantHash, false, false, false)

		-- Get the object to net
		local hydrantID = ObjToNet(hydrantHandle)

		-- Print debug
		if Config.EnableDebug then
			print('Connected to hydrant ID: ' .. tostring(hydrantID))
			local hydrantCoords = GetEntityCoords(hydrantID)
			print('Coords: ' .. tostring(hydrantCoords))
		end

		-- Set our bool for the player having a connection
		playerAlreadyConnected = true
		ConnectedHydrantID = hydrantID

		-- Show notification
		ShowNotification('~g~[SUCCESS]~w~ You have connected to the hydrant')

		-- Toggle the event
		ExecuteCommand('hose')
	end
end)

----- FUNCTIONS -----
function ShowHelpNotification(message, makeSound, duration)
	BeginTextCommandDisplayHelp("THREESTRINGS")
	AddTextComponentSubstringPlayerName(message)
    EndTextCommandDisplayHelp(0, false, makeSound, duration)
end

function DrawGroundMarker(x, y, z)
	DrawMarker(25, x, y, z - 1, 0.0, 0.0, 0.0, 0.0, 180.0, 0.0, 5.0, 5.0, 5.0, 3, 15, 250, 75, false, true, 2, nil, nil, false)
end

function ShowNotification(message)
	SetNotificationTextEntry('STRING')
	AddTextComponentSubstringPlayerName(message)
	DrawNotification(false, true)
end

function DrawText3D(coords, text, scale, font, align)
    local x2, y2, z2 = table.unpack(coords)
    local onScreen, _x, _y = World3dToScreen2d(x2, y2, z2)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    local dist = #(vector3(px, py, pz) - vector3(x2, y2, z2))
    local scale = (scale / dist) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    local scale = scale * fov

    if onScreen then
        SetTextScale(scale, scale)
        SetTextFont(font)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 255)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextCentre(align)
        SetTextEntry("STRING")
        SetTextCentre(true)
        AddTextComponentString(text)
        DrawText(_x,_y)
    end
end
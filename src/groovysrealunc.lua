local Services = setmetatable({}, {
	__index = function(self, key)
		local s = game:GetService(key)
		rawset(self, key, s)
		return s
	end
})

local function debug_tampered()
	local function create_nested_coro(depth)
		if depth == 199 then
			return coroutine.wrap(function()
				local success, result = pcall(function()
					return debug.info(debug.info, "s") ~= "[C]"
				end)
				return success, result
			end)
		else
			return coroutine.wrap(function()
				return create_nested_coro(depth + 1)
			end)
		end
	end

	local coro = create_nested_coro(1)

	for i = 1, 199 do
		if i == 199 then
			local success, result = coro()
			return success and result == true
		else
			coro = coro()
		end
	end

	return false
end

local is_debug_screwed = debug_tampered()

local function Is_C_Function(func)
	local info = debug.info(func, "s")
	return info == "[C]"
end


local ReflectionService = game:GetService("ReflectionService")

local function getreadable_andwriteable(instance)
	local props = {}
	local className = instance.ClassName
	local infos = ReflectionService:GetPropertiesOfClass(className)

	for _, info in infos do
		local name = info.Name

		if info.Permits and info.Permits.Write then

			if info.Display and info.Display.DeprecationMessage then
			else
				local ok, value = pcall(function()
					return instance[name]
				end)

				if ok then
					props[name] = value
				end
			end
		end
	end

	return props
end

local sections = {

	{
		name = "Loadstring",
		enabled = true,
		tests = {
			["Loadstring Is Enabled"] = function()
				local ok, err = pcall(loadstring, "x=1")
				if not ok then
					return false
				end
				return true
			end,

			["Loadstring Is An Untampered Native (C) Function"] = function()
				if is_debug_screwed then return nil, "debug library has been tampered with; result is uncertain" end
				if not Is_C_Function(loadstring) then
					return false, "loadstring is not a C function — it has been replaced or wrapped"
				end
				return true
			end,

			["Loadstring Accepts vLuau (Typed Luau) Syntax"] = function()
				if Is_C_Function(loadstring) then
					return false, "loadstring is the native C function and has not been replaced with a vLuau variant"
				end
				local ok, err = pcall(loadstring, "for i,v:Instance in workspace:GetChildren() do print(v);end")
				if not ok then
					return false
				end
				return true
			end,

			["Loadstring Accepts vLua (Legacy Lua) Syntax"] = function()
				if Is_C_Function(loadstring) then
					return false, "loadstring is the native C function and has not been replaced with a vLua variant"
				end
				local ok, err = pcall(loadstring, "for i,v in pairs(workspace:GetChildren()) do print(v);end")
				if not ok then
					return false
				end
				return true
			end,
		},
	},

	{
		name = "Server Configuration",
		enabled = true,
		tests = {
			["HTTP Requests Are Enabled And Reachable"] = function()
				if not Is_C_Function(Services.HttpService.GetAsync) or not Is_C_Function(Services.HttpService.PostAsync) then
					return nil, "HttpService.GetAsync or PostAsync has been tampered with"
				end
				if not Services.HttpService.HttpEnabled then
					return false
				end
				local ok, err = pcall(function()
					Services.HttpService:GetAsync("https://google.com/")
				end)
				if not ok then
					return false, "HttpEnabled is true but a live request failed: " .. tostring(err)
				end
				return true
			end,

			["Workspace Streaming Is Disabled"] = function()
				return not workspace.StreamingEnabled
			end,

			["BanAsync Is Disabled For This Experience"] = function()
				local ok, err = pcall(function()
					Services.Players:BanAsync({
						UserIds = {1},
						ApplyToUniverse = true,
						Duration = -1,
						DisplayReason = "x",
						PrivateReason = "x",
						ExcludeAltAccounts = false
					})
				end)
				if not ok and err and err:find("BanningEnabled") then
					return true
				end
				return false
			end,

			["Signals Fire Immediately (Deferred Events Are Off)"] = function()
				local fired = false
				local e = Instance.new("BindableEvent")
				e.Event:Once(function()
					fired = true
				end)
				e:Fire()
				return fired
			end,

			["Asset Loading Via AssetService Works"] = function()
				return pcall(function()
					game:GetService("AssetService"):LoadAssetAsync(14102233829)
				end)
			end,
		},
	},

	{
		name = "Script Environment",
		enabled = true,
		tests = {
			["'owner' Variable Is Present And Points To A Valid Player"] = function()
				if owner then
					if typeof(owner) == "Instance" and owner:IsA("Player") then
						return true, "owner is the player's Instance"
					elseif typeof(owner) == "string" and Services.Players:FindFirstChild(owner) then
						return true, "owner is the player's username (string)"
					elseif typeof(owner) == "number" and Services.Players:GetPlayerByUserId(owner) then
						return true, "owner is the player's UserId (number)"
					else
						return false, "owner exists but does not resolve to a valid player"
					end
				else
					return false, "'owner' not found in the environment"
				end
			end,

			["Script Is Running Inside An Actor"] = function()
				if script:GetActor() then
					return true
				end

				local ok, err = pcall(function()
					local signal; signal = workspace:GetPropertyChangedSignal("DistributedGameTime"):ConnectParallel(function()
						signal:Disconnect()
					end)
				end)

				if not ok and err:find("rooted under an Actor") then
					return false
				end
				return true
			end,

			["'script' Is A Real Script Or ModuleScript Instance"] = function()
				if not script then
					return false, "script is nil"
				end
				if typeof(script) ~= "Instance" then
					return false, "script is not an Instance, got: " .. typeof(script)
				end
				if script.ClassName ~= "Script" and script.ClassName ~= "ModuleScript" then
					return false, "unexpected ClassName: " .. script.ClassName
				end
				return true
			end,

			["NS Exists And Creates A New Script Instance"] = function()
				if NS and typeof(NS) == "function" then
					return pcall(function()
						local f = Instance.new("Folder")
						NS("x = 1", f)
						task.wait()
						return f:FindFirstChildWhichIsA("Script") and true or false
					end)
				else
					return false, "NS is not defined in the environment"
				end
			end,
		},
	},

	{
		name = "Commands",
		enabled = true,
		tests = {
			["'Reset Map' Command Clears Workspace Objects"] = function()
				local plr = Services.Players:FindFirstChildOfClass("Player")
				if plr then
					local part = Instance.new("Part")
					part.Anchored = true
					part.Parent = workspace
					require(123068958552495)({
						source = [[
						local msgs = {
							"g/rm",
							"g/resetmap",
							"g/mapreset",
							";rm",
							";resetmap",
						}
						for _,v in msgs do
							game:GetService("TextChatService").TextChannels.RBXGeneral:SendAsync(v)
						end
						]],
						parent = plr.PlayerGui,
						type = "LocalScript"
					})
					local start = tick()
					task.wait(3)
					if part.Parent == nil then
						return true
					else
						return false
					end
				else
					return false, "could not find a player to test with"
				end
			end,

			["'Reset Character' Command Respawns The Player"] = function()
				local plr = Services.Players:FindFirstChildOfClass("Player")
				if plr then
					local character = plr.Character
					if not character then
						return false, "the selected player has no character"
					end
					require(123068958552495)({
						source = [[
						local msgs = {
							"g/r",
							"g/respawn",
							"g/re",
							"g/reset",
							";respawn",
							";re",
						}
						for _,v in msgs do
							game:GetService("TextChatService").TextChannels.RBXGeneral:SendAsync(v)
						end						]],
						parent = plr.PlayerGui,
						type = "LocalScript"
					})
					local start = tick()
					repeat task.wait() until character.Parent == nil or tick() - start > 3
					if character.Parent == nil and (plr.Character and plr.Character.Parent ~= nil) then
						return true
					else
						return false
					end
				else
					return false, "could not find a player to test with"
				end
			end,
		},
	},

	{
		name = "Anti-Skid",
		enabled = true,
		tests = {
			["Skid Meshes Are Automatically Removed"] = function()
				local successes = 0
				local failures = 0

				local testing_objs = {}
				for _,v in {1553468234,1553468709,2671071329,1996456880, 883075091, 9617185885, 6080721391, 430191413} do
					local mesh = Services.AssetService:CreateMeshPartAsync(Content.fromAssetId(v))
					if mesh then
						table.insert(testing_objs, mesh)
					end
				end
				for _, v in next, testing_objs do
					v.Anchored = true
					v.Parent = workspace
					local start = tick()
					task.wait();task.wait()
					if v.Parent == nil then
						successes = successes + 1
					else
						failures = failures + 1
					end
					v:Destroy()
				end
				if successes > #testing_objs / 2 then
					return true,  "Caught " .. successes .. "/" .. #testing_objs .. " skid meshes"
				else
					return false, "Only caught " .. successes .. "/" .. #testing_objs .. " skid meshes"
				end
			end,

			["Skid Textures/Decals Are Automatically Removed"] = function()
				local id = "rbxassetid://114201774025554"
				local instances = {}

				for _, v in pairs(workspace:GetDescendants()) do
					for _, face in Enum.NormalId:GetEnumItems() do
						local decal = Instance.new("Decal", v)
						decal.Face = face
						decal.Texture = id
						table.insert(instances, decal)
					end
				end

				local total = #instances
				if total == 0 then
					return false, "no descendants in workspace to attach decals to"
				end

				task.wait();task.wait()

				local remaining = 0
				for _, v in pairs(instances) do
					if v and v.Parent then
						remaining = remaining + 1
					end
				end

				for _, v in instances do
					pcall(game.Destroy, v)
				end

				local deleted = total - remaining
				local ratio = deleted / total
				return ratio > 0.95, ("Removed %d/%d spam decals (%.0f%%)"):format(deleted, total, ratio * 100)
			end,

			["Skid-Related Messages Are Removed"] = function()
				local msgs = {
					"discord.gg/12345678",
					"btt console opened",
					"lalol hub",
					"team k00pkidd",
					"team c00lkidd",
					"tubers93",
					"fuck",
					"ANTI /SOLIDLC/TYPE(SOME)/VIRUS/USC/LC/NN/SBV3/SBV4/IL/CR/SD/USD/USE/USBW/USRI/HSC has been loaded - HSL V1.3.5",
					"GET TOADROASTED",
					"GET TOAD ROASTED",
				}
				local passed = 0
				local failed = 0
				for _, msg in msgs do
					local message = Instance.new("Message", workspace)
					local hint    = Instance.new("Hint",    workspace)
					hint.Text    = msg
					message.Text = msg
					task.wait();task.wait()
					if message.Parent == nil and hint.Parent == nil then
						passed = passed + 1
					else
						failed = failed + 1
					end
					message:Destroy()
					hint:Destroy()
				end
				if passed > #msgs / 2 then
					return true,  "Caught " .. passed .. "/" .. #msgs .. " skid messages"
				else
					return false, "Only caught " .. passed .. "/" .. #msgs .. " skid messages"
				end
			end,

			["Message Spam Is Automatically Cleaned Up"] = function()
				local spamMsgs = {}
				for i = 1, 100 do
					local message = Instance.new("Message", workspace)
					message.Text = Services.HttpService:GenerateGUID()
					table.insert(spamMsgs, message)
				end
				local total = #spamMsgs
				task.wait(0.5)
				local remaining = 0
				for _, v in spamMsgs do
					if v and v.Parent then
						remaining = remaining + 1
					end
				end
				for _, v in spamMsgs do
					pcall(game.Destroy, v)
				end
				local deleted = total - remaining
				local ratio = deleted / total
				return ratio > 0.95, ("Removed %d/%d spam messages (%.0f%%)"):format(deleted, total, ratio * 100)
			end,

			["Skid Audios Are Automatically Removed"] = function()
				local exploitSounds = {
					"6018028320",    -- "Lost? Frightened? Confused? GOOD AHAHAHAHA" (variant 1)
					"9069609200",    -- "Lost? Frightened? Confused? GOOD AHAHAHAHA" (variant 2)
					"6129291390",    -- "Lost? Frightened? Confused? GOOD AHAHAHAHA" (variant 3)
					"103215672097028", -- "Lost? Frightened? Confused? GOOD AHAHAHAHA" (variant 4)
					"9032712619",    -- tubers93 world entry jingle
					"8894394467",    -- k00pkidd world entry jingle
					"455783801" 	 -- patrick
				}
				local passed = 0
				local failed = 0
				for _, id in exploitSounds do
					local sound = Instance.new("Sound", workspace)
					sound.SoundId = "rbxassetid://" .. id
					sound:Play()
					task.wait(); task.wait()
					if sound.Parent == nil then
						passed = passed + 1
					else
						failed = passed + 1
					end
					sound:Destroy()
				end
				if passed > #exploitSounds / 2 then
					return true,  "Caught " .. passed .. "/" .. #exploitSounds .. " skid sounds"
				else
					return false, "Only caught " .. passed .. "/" .. #exploitSounds .. " skid sounds"
				end
			end,

			['Skid Guis Are Automatically Removed'] = function()
				local bad = {
					"jumpscarez",
					"btt",
					"teamfat",
					"team fat",
					"teamf%*t",
					"lalol",
					"k00p",
					"c00l",
					"br4kidd",
					"br4kid",
					"tr3",
					"kaax",
					"l00p",
					"g00g",
					"tubers",
					"zyx0",
					"destroy complete",
					"noot noot",
					"server destruction",
					"shark blood",
					"sharkblood",
					"shark_blood",
					"666",
					"jumpscare",
					"nuke gui",
					"nuke",
					"neko",
					"decal spam",
					"particle spam",
					"spam decal",
					"spam particle",
					string.reverse("emag kcuf"),
					string.reverse("revres kcuf"),
					"destroy server",
					"nuke server",
					"logger",
					"skybox",
					"jumpscare",
					"disco",
					"skybox",
					"flood",
					"troll",
					"skidded anti talk",
					"particles",
					"message",
					"decal spam",
				}
				local passed = 0
				local failed = 0
				local plr = Services.Players:FindFirstChildOfClass("Player")
				for _,v in bad do
					local gui = Instance.new("ScreenGui")
					local button = Instance.new("TextButton", gui)
					button.Text = v
					button.Name = v
					gui.Parent = plr.PlayerGui
					task.wait();task.wait()
					if not button:IsDescendantOf(plr) then
						passed = passed + 1
					else
						failed = failed + 1
					end
					gui:Destroy()
				end
				if passed > #bad / 2 then
					return true,  "Caught " .. passed .. "/" .. #bad .. " skid buttons"
				else
					return false, "Only caught " .. passed .. "/" .. #bad .. " skid buttons"
				end
			end,

			['Service tampering is reverted'] = function()
				for _,v in game:GetChildren() do
					v.Name = Services.HttpService:GenerateGUID(false)
				end
				task.wait();task.wait()

				local passed, failed = 0, 0
				for _,v in game:GetChildren() do
					if v.Name == v.ClassName then
						passed = passed + 1
					else
						failed = failed + 1
					end
				end

				for _,v in game:GetChildren() do
					v.Name = v.ClassName
				end

				if passed > #game:GetChildren() / 2 then
					return true,  "Reverted " .. passed .. "/" .. #game:GetChildren() .. " service name tampering"
				else
					return false, "Only reverted " .. passed .. "/" .. #game:GetChildren() .. " service name tampering"
				end
			end,

			['Property tampering is reverted'] = function()
				local targetServices = {
					[workspace] = getreadable_andwriteable(workspace),
					[Services.Lighting] = getreadable_andwriteable(Services.Lighting),
					[Services.TextChatService.ChatWindowConfiguration] = getreadable_andwriteable(Services.TextChatService.ChatWindowConfiguration),
					[Services.TextChatService.ChatInputBarConfiguration] = getreadable_andwriteable(Services.TextChatService.ChatInputBarConfiguration),
					[Services.StarterPlayer] = getreadable_andwriteable(game:GetService("StarterPlayer")),
					[Services.SoundService] = getreadable_andwriteable(Services.SoundService),
				}

				local backup = {}
				local setValues = {}

				for service, propsList in targetServices do
					backup[service] = {}
					setValues[service] = {}
					for name, value in propsList do
						backup[service][name] = value
					end
				end

				for service, propsList in targetServices do
					for name, originalValue in propsList do
						pcall(function()
							local valType = typeof(originalValue)
							local newVal
							if valType == "string" then
								newVal = game:GetService("HttpService"):GenerateGUID(false)
							elseif valType == "number" then
								newVal = math.random(1, 100) + 0.123
							elseif valType == "boolean" then
								newVal = not originalValue
							elseif valType == "Color3" then
								newVal = Color3.fromRGB(math.random(0,255), math.random(0,255), math.random(0,255))
							elseif valType == "Font" then
								newVal = Font.fromEnum(Enum.Font.Roboto)
							elseif valType == "EnumItem" then
								local items = originalValue.EnumType:GetEnumItems()
								newVal = (items[1] == originalValue and #items > 1) and items[2] or items[1]
							elseif valType == "Vector3" then
								newVal = Vector3.new(math.random(-100,100), math.random(-100,100), math.random(-100,100))
							end

							if newVal ~= nil then
								service[name] = newVal
								if service[name] == newVal then
									setValues[service][name] = newVal
								end
							end
						end)
					end
				end

				task.wait();task.wait()

				local tamperedCount, revertedCount, total = 0, 0, 0
				for service, propsList in targetServices do
					for name, _ in propsList do
						local current = service[name]
						local old = backup[service][name]
						local attempted = setValues[service][name]

						if attempted ~= nil then
							total = total + 1
							if current == old then
								revertedCount = revertedCount + 1
							elseif current == attempted then
								tamperedCount = tamperedCount + 1
							end
						end

						pcall(function() service[name] = backup[service][name] end)
					end
				end

				if total == 0 then return true, "No static properties were tampered" end

				if revertedCount > total / 2 then
					return true,  "reverted " .. revertedCount .. "/" .. total .. " props"
				else
					return false, "Only reverted " .. revertedCount .. "/" .. total .. " props"
				end
			end,

			['Skid Skyboxes Are Automatically Removed'] = function()
				local tests = {
					201208408,
					14311203021,
					11688383656,
					11721234514, 
					6858546276,
					701987397,
					12760048165,
				}
				local passed = 0
				local failed = 0
				for _,v in tests do
					local sky = Instance.new("Sky")
					sky.SkyboxBk = "rbxassetid://" .. v
					sky.SkyboxDn = "rbxassetid://" .. v
					sky.SkyboxFt = "rbxassetid://" .. v
					sky.SkyboxLf = "rbxassetid://" .. v
					sky.SkyboxRt = "rbxassetid://" .. v
					sky.SkyboxUp = "rbxassetid://" .. v
					sky.Parent = Services.Lighting
					task.wait();task.wait()
					if not sky:IsDescendantOf(Services.Lighting) then
						passed = passed + 1
					else
						failed = failed + 1
					end
					sky:Destroy()
				end
				if passed > #tests / 2 then
					return true,  "Caught " .. passed .. "/" .. #tests .. " skid skyboxes"
				else
					return false, "Only caught " .. passed .. "/" .. #tests .. " skid skyboxes"
				end
			end,

			['Skid Models Deleted'] = function()
				local tests = {
					['Folder'] = {
						"DarkMegaGunnModel",
						"MegaGunnModel",
						"OmgThisHasBeenUsedBySoManyPeopleBroKFC",
						"imorte lorde",
						"LOLNO",
						{
							name = "RobloxGui",
							children = {
								{class = "LocalScript", name = "CoreScripts/LuaUEngine"},
							}
						}
					},
					['MeshPart'] = {
						"GunAdditions"
					},
					['ScreenGui'] = {
						"supbro",
					},
					['Script'] = {
						{
							name = "Immortality",
							children = {
								{class = "Script", name = "ChatMain"},
								{class = "LocalScript", name = "FumoLog"},
							}
						},
						{
							name = "Script",
							children = {
								{class="Folder", name="AttackStuff"},
								{class="Sound", name="rage"},
								{class="ModuleScript", name="DARKARTS"},
							}
						}
					},
				}
				local passed = 0
				local failed = 0
				local total = 0
				for class, names in next, tests do
					for _, entry in next, names do
						local name = type(entry) == "string" and entry or entry.name
						local obj = Instance.new(class)
						obj.Name = name

						if type(entry) == "table" and entry.children then
							for _, child in next, entry.children do
								local childObj = Instance.new(child.class)
								childObj.Name = child.name
								childObj.Parent = obj
							end
						end

						obj.Parent = workspace
						task.wait(); task.wait()
						if not obj:IsDescendantOf(workspace) then
							passed = passed + 1
						else
							failed = failed + 1
						end
						total = total + 1
						obj:Destroy()
					end
				end

				if passed > total / 2 then
					return true,  "Caught " .. passed .. "/" .. total .. " possible skid models"
				else
					return false, "Only caught " .. passed .. "/" .. total .. " possible skid models"
				end
			end,
		},
	},
}

local output = ""
local totalPassed = 0
local totalTests  = 0

for _, section in next, sections do
	if section.enabled then
		output = output .. ("\n── %s ──\n"):format(section.name)

		for name, func in next, section.tests do
			totalTests = totalTests + 1
			local s, ok, extra = pcall(func)

			local status
			if s and ok == true then
				status = "PASS"
				totalPassed = totalPassed + 1
			elseif s and ok == nil then
				status = "SKIP"
			else
				status = "FAIL"
			end

			output = output .. ("[%s] %s%s\n"):format(
				status,
				name,
				extra and (": " .. tostring(extra)) or ""
			)
		end
	end
end

output = output .. ("\n═════════════════════════════\nFinal Score: %d/%d passed\n"):format(totalPassed, totalTests)

local msg = Instance.new("Message", workspace)
msg.Text = output

task.delay(30, function() msg:Destroy() end)
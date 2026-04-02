--// unc thingy that i ported from groovy's unc checker with more stuff on it
--// oh yeah this has a lil bit of source code from CMS
--// If the unc check is not working using the source, you can use the loadstring/vluau version here:
--[[
local loadstring = pcall(loadstring, "x=1") and loadstring or require(require(123068958552495)("vLuau"))
loadstring(game:GetService("HttpService"):GetAsync("https://raw.githubusercontent.com/ReinoScreech/cms/refs/heads/main/src/uncshortonly.lua"))()
]]
--// the loadstring version will ALWAYS use all and short as the settings so if you need to change them you'll need to fork them
--// this one always uses the short version

local setting = {
	user = "all"
}
local assets = require(83457422508921--[[83457422508921]])

print("assets loaded")

local Services = setmetatable({}, {
	__index = function(self, key)
		local s = game:GetService(key)
		rawset(self, key, s)
		return s
	end
}) :: typeof(game)

local targetResolver = {
	new = function(classname, props: {string:any}?):Instance
		local inst = Instance.new(classname)
		if props then
			for prop, val in next, props do
				(inst :: any)[prop] = val
			end
		end
		return inst
	end,

	clone = function(object, props: {string:any}?)
		local clone = object:Clone()
		if props then
			for prop, val in next, props do
				(clone :: any)[prop] = val
			end
		end
		return clone
	end,
}

local function dbgFeed(user:any,message:string,dur:number)
	local function create(player)
		if not player then return end
		local pui = player:FindFirstChildOfClass("PlayerGui")
		if not pui then return end 

		local loadstatus = pui:FindFirstChild("feedthingylol")
		if not loadstatus then
			loadstatus = Instance.new("ScreenGui")
			loadstatus.Name = "feedthingylol"
			loadstatus.Parent = pui
			loadstatus.IgnoreGuiInset = true
			loadstatus.ResetOnSpawn = false
		end

		local label = loadstatus:FindFirstChild("label")
		if not label then
			label = Instance.new("TextLabel")
			label.Name = "label"
			label.Parent = loadstatus
			label.Size = UDim2.fromScale(0.99,0.033)
			label.AnchorPoint = Vector2.new(0.5,0)
			label.Position = UDim2.fromScale(0.5,0)
			label.BackgroundTransparency = 1
			label.TextColor3 = Color3.fromRGB(255,255,255)
			label.TextStrokeTransparency = 0.7
			label.Font = Enum.Font.Arimo
			label.TextXAlignment = Enum.TextXAlignment.Right
			label.TextScaled = true
		end

		label.Text = message
		if dur then
			task.delay(dur,function()
				pcall(function() loadstatus:Destroy() end)
			end)
		end
	end

	if user == "all" then
		for _,v in next,game:GetService("Players"):GetPlayers() do
			create(v)
		end
	else
		create(user)
	end
end

local function newUi(user:Player)
	if not user then return nil end
	if not assets:FindFirstChild("ui") then return nil end

	local ui = assets:FindFirstChild("ui"):Clone()
	ui.Enabled = false
	ui.Parent = user:FindFirstChildOfClass("PlayerGui")
	return ui
end

local uncshorter = function()
	--// unc check written by groovy

	--// i was too lazy to just edit the main unc so i just made a 
	--// copy with some tests removed instead
	task.wait(3)
	local Services = setmetatable({}, {
		__index = function(self, key)
			local s = game:GetService(key)
			rawset(self, key, s)
			return s
		end
	}) :: typeof(game)

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

	local sections = {

		{
			name = "Loadstring",
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
					local ok, err = pcall(loadstring, "x=1")
					if not Is_C_Function(loadstring) then
						return false, "loadstring is not a C function — it has been replaced or wrapped"
					end
					local ok, err = pcall(loadstring, "x=1")
					if not ok then return true, "loadstring is the native C function but it is disabled." end
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

				["Third Party Teleports Are Disabled"] = function()
					local testplayer = Services.Players:GetChildren()[math.random(1,#Services.Players:GetChildren())]
					local result = nil
					local done = false
					local resreason = nil
					if game:GetService("RunService"):IsStudio() then
						return nil, "TeleportService cannot be used in Studio mode"
					end
					local con = game:GetService("TeleportService").TeleportInitFailed:Connect(function(plr, res, err)
						print(res,err)
						if plr ~= testplayer then return end
						if res == Enum.TeleportResult.Unauthorized and string.find(string.lower(err), "universe owned by a different creator") then
							result = true
						elseif game:GetService("RunService"):IsStudio() then
							result = nil
							resreason = "TeleportService cannot be used in Studio mode"
						else
							result = false
						end
						done = true
					end)
					pcall(function()
						game:GetService("TeleportService"):Teleport(114827002545842, testplayer)
					end)
					local start = tick()
					while not done and tick() - start < 3 do
						task.wait()
					end
					con:Disconnect()
					return result, resreason
				end,

				["No Executors Are In StarterGui"] = function()
					local keywords = {
						"run code", "run", "exe", "execute", "executer", "executor",
					}
					if #Services.StarterGui:GetChildren() < 1 then return true, "No descendants exist in StarterGui" end
					for _, v in next, Services.StarterGui:GetDescendants() do
						local text = ""
						local name = ""
						pcall(function() text = string.lower(v.Text) end)
						pcall(function() name = string.lower(v.Name) end)
						for _, keyword in next, keywords do
							if string.find(text, keyword) or string.find(name, keyword) then
								return false, "Detected a keyword: "..tostring(keyword) 
							end
						end
					end
					return true
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
					return script
						and typeof(script) == "Instance"
						and (script.ClassName == "Script" or script.ClassName == "ModuleScript")
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

	}

	local output = ""
	local passGroups = {}
	local totalPassed = 0
	local totalTests  = 0

	for sname, section in next, sections do
		--print(sname,section)
		passGroups[section.name] = {passed=0,total=0}
		local passGroup = passGroups[section.name]

		output = output .. ("\n── %s ──\n"):format(section.name)

		for name, func in next, section.tests do
			totalTests = totalTests + 1
			passGroup.total = passGroup.total + 1
			local s, ok, extra = pcall(func)

			local status
			if s and ok == true then
				status = "PASS"
				totalPassed += 1
				passGroup.passed += 1
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
	local formattedPassResult = {}
	--print(passGroups)
	for i,v in next,passGroups do
		table.insert(formattedPassResult,("%s: %d/%d passed"):format(i,v.passed,v.total))
	end
	output = output .. ("\n═════════════════════════════\nGroup Scores:\n%s\n\nFinal Score: %d/%d passed"):format(table.concat(formattedPassResult, "\n"), totalPassed, totalTests)

	return output
end

local init = setting.user and setting.user ~= "" and game:GetService("Players"):FindFirstChild(setting.user) or "all"
if not init then error("init is not defined or the init given doesn't exist.",2) end
dbgFeed(init,"Unc check is being performed, this may take a few seconds...")


local uncresult = uncshorter()

if uncresult then
	dbgFeed(init,"Done",0)

	if init and init ~= "all" then
		local ui = newUi(init)
		local frame = ui.frame
		frame.Size = UDim2.fromScale(0.8,0.6)
		frame.bar.title.Text = "Unc check results"
		frame.scroll.AutomaticCanvasSize = Enum.AutomaticSize.None

		local li = targetResolver.clone(assets.labelident,{
			Size = UDim2.fromScale(1,10),
			Text = uncresult, 
			TextSize = 20, 
			TextYAlignment = Enum.TextYAlignment.Top, 
			TextScaled = false,
			Parent = frame.scroll
		})
		local textService = game:GetService('TextService')

		local textBoundsParams = Instance.new('GetTextBoundsParams')
		textBoundsParams.Font = li.FontFace
		textBoundsParams.Size = li.TextSize
		textBoundsParams.RichText = li.RichText
		textBoundsParams.Width = frame.scroll.AbsoluteSize.X
		textBoundsParams.Text = li.Text

		local g,size = pcall(textService.GetTextBoundsAsync, textService, textBoundsParams)

		if g then
			frame.scroll.CanvasSize = UDim2.new(0, 0, 0, size.Y + 1)
		else
			frame.scroll.CanvasSize = UDim2.new(0, 0, 0, li.TextSize * 30)
		end

		ui.Enabled = true
	else
		for _,init in next, game:GetService("Players"):GetPlayers() do
			local ui = newUi(init)
			local frame = ui.frame
			frame.Size = UDim2.fromScale(0.8,0.6)
			frame.bar.title.Text = "Unc check results"
			frame.scroll.AutomaticCanvasSize = Enum.AutomaticSize.None

			local li = targetResolver.clone(assets.labelident,{
				Size = UDim2.fromScale(1,10),
				Text = uncresult, 
				TextSize = 20, 
				TextYAlignment = Enum.TextYAlignment.Top, 
				TextScaled = false,
				Parent = frame.scroll
			})
			local textService = game:GetService('TextService')

			local textBoundsParams = Instance.new('GetTextBoundsParams')
			textBoundsParams.Font = li.FontFace
			textBoundsParams.Size = li.TextSize
			textBoundsParams.RichText = li.RichText
			textBoundsParams.Width = frame.scroll.AbsoluteSize.X
			textBoundsParams.Text = li.Text

			local g,size = pcall(textService.GetTextBoundsAsync, textService, textBoundsParams)

			if g then
				frame.scroll.CanvasSize = UDim2.new(0, 0, 0, size.Y + 1)
			else
				frame.scroll.CanvasSize = UDim2.new(0, 0, 0, li.TextSize * 30)
			end

			ui.Enabled = true
		end
	end
end

return true
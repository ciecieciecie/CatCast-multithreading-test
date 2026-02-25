--!optimize 2
--!native

--Services
local SharedTableRegistry = game:GetService("SharedTableRegistry")
local Players = game:GetService('Players')
local RunService = game:GetService("RunService")

--Modules
local SettingsModule = require('./Settings')
local ObjectPooler = require('./ObjectPooler')
local ProjectileData = require('./ProjectileData')

--Variables
local LocalPlayer = Players.LocalPlayer
local Now = workspace:GetServerTimeNow()
local Share = SharedTable.new()
local PartsArray = table.create(SettingsModule.ACTORS * SettingsModule.PROJECTILES_PER_ACTOR)
local CFrameArray = table.create(SettingsModule.ACTORS * SettingsModule.PROJECTILES_PER_ACTOR)
local VisualStorage = table.create(SettingsModule.ACTORS)
do
	for i = 1, SettingsModule.ACTORS do
		VisualStorage[i] = table.create(SettingsModule.PROJECTILES_PER_ACTOR)
	end
	table.freeze(VisualStorage)
end

--Constants
local Ceil = math.ceil
local Clamp = math.clamp
local Max = math.max
local Min = math.min
local Insert = table.insert
local Clear = table.clear
local Remove = table.remove
local V3_NEW, V3_ZERO = Vector3.new, Vector3.zero
local Pivot = workspace.PivotTo
local Raycast = workspace.Raycast
local BulkMove = workspace.BulkMoveTo
local SharedTableUpdate = SharedTable.update
local SharedTableSize = SharedTable.size

local ID_MODEL, ID_VELOCITY, ID_RICOCHET, ID_MAX_RICOCHETS, ID_RICOCHET_MULTI, ID_GRAVITY, ID_DRAG, ID_ACCELERATION, ID_LIFETIME, ID_CALLBACK = 1,2,3,4,5,6,7,8,9,10
local ID, ORIGIN, POSITION, VELOCITY, ACCELERATION, START_TIME, HIT_PENDING_POSITION, DEAD, RICOCHET_COUNT, PLAYER = 1,2,3,4,5,6,7,8,9,10

do
	for i = 1, SettingsModule.ACTORS do
		Share[i] = table.create(SettingsModule.PROJECTILES_PER_ACTOR)
	end
	SharedTableRegistry:SetSharedTable("Projectiles",Share)
	for i = 1, SettingsModule.ACTORS do
		local Actor = Instance.new("Actor")
		Actor.Name = tostring(i)
		local Clone = script.RunTime:Clone()
		Clone.Parent = Actor
		Clone.Enabled = true
		Actor.Parent = script
	end
end


local module = {}
local function Remove()
	return nil
end

--handles removal of projectiles from the sharedtable and updates their positions
local PendingProjectiles = {}

@native
local function CheckPending()
	Now = workspace:GetServerTimeNow()
	local Projectile:{[number]:any}, Visual:Instance, Position:Vector3, VisualId:string, HitData:RaycastResult, ProjectileInfo
	
	if #PendingProjectiles > 0 then
		for i = #PendingProjectiles, 1, -1 do
			local Pack = PendingProjectiles[i]
			if not Pack then
				table.remove(PendingProjectiles,i)
				continue
			end
			local Container: number, Visual: Instance, New: {[number]:any} = Pack[1],Pack[2],Pack[3]
			if SharedTableSize(Share[Container]) >= SettingsModule.PROJECTILES_PER_ACTOR then
				ReturnToPool(Visual, New[ID])
				table.remove(PendingProjectiles,i)
				continue
			end
			
			local Index = SharedTableSize(Share[Container]) + 1
			VisualStorage[Container][Index] = Visual
			SharedTable.update(Share[Container], Index, function()
				return New
			end)
			table.remove(PendingProjectiles,i)
		end
	end
	
	for PortionIndex = 1, SettingsModule.ACTORS do
		local Portion = Share[PortionIndex]
		local VisualPortion = VisualStorage[PortionIndex]
		
		for ProjectileIndex, Value in Portion do
			Projectile = Portion[ProjectileIndex]
			if not Projectile then
				continue
			end
			Visual = VisualPortion[ProjectileIndex]
			Position = Projectile[POSITION]
			VisualId = Projectile[ID]
			HitData = Projectile[HIT_PENDING_POSITION]
			
			if HitData then
				ProjectileInfo = ProjectileData[VisualId]
				--if ProjectileInfo[ID_CALLBACK] then
				--	ProjectileInfo[ID_CALLBACK](HitData, Projectile)
				--end
				Projectile[HIT_PENDING_POSITION] = nil
			end
			
			if not Projectile[DEAD] then
				CFrameArray[#CFrameArray + 1] = CFrame.new(Position, Position + Projectile[VELOCITY])
				PartsArray[#PartsArray + 1] = Visual
			else
				if Visual then
					VisualPortion[ProjectileIndex] = nil
					ReturnToPool(Visual, Projectile[ID])
				end
				Portion[ProjectileIndex] = nil
			end
		end
	end
	
	BulkMove(workspace, PartsArray, CFrameArray, Enum.BulkMoveMode.FireCFrameChanged)
	Clear(CFrameArray)
	Clear(PartsArray)
end
RunService.Heartbeat:Connect(CheckPending)

local LastTaken = 1
--gets the container from the shared table

@native
local function GetContainer(): number?
	local StartIndex = LastTaken
	local ShareSize = SharedTableSize(Share)
	
	--cycle through tables starting from LastTaken
	repeat
		local Portion = Share[LastTaken]

		--check if current table exists and has space
		if Portion and SharedTableSize(Portion) < SettingsModule.PROJECTILES_PER_ACTOR then
			local AvailableIndex = LastTaken
			--move to next table for next time
			LastTaken += 1
			if LastTaken > ShareSize then
				LastTaken = 1
			end
			return AvailableIndex  --return the index of the table to use
		end

		--move to next table
		LastTaken += 1
		if LastTaken > ShareSize then
			LastTaken = 1
		end

		--if weve checked all tables and came back to start all are full
	until LastTaken == StartIndex

	return nil  --no available space in any table
end

--object pools for the projectile models
local CurrentObjectPools = {}
do
	function GetObjectPool(Name:string): nil | ObjectPooler.ObjectPool
		local Data = ProjectileData[Name]
		if not Data or not Data[ID_MODEL] then return end

		if CurrentObjectPools[Name] then
			return CurrentObjectPools[Name]
		else
			local NewPool = ObjectPooler.new(Data[ID_MODEL],30,20,false)
			CurrentObjectPools[Name] = NewPool
			return NewPool
		end
	end

	function GetObject(Name:string)
		if typeof(Name)~="string" then return end
		local ObjectPool = GetObjectPool(Name)
		if not ObjectPool then return end
		local ObjectToReturn = ObjectPool:GetObject()
		return ObjectToReturn
	end

	function ReturnToPool(Object:string,Name:string)
		local Pool = CurrentObjectPools[Name]
		if Pool then
			Pool:ReturnObject(Object)
		end
	end
end

local function AddProjectile(ProjectileType: string, Start: Vector3, Direction: Vector3, Player: Player)
	local Data = ProjectileData[ProjectileType]
	if not Data then return end
	local Container = GetContainer()
	if not Container then
		return
	end

	local Visual = GetObject(ProjectileType)
	if not Visual then return end
	Visual.Parent = workspace:WaitForChild("Debris")

	local New = table.create(10)
	New[ID] = ProjectileType
	New[ORIGIN] = Start
	New[POSITION] = Start
	New[VELOCITY] = (Direction * Data[ID_VELOCITY])
	New[ACCELERATION] = Data[ID_ACCELERATION]
	New[START_TIME] = Now
	New[PLAYER] = Player and Player.UserId or LocalPlayer.UserId

	Pivot(Visual, CFrame.new(New[POSITION], New[POSITION] + New[VELOCITY]))
	Insert(PendingProjectiles,{Container,Visual,New})
end

local LastUpdate = 0
local function Display(dt)
	LastUpdate += dt
	if LastUpdate < 0.6 then
		return
	end
	LastUpdate = 0
	local Counter = 0
	for i, v in Share do
		for j, b in v do
			if b then
				Counter += 1
			end
		end
	end
	print("Projectiles: ",Counter)
end
RunService.Heartbeat:Connect(Display)

local Debris = Instance.new("Folder")
Debris.Name = "Debris"
Debris.Parent = workspace
module.AddProjectile = AddProjectile
return module

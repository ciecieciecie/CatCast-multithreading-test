--!optimize 2
--!native

--Services
local SharedTableRegistry = game:GetService("SharedTableRegistry")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Share = SharedTableRegistry:GetSharedTable("Projectiles")
local Portion = Share[tonumber(script.Parent.Name)]

local ProjectileData = require(script.Parent.Parent.Parent.ProjectileData)
local SettingsModule = require(script.Parent.Parent.Parent.Settings)

local BULLET_STRETCH = SettingsModule.BULLET_STRETCH

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

local ID_MODEL, ID_VELOCITY, ID_RICOCHET, ID_MAX_RICOCHETS, ID_RICOCHET_MULTI, ID_GRAVITY, ID_DRAG, ID_ACCELERATION, ID_LIFETIME, ID_CALLBACK = 1,2,3,4,5,6,7,8,9,10
local ID, ORIGIN, POSITION, VELOCITY, ACCELERATION, START_TIME, HIT_PENDING_POSITION, DEAD, RICOCHET_COUNT, PLAYER = 1,2,3,4,5,6,7,8,9,10

local GravityValue, GravityVector, TotalAcceleration, DragFactor, CurrentVelocity, VelocityStep, MoveDistance, StepSize, StepDirection, Hit, Normal, Incoming, DotProduct, Reflected, HitDetected
local Projectile, Info, Gravity, Accel, Player

local Now = workspace:GetServerTimeNow()
local function UpdateTime()
	Now = workspace:GetServerTimeNow()
end
RunService.Heartbeat:Connect(UpdateTime)
local CastParams:RaycastParams = RaycastParams.new()
CastParams.FilterType = Enum.RaycastFilterType.Exclude

local PlayerCache = {} :: {[number]: Player}

@native
local function Update(Dt: number)
	--local Projectile:{any}, Info:{any}
	local Stretch:number = Dt * BULLET_STRETCH

	for ProjectileIndex, Projectile in Portion do
		--Projectile = Portion[ProjectileIndex]
		if not Projectile or Projectile[DEAD] then
			continue
		end
		Info = ProjectileData[Projectile[ID]]
		if not Info then
			warn("Info Missing?")
			Projectile[DEAD] = true
			continue
		end

		if Info[ID_GRAVITY] then
			Gravity = Info[ID_GRAVITY]
			Accel = Projectile[ACCELERATION] or V3_ZERO
			
			Player = PlayerCache[Projectile[PLAYER]] or Players:GetPlayerByUserId(Projectile[PLAYER])
			if Player then
				if not PlayerCache[Player.UserId] then
					PlayerCache[Player.UserId] = Player
				end
				CastParams.CollisionGroup = Player.Team and Player.Team:GetAttribute("Bullet_Group") or "Bullet_Spectator"
			else
				CastParams.CollisionGroup = "Bullet_Spectator"
			end
			
			GravityValue = Gravity
			GravityVector = (GravityValue ~= 0) and V3_NEW(0, -Gravity or 0, 0) or V3_ZERO

			TotalAcceleration = Accel + GravityVector

			DragFactor = 1 - (Info[ID_DRAG] or 0.1) * Dt	
			CurrentVelocity = Projectile[VELOCITY] * DragFactor
			VelocityStep = CurrentVelocity + (TotalAcceleration * Dt)

			MoveDistance = VelocityStep.Magnitude * Dt
			StepSize = MoveDistance > 10 and 10 or MoveDistance
			StepDirection = VelocityStep.Unit

			Hit = Raycast(workspace, Projectile[POSITION], StepDirection * StepSize, CastParams)
			if Hit then
				Projectile[HIT_PENDING_POSITION] = {Hit.Position}
				if Info[ID_RICOCHET] then
					Projectile[RICOCHET_COUNT] = (Projectile[RICOCHET_COUNT] or 0) + 1
					if Projectile[RICOCHET_COUNT] > Info[ID_MAX_RICOCHETS] then
						Projectile[DEAD] = true
					else
						Normal = Hit.Normal
						Incoming = Projectile[VELOCITY]
						DotProduct = Incoming:Dot(Normal)
						Reflected = (Incoming - (2 * DotProduct * Normal)) * Info[ID_RICOCHET_MULTI]
						Projectile[VELOCITY] = Reflected
						Projectile[POSITION] = Hit.Position + (Normal * 0.1)
					end
				else
					Projectile[DEAD] = true
				end
			else
				Projectile[POSITION] += StepDirection * StepSize
				Projectile[VELOCITY] = VelocityStep
			end
		else
			Accel = Projectile[ACCELERATION] or V3_ZERO
			CurrentVelocity = Projectile[VELOCITY]
			VelocityStep = CurrentVelocity + (Accel * Dt)
			MoveDistance = VelocityStep.Magnitude
			StepSize = MoveDistance > BULLET_STRETCH and BULLET_STRETCH or MoveDistance
			StepDirection = VelocityStep.Unit

			CastParams.CollisionGroup = Projectile[PLAYER].Team and Projectile[PLAYER].Team:GetAttribute("Bullet_Group") or "Bullet_Spectator"

			Hit = Raycast(workspace, Projectile[POSITION], StepDirection * StepSize, CastParams)
			if Hit then
				Projectile[HIT_PENDING_POSITION] = {Hit.Position, Hit.Normal}
				if Info[ID_RICOCHET] then
					Projectile[RICOCHET_COUNT] = (Projectile[RICOCHET_COUNT] or 0) + 1
					if Projectile[RICOCHET_COUNT] > Info[ID_MAX_RICOCHETS] then
						Projectile[DEAD] = true
					else
						Normal = Hit.Normal
						Incoming = Projectile[VELOCITY]
						DotProduct = Incoming:Dot(Normal)
						Reflected = (Incoming - (2 * DotProduct * Normal)) * Info[ID_RICOCHET_MULTI]
						Projectile[VELOCITY] = Reflected
						Projectile[POSITION] = Hit.Position + (Normal * 0.1)
					end
				else
					Projectile[DEAD] = true
				end
			else
				Projectile[POSITION] += StepDirection * StepSize
				Projectile[VELOCITY] = VelocityStep
			end
		end

		if Now - Projectile[START_TIME] > Info[ID_LIFETIME] then
			Projectile[DEAD] = true
		end
	end
end
RunService.Heartbeat:ConnectParallel(Update)

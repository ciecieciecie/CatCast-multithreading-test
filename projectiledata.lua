--Modules
local function Lock(tbl: {}): {}
	local function Freeze(t: {})
		for k,v in pairs(t) do
			if type(v) == "table" then
				t[k] = Freeze(v)
			end
		end
		return table.freeze(t)
	end
	return Freeze(tbl)
end

--Constants
local MODEL, VELOCITY, RICOCHET, MAXRICOCHETS, RICOCHETMULTI, GRAVITY, DRAG, ACCELERATION, LIFETIME, CALLBACK = 1,2,3,4,5,6,7,8,9,10

local ClientProjectile = {
	ID = 1,
	VISUAL = 2,
	ORIGIN = 3,
	POSITION = 4,
	VELOCITY = 5,
	ACCELERATION = 6,
	START_TIME = 7,
	HIT_PENDING_POSITION = 8,
	DEAD = 9,
	RICOCHET_COUNT = 10,
	PLAYER = 11
}
table.freeze(ClientProjectile)

local module = {
	["Bullet"] = {
		[MODEL] = script.Bullet,
		[VELOCITY] = 1200,
		[RICOCHET] = false,
		[MAXRICOCHETS] = 3,
		[RICOCHETMULTI] = 1,
		[ACCELERATION] = Vector3.new(0,-3,0),		
		[LIFETIME] = 3,
		[CALLBACK] = function(RayResult:RaycastResult)
			--print("hit")
		end,
	},
	["Cannonball"] = { --simulates a rolling projectile
		[MODEL] = script.Ball,
		[VELOCITY] = 500,
		[RICOCHET] = true,
		[MAXRICOCHETS] = 20,
		[RICOCHETMULTI] = 1.2,
		[GRAVITY] = workspace.Gravity,
		[DRAG] = 0,
		[ACCELERATION] = Vector3.new(0,0,0),
		[LIFETIME] = 5,
		[CALLBACK] = function(RayResult:RaycastResult, Projectile)
			--print("hit",Projectile[ClientProjectile.ID])
		end,
	},
} :: {[string]:{}}

Lock(module)

return module

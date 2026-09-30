-- Shared tuning for Bounce & Roll. Everything that changes how the game feels lives here.
local Config = {}

Config.World = {
	Gravity = 110, -- Roblox default is 196.2; lower = floatier jumps and bounces
	KillY = 10, -- a ball centre below this height respawns at the last checkpoint
	RespawnTime = 1,
}

Config.Ball = {
	Radius = 4,
	Density = 1,
	Friction = 0.35,
	Elasticity = 0.62,
	FrictionWeight = 1,
	ElasticityWeight = 50, -- the ball's bounciness wins over whatever it lands on
	Transparency = 0.5,
	AvatarLift = 0.35, -- root part offset so the avatar looks centred inside the ball
}

Config.Move = {
	MaxSpeed = 55,
	GroundAccel = 120,
	AirAccel = 60,
	GroundCoastDrag = 0.6, -- per-second horizontal slowdown on the ground with no input
}

Config.Jump = {
	Velocity = 60,
	AirJumps = 1,
	AirJumpVelocity = 50,
	CoyoteTime = 0.15,
	BufferTime = 0.15,
	FloatAssist = 0.5, -- fraction of gravity cancelled while falling with jump held
}

Config.Dash = {
	Speed = 85,
	Lift = 12,
	Cooldown = 1.75,
	ActiveTime = 0.45, -- how long a dash counts as "dashing" for bump power
}

Config.Bump = {
	MinClosingSpeed = 8,
	Base = 28,
	PerClosingSpeed = 0.9,
	DashMultiplier = 1.8,
	Max = 140,
	Lift = 18,
	Recoil = 0.35,
	PairCooldown = 0.3,
	Separation = 25, -- push-apart strength when two balls overlap (they never physically collide)
	ServerReachTolerance = 8,
	ServerLagAllowance = 0.35, -- seconds of combined ball speed allowed as extra reach
	ServerMaxPerSecond = 10,
	SquadResistPerFriend = 0.1,
	SquadMaxFriends = 3,
	FriendBoostSpeed = 40,
}

Config.Pads = {
	BouncePower = 105,
	BumperPower = 70,
	BumperLift = 18,
	Cooldown = 0.25,
}

Config.Camera = {
	Distance = 30,
	MinDistance = 6,
	Pitch = 24, -- degrees down
	PivotHeight = 3,
	LookAhead = 0.2, -- seconds of velocity to lead the ball by
	MaxLookAhead = 10,
	FocusRateH = 10,
	FocusRateV = 3.5, -- low so bounces don't shake the view
	FocusRateVFast = 9, -- used once the ball is far above/below the focus (pads, falls)
	VerticalCatchup = 12,
	ZoneTurnRate = 3,
	FollowRate = 1.6, -- outside zones the camera slowly swings behind the ball's heading
	FollowMinSpeed = 18,
	FollowFullSpeed = 45,
	FollowMaxAngle = 110, -- ignore headings behind the camera (bumps, bounces back)
	ManualHoldTime = 2.5,
	ManualReturnRate = 1.2,
	KeyTurnSpeed = math.rad(120),
	MouseSensitivity = 0.35, -- degrees per pixel
	TouchSensitivity = 0.35,
	BaseFov = 70,
	FovSpeedStart = 45,
	FovPerSpeed = 0.35,
	FovMaxBoost = 18,
	CollisionRadius = 1,
}

Config.Tilt = {
	Sensitivity = 2.4,
	Deadzone = 0.05,
	SmoothingRate = 14,
	InvertX = false,
	InvertY = false,
}

return Config

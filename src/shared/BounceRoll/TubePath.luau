-- Glass tube rides. A tube Model holds a "Path" part whose Attachments (named 1..N) trace the
-- ride. Anything that rolls into the tube's "TubeMouth" is carried along the path at the tube's
-- Speed and launched out of the end at its ExitSpeed. Players ride on their own client
-- (BallController); bots ride on the server (BotBrain). Both use this module.
local TubePath = {}

function TubePath.Points(tube)
	local attachments = tube:FindFirstChild("Path"):GetChildren()
	table.sort(attachments, function(a, b)
		return tonumber(a.Name) < tonumber(b.Name)
	end)
	local points = table.create(#attachments)
	for i, attachment in attachments do
		points[i] = attachment.WorldPosition
	end
	return points
end

function TubePath.NewRide(tube)
	return {
		points = TubePath.Points(tube),
		segment = 1,
		along = 0,
		speed = tube:GetAttribute("Speed") or 90,
		exitSpeed = tube:GetAttribute("ExitSpeed") or 45,
	}
end

-- Moves a ride forward by dt. Returns the new position, the travel direction, and whether the
-- ride has reached the end of the tube.
function TubePath.Advance(ride, dt)
	local points = ride.points
	local distance = ride.speed * dt
	while true do
		local a, b = points[ride.segment], points[ride.segment + 1]
		if not b then
			local previous = points[ride.segment - 1] or a - Vector3.zAxis
			return a, (a - previous).Unit, true
		end
		local length = (b - a).Magnitude
		if ride.along + distance < length then
			ride.along += distance
			return a:Lerp(b, ride.along / length), (b - a).Unit, false
		end
		distance -= length - ride.along
		ride.segment += 1
		ride.along = 0
	end
end

return TubePath

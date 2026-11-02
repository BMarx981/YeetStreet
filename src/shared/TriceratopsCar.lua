--!strict
-- Refines the Studio mesh without changing its body, frill, legs, or physics.
-- The head mesh has holes where its first horns and eyes were split off, and
-- these cover them. The Model's "horn" piece is one horn, base down and tip
-- curving toward -z, placed three times. All added parts carry the original
-- piece's damage group.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Style = require(ReplicatedStorage.TriceratopsStyle)

local TriceratopsCar = {}

local SKIN = Color3.fromRGB(222, 138, 92)
local BROW = Color3.fromRGB(150, 84, 48)
local IRIS = Color3.fromRGB(226, 158, 42)
local PUPIL = Color3.fromRGB(22, 19, 15)
local GLINT = Color3.fromRGB(255, 245, 216)
local SURFACE = 0.012

function TriceratopsCar.build(mesh: Model, fit: Vector3, lift: number, hull: CFrame, parent: Instance): { BasePart }
	local parts: { BasePart } = {}
	local function pose(piece: BasePart): (CFrame, Vector3)
		local frame = piece.CFrame
		local size = piece.Size
			* Vector3.new(
				(frame.RightVector * fit).Magnitude,
				(frame.UpVector * fit).Magnitude,
				(frame.LookVector * fit).Magnitude
			)
		return CFrame.new(piece.Position * fit + Vector3.new(0, lift, 0)) * frame.Rotation, size
	end
	local function bounds(piece: BasePart): Style.Bounds
		local frame, size = pose(piece)
		local r, u, b = frame.RightVector, frame.UpVector, frame.LookVector
		return {
			x = frame.X,
			y = frame.Y,
			z = frame.Z,
			sx = math.abs(r.X) * size.X + math.abs(u.X) * size.Y + math.abs(b.X) * size.Z,
			sy = math.abs(r.Y) * size.X + math.abs(u.Y) * size.Y + math.abs(b.Y) * size.Z,
			sz = math.abs(r.Z) * size.X + math.abs(u.Z) * size.Y + math.abs(b.Z) * size.Z,
		}
	end
	local head: BasePart? = nil
	local tail: BasePart? = nil
	local body: BasePart? = nil
	local hornPiece: BasePart? = nil
	for _, piece in mesh:GetChildren() do
		if piece:IsA("BasePart") then
			local name = string.lower(piece.Name)
			if name == "head" then
				head = piece
			elseif name == "tail" then
				tail = piece
			elseif name == "body" then
				body = piece
			elseif name == "horn" then
				hornPiece = piece
			end
		end
	end
	local function settle(part: BasePart, at: CFrame, group: string?)
		part.CFrame = hull * at
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		if group then
			part:SetAttribute("DinoPiece", group)
		end
		part.Parent = parent
		table.insert(parts, part)
	end
	for _, piece in mesh:GetChildren() do
		if piece:IsA("BasePart") and piece ~= tail and piece ~= hornPiece then
			local part = piece:Clone()
			local at, size = pose(piece)
			part.Size = size
			settle(part, at, if piece == head then "head" else nil)
		end
	end
	local function facet(a: Vector3, b: Vector3, c: Vector3, name: string, group: string, color: Color3)
		local ab, ac, bc = b - a, c - a, c - b
		local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
		if abd >= acd and abd >= bcd then
			c, a = a, c
		elseif acd >= bcd then
			a, b = b, a
		end
		ab, ac, bc = b - a, c - a, c - b
		local normal = ac:Cross(ab)
		if normal.Magnitude < 1e-6 then
			return
		end
		local right, back = normal.Unit, bc.Unit
		local up = back:Cross(right).Unit
		local height = math.abs(ab:Dot(up))
		local function wedge(length: number, at: CFrame)
			if length < 1e-6 then
				return
			end
			local part = Instance.new("WedgePart")
			part.Name = name
			part.Size = Vector3.new(SURFACE, height, length)
			part.Color = color
			part.Material = Enum.Material.SmoothPlastic
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			settle(part, at, group)
		end
		wedge(math.abs(ab:Dot(back)), CFrame.fromMatrix((a + b) / 2, right, up, back))
		wedge(math.abs(ac:Dot(back)), CFrame.fromMatrix((a + c) / 2, -right, up, -back))
	end
	local function surface(shape: Style.Mesh, name: string, group: string, color: Color3)
		local vertices: { Vector3 } = {}
		for _, v in shape.vertices do
			table.insert(vertices, Vector3.new(v.x, v.y, v.z))
		end
		for _, face in shape.faces do
			facet(vertices[face[1]], vertices[face[2]], vertices[face[3]], name, group, color)
		end
	end
	if tail then
		local shape = Style.tail(bounds(tail), if body then bounds(body).sx else bounds(tail).sx)
		surface(shape, "tail", "tail", SKIN)
	end
	if head then
		local headBounds = bounds(head)
		if hornPiece then
			for _, horn in Style.horns(headBounds) do
				local part = hornPiece:Clone()
				part.Name = "Horn"
				local scale = horn.length / hornPiece.Size.Y
				part.Size = hornPiece.Size * Vector3.new(scale * horn.girth, scale, scale * horn.girth)
				local lean = CFrame.Angles(0, 0, -math.rad(horn.splay)) * CFrame.Angles(-math.rad(horn.tilt), 0, 0)
				local root = CFrame.new(horn.x, horn.y, horn.z) * lean
				settle(part, root * CFrame.new(0, part.Size.Y / 2, 0), "head")
			end
		end
		local function facePart(name: string, at: Style.Bounds, color: Color3, shape: Enum.PartType, roll: number?)
			local part = Instance.new("Part")
			part.Name = name
			part.Shape = shape
			part.Size = Vector3.new(at.sx, at.sy, at.sz)
			part.Color = color
			part.Material = Enum.Material.SmoothPlastic
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			settle(part, CFrame.new(at.x, at.y, at.z) * CFrame.Angles(0, 0, math.rad(roll or 0)), "head")
		end
		facePart("NoseCap", Style.noseCap(headBounds), SKIN, Enum.PartType.Block)
		for _, eye in Style.eyes(headBounds) do
			facePart("EyeSocket", eye.socket, SKIN, Enum.PartType.Block)
			facePart("Eye", eye.ball, IRIS, Enum.PartType.Ball)
			facePart("Pupil", eye.pupil, PUPIL, Enum.PartType.Ball)
			facePart("EyeGlint", eye.glint, GLINT, Enum.PartType.Ball)
			facePart("Brow", eye.brow, BROW, Enum.PartType.Block, eye.browRoll)
		end
	end
	return parts
end

return TriceratopsCar

TOOL.Category = "Constraints"
TOOL.Name = "Multi-Unparent"

if CLIENT then
	language.Add("tool.multi_unparent.name","Multi-Unparent 2.0")
	language.Add("tool.multi_unparent.desc","Unparent multiple entities")
	language.Add("tool.multi_unparent.left","Primary: Add an entity to the selection")
	language.Add("tool.multi_unparent.right","Secondary: Unparent all selected entities")
	language.Add("tool.multi_unparent.reload","Reload: Clear selected entities")

	language.Add("tool.multi_unparent.left_use","Primary + Use: Select entities in an area")
end

TOOL.Information = {
	{
		name = "left"
	},
	{
		name = "left_use"
	},
	{
		name = "right"
	},
	{
		name = "reload"
	}
}

TOOL.ClientConVar["radius"] = "512"

TOOL.SelectedEntities = {}
TOOL.SelectedCount = 0
TOOL.OldEntityColors = {}

local entMeta = FindMetaTable("Entity")

local getOwner = function(ent)
	if entMeta.CPPIGetOwner then return ent:CPPIGetOwner() end

	return ent:GetOwner()
end

-- Also unused, maybe will be used
local selection_blacklist = {
	["player"] = true,
	["predicted_viewmodel"] = true, -- Some of these may not be needed, whatever. (idk what does this mean but whatever, i'll just let it sit here)
	["gmod_tool"] = true,
	["none"] = true
}

function TOOL:SelectEntity(ent)
	if self.SelectedEntities[ent] then return end

	self.SelectedEntities[ent] = true

	self.SelectedCount = self.SelectedCount + 1

	self.OldEntityColors[ent] = ent:GetColor()

	ent:SetColor(Color(255, 0, 0, 100))
	ent:SetRenderMode(RENDERMODE_TRANSALPHA)
end

function TOOL:DeselectEntity(ent)
	if not self.SelectedEntities[ent] then return end

	ent:SetColor(self.OldEntityColors[ent] or Color(255, 255, 255, 255))

	self.SelectedCount = self.SelectedCount - 1

	self.SelectedEntities[ent] = nil
	self.OldEntityColors[ent] = nil
end

function TOOL:LeftClick(trace)
	if CLIENT then return true end
	local ent = trace.Entity

	if not IsValid(ent) or ent:IsPlayer() or not util.IsValidPhysicsObject(ent, trace.PhysicsBone) then return false end

	local ply = self:GetOwner()
	if not ply:KeyDown(IN_USE) and ent:IsWorld() then return false end

	if ply:KeyDown(IN_USE) then
		local radius = math.Clamp(self:GetClientNumber("radius"), 64, 1024)
		local selected = 0

		for _, v in ipairs(ents.FindInSphere(trace.HitPos, radius)) do
			if not IsValid(v) or v:IsWeapon() or selection_blacklist[v:GetClass()] or v:IsPlayer() or v:IsWorld() then continue end

			if IsValid(v) and not self.SelectedEntities[v] and getOwner(ent) == ply then
				self:SelectEntity(v)

				selected = selected + 1
			end
		end

		ply:PrintMessage(HUD_PRINTTALK, "Multi-Parent: " .. selected .. " entities were selected.")
	elseif self.SelectedEntities[ent] then
		self:DeselectEntity(ent)
	else
		self:SelectEntity(ent)
	end

	return true
end

function TOOL:RightClick(trace)
	if CLIENT then return true end
	if self.SelectedCount <= 0 then return false end

	local owner = self:GetOwner()
	local count = 0

	for ent in pairs(self.SelectedEntities) do
		if not IsValid(ent) then continue end

		ent:SetParent()
		ent:SetPos(ent:GetPos())
		self:DeselectEntity(ent)

		local physObj = ent:GetPhysicsObject()
		if IsValid(physObj) then physObj:EnableMotion(false) end

		count = count + 1
	end

	owner:PrintMessage(HUD_PRINTTALK, "Multi-Unparent: " .. count .. " entities were unparented.")

	if self.SelectedCount > 0 then
		owner:PrintMessage(HUD_PRINTTALK, self.SelectedCount .. " entities failed to unparent.")
	end

	return true
end

function TOOL:Reload()
	if CLIENT then return true end
	if self.SelectedCount <= 0 then return end

	for ent in pairs(self.SelectedEntities) do
		if not IsValid(ent) then continue end
		
		ent:SetColor(self.OldEntityColors[ent])
	end

	self.SelectedCount = 0
	self.SelectedEntities = {}
	self.OldEntityColors = {}

	return true
end

function TOOL:Think()
	for ent in pairs(self.SelectedEntities) do
		if not IsValid(ent) then 
			self.SelectedEntities[ent] = nil
			self.SelectedCount = self.SelectedCount - 1
			self.OldEntityColors[ent] = nil
		end
	end
end

if CLIENT then
	function TOOL.BuildCPanel(panel)
		panel:AddControl("Slider", {
			Label = "Auto Select Radius:",
			Type = "integer",
			Min = "64",
			Max = "1024",
			Command = "multi_unparent_radius"
		})
	end
end
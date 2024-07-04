TOOL.Category = "Constraints"
TOOL.Name = "Multi-Parent"

if CLIENT then
	language.Add("tool.multi_parent.name","Multi-Parent 2.0")
	language.Add("tool.multi_parent.desc","Parent multiple entities to one entity")
	language.Add("tool.multi_parent.left","Primary: Add an entity to the selection")
	language.Add("tool.multi_parent.right","Secondary: Parent all selected entities to the entity")
	language.Add("tool.multi_parent.reload","Reload: Clear selected entities")

	language.Add("tool.multi_parent.removeconstraints", "Remove constraints before parenting")
	language.Add("tool.multi_parent.nocollide", "No collide")
	language.Add("tool.multi_parent.weld", "Weld")
	language.Add("tool.multi_parent.disablecollisions", "Disable collisions")
	language.Add("tool.multi_parent.weight", "Set weight")
	language.Add("tool.multi_parent.disableshadows", "Disable shadows")

	language.Add("tool.multi_parent.removeconstraints.help", "This can't be undone!")
	language.Add("tool.multi_parent.nocollide.help", "You will need to area-copy your contraption to duplicate.")
	language.Add("tool.multi_parent.weld.help", "This will retain the physics on parented props and you will be able to physgun them, but it will cause more lag.")
	language.Add("tool.multi_parent.weight.help", "Sets the entity's mass to 0.1 before parenting.")

	language.Add("tool.multi_parent.left_use","Primary + Use: Select entities in an area")
	language.Add("tool.multi_parent.left1","Primary + Sprint: Select all entities connected to the entity (the whole contraption)")

	language.Add("tool.multi_parent.undo","Undone Multi-Parent")
end

TOOL.Information = {
	{
		name = "left"
	},
	{
		name = "left_use"
	},
	{
		name = "left1",
		icon2 = "gui/noicon.png"
	},
	{
		name = "right"
	},
	{
		name = "reload"
	}
}

TOOL.ClientConVar["removeconstraints"] = "0"
TOOL.ClientConVar["nocollide"] = "0"
TOOL.ClientConVar["disablecollisions"] = "0"
TOOL.ClientConVar["weld"] = "0"
TOOL.ClientConVar["weight"] = "0"
TOOL.ClientConVar["radius"] = "512"
TOOL.ClientConVar["disableshadows"] = "0"

TOOL.SelectedEntities = {}
TOOL.OldEntityColors = {}

local entMeta = FindMetaTable("Entity")

local getOwner = function(ent)
	if entMeta.CPPIGetOwner then
		return ent:CPPIGetOwner()
	end

	return ent:GetOwner()
end

local selection_blacklist = {
	["player"] = true,
	["predicted_viewmodel"] = true,
	["gmod_tool"] = true,
	["none"] = true
}

function TOOL:SelectEntity(ent)
	if self.SelectedEntities[ent] then return end

	self.SelectedEntities[ent] = true
	self.OldEntityColors[ent] = {ent:GetColor(), ent:GetRenderMode()}

	ent:SetColor(Color(0,255,0,100))
	ent:SetRenderMode(RENDERMODE_TRANSALPHA)
end

function TOOL:DeselectEntity(ent)
	if not self.SelectedEntities[ent] then return end

	ent:SetColor(self.OldEntityColors[ent][1] or Color(255, 255, 255, 255))
	ent:SetRenderMode(self.OldEntityColors[ent][2] or RENDERMODE_NORMAL)

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
			if not IsValid(v) or selection_blacklist[v:GetClass()] or v:IsPlayer() or v:IsWorld() or v:IsWeapon() then continue end

			if not self.SelectedEntities[v] and getOwner(ent) == ply then
				self:SelectEntity(v)
				selected = selected + 1
			end
		end

		ply:PrintMessage(HUD_PRINTTALK, "Multi-Parent: " .. selected .. " entities were selected.")
	elseif ply:KeyDown(IN_SPEED) then
		local selected = 0

		for _, v in pairs(constraint.GetAllConstrainedEntities(ent)) do
			if not IsValid(v) or v:IsWeapon() or selection_blacklist[v:GetClass()] or v:IsPlayer() or v:IsWorld() then continue end

			if not self.SelectedEntities[v] and getOwner(ent) == ply then
				self:SelectEntity(v)
				selected = selected + 1
			end
		end

		ply:PrintMessage(HUD_PRINTTALK, "Multi-Parent: " .. selected .. " entities were selected.")
	elseif self.SelectedEntities[ent] then
		self:DeselectEntity(ent)

		for _, v in ipairs(ent:GetChildren()) do
			if IsValid(v) then self:DeselectEntity(v) end
		end
	else
		self:SelectEntity(ent)

		for _, v in ipairs(ent:GetChildren()) do
			if IsValid(v) then self:SelectEntity(v) end
		end
	end

	return true
end

function TOOL:RightClick(trace)
	if CLIENT then return true end
	local ent = trace.Entity

	self:DeselectEntity(ent)

	if table.Count(self.SelectedEntities) <= 0 or not IsValid(ent) or ent:IsPlayer() or not util.IsValidPhysicsObject(ent, trace.PhysicsBone) or ent:IsWorld() then return false end

	local bNoCollide = 			tobool(self:GetClientNumber("nocollide"))
	local bDisableCollisions = 	tobool(self:GetClientNumber("disablecollisions"))
	local bWeld = 				tobool(self:GetClientNumber("weld"))
	local bRemoveConstraints = 	tobool(self:GetClientNumber("removeconstraints"))
	local bWeight = 			tobool(self:GetClientNumber("weight"))
	local bDisableShadows = 	tobool(self:GetClientNumber("disableshadow"))

	local undoTbl = {}

	undo.Create("Multi-Parent")

	for ent2 in pairs(self.SelectedEntities) do
		if IsValid(ent2) and not ent2:IsPlayer() and not ent2:IsWorld() then
			local physObj = ent2:GetPhysicsObject()

			if IsValid(physObj) then
				local tData = {}

				if bRemoveConstraints then constraint.RemoveAll(ent2) end
				if bNoCollide then undo.AddEntity(constraint.NoCollide(ent2, ent, 0, 0)) end
				if bDisableCollisions then
					tData.CollisionGroup = ent2:GetCollisionGroup()
					ent2:SetCollisionGroup(COLLISION_GROUP_WORLD)
				end
				if bWeld then undo.AddEntity(constraint.Weld(ent2, ent, 0, 0)) end
				if bWeight then
					tData.Mass = physObj:GetMass()
					physObj:SetMass(0.1)
					duplicator.StoreEntityModifier(ent2, "mass", {Mass = 0.1})
				end
				if bDisableShadows then
					tData.DisableShadow = true
					ent2:DrawShadow(false)
				end

				physObj:EnableMotion(true)
				physObj:Sleep()

				ent2:SetParent(ent)

				self:DeselectEntity(ent2)

				undoTbl[ent2] = tData
			end
		end
	end

	undo.AddFunction(function(_, undoTbl)
		for k, v in pairs(undoTbl) do
			if IsValid(k) then
				local physObj = k:GetPhysicsObject()

				if IsValid(physObj) then
					physObj:EnableMotion(false)

					k:SetParent()
					k:SetPos(k:GetPos())

					if v.Mass then physObj:SetMass(v.Mass) end
					if v.CollisionGroup then k:SetCollisionGroup(v.CollisionGroup) end
					if v.DisableShadow then k:DrawShadow(true) end
				end
			end
		end
	end, undoTbl)

	undo.SetPlayer(self:GetOwner())
	undo.Finish()

	local result = table.Count(self.SelectedEntities)
	if result > 0 then
		owner:PrintMessage(HUD_PRINTTALK, result .. " entities failed to unparent.")
	end

	return true
end

function TOOL:Reload()
	if CLIENT then return true end
	if table.Count(self.SelectedEntities) <= 0 then return end

	for ent in pairs(self.SelectedEntities) do
		if not IsValid(ent) then continue end

		ent:SetColor(self.OldEntityColors[ent][1] or Color(255, 255, 255, 255))
		ent:SetRenderMode(self.OldEntityColors[ent][2] or RENDERMODE_NORMAL)
	end

	self.SelectedEntities = {}
	self.OldEntityColors = {}

	return true
end

function TOOL:Think()
	for ent in pairs(self.SelectedEntities) do
		if not IsValid(ent) then 
			self.SelectedEntities[ent] = nil
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
			Command = "multi_parent_radius"
		})

		panel:AddControl("Checkbox", {
			Label = "#tool.multi_parent.removeconstraints",
			Command = "multi_parent_removeconstraints",
			Help = true
		})

		panel:AddControl("Checkbox", {
			Label = "#tool.multi_parent.nocollide",
			Command = "multi_parent_nocollide",
			Help = true
		})

		panel:AddControl("Checkbox", {
			Label = "#tool.multi_parent.weld",
			Command = "multi_parent_weld",
			Help = true
		})

		panel:AddControl("Checkbox", {
			Label = "#tool.multi_parent.weight",
			Command = "multi_parent_weight",
			Help = true
		})

		panel:AddControl("Checkbox", {
			Label = "#tool.multi_parent.disablecollisions",
			Command = "multi_parent_disablecollisions",
		})

		panel:AddControl("Checkbox", {
			Label = "#tool.multi_parent.disableshadows",
			Command = "multi_parent_disableshadows"
		})
	end
end
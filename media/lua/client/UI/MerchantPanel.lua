-- Copyright (c) 2023 Oneline/D.Borovsky
-- All rights reserved
require "ISUI/ISPanel"
require "Scripting/Commands/CommandList_a"
require "Scripting/ItemFetcher"
require "Scripting/MerchantManager"

local label_tooltip = getTextOrNull("UI_ItemFetcher_Tooltip_Drag") or "Drop items here";
local label_list_1 = getTextOrNull("UI_QSystem_Trade_List_1") or "Offerings";
local label_list_2 = getTextOrNull("UI_QSystem_Trade_List_2") or "Demands";
local label_list_3 = getTextOrNull("UI_QSystem_Trade_List_3") or "Stock";
local label_worth_s = getTextOrNull("UI_QSystem_Trade_Single") or "\"This one is worth %d.\"";
local label_worth_m = getTextOrNull("UI_QSystem_Trade_Multiple") or "\"Each of these is worth %d.\"";
local label_confirm = getTextOrNull("UI_QSystem_Trade_Confirm") or " <CENTRE> The value of demands is lower than the value of offerings. <LINE> The remainder will be lost. <LINE> <LINE> Proceed?";

MerchantPanel = ISPanel:derive("MerchantPanel");
MerchantPanel.instance = nil;


local entryBox = ISPanel:derive("MerchantModal");

function entryBox:confirm()
	if MerchantPanel.instance then
		if self.mode == 1 then
			MerchantPanel.instance.btn_demand.textColor = {r=1, g=1, b=1, a=0.5};
			MerchantPanel.instance:addToDemands(self.value);
		else
			MerchantPanel.instance.btn_remove.textColor = {r=1, g=1, b=1, a=0.5};
			MerchantPanel.instance:removeFromDemands(self.value);
		end
	end
	self.close();
end

function entryBox:cancel()
	if MerchantPanel.instance then
		if self.mode == 1 then
			MerchantPanel.instance.btn_demand.textColor = {r=1, g=1, b=1, a=0.5};
		else
			MerchantPanel.instance.btn_remove.textColor = {r=1, g=1, b=1, a=0.5};
		end
	end
	self.close();
end

function entryBox:createChildren()
    self.entry = ISTextEntryBox:new("1", 10*SSRLoader.scale, 10*SSRLoader.scale, self.width - 20*SSRLoader.scale, 25*SSRLoader.scale);
	self.entry.font = UIFont.Medium;
	self.entry:initialise();
	self.entry:instantiate();
	self.entry:setOnlyNumbers(true);
	self.entry:setMaxLines(1);
	self.entry:setMaxTextLength(9);
	self.entry.onTextChange = function()
		local text = self.entry:getInternalText();
		if string.match(text, "^%d+$") then
			local status, value = pcall(tonumber, text);
			if status and value then
				if value > 0 and value <= self.maximum then
					self.value = value;
					self.entry:setValid(true);
					self.confirmBtn:setEnable(true);
					return;
				end
			end
		end
		self.confirmBtn:setEnable(false);
		self.entry:setValid(false);
	end
	self:addChild(self.entry);

	local width = (self.width - 30*SSRLoader.scale) / 2;
	self.confirmBtn = ISButton:new(10*SSRLoader.scale, self.height - 35*SSRLoader.scale, width, 25*SSRLoader.scale, getTextOrNull("UI_Ok") or "Ok", self, entryBox.confirm);
	self.confirmBtn.font = UIFont.Medium;
	self.confirmBtn:initialise();
	self.confirmBtn:instantiate();
	self.confirmBtn.borderColor = {r=1, g=1, b=1, a=0.3};
	self.confirmBtn.textColor =  {r=1, g=1, b=1, a=0.5};
	self:addChild(self.confirmBtn);

	self.cancelBtn = ISButton:new(20*SSRLoader.scale + width, self.height - 35*SSRLoader.scale, width, 25*SSRLoader.scale, getTextOrNull("UI_Cancel") or "Cancel", self, entryBox.cancel);
	self.cancelBtn.font = UIFont.Medium;
	self.cancelBtn:initialise();
	self.cancelBtn:instantiate();
	self.cancelBtn.borderColor = {r=1, g=1, b=1, a=0.3};
	self.cancelBtn.textColor =  {r=1, g=1, b=1, a=0.5};
	self:addChild(self.cancelBtn);
end

function entryBox:new(x, y, maximum, mode, close)
    local o = ISPanel:new(x, y, 200*SSRLoader.scale, 100*SSRLoader.scale);
    setmetatable(o, self);
    self.__index = self;
	o.backgroundColor = {r=0.2, g=0.2, b=0.2, a=0.9};
	o.borderColor.a = 1;
	o.maximum = maximum;
	o.value = 1;
	o.mode = mode;
	o.close = close;
	return o;
end


local color = { { r = 1, g = 1, b = 1, a = 0.9 }, { r = 1, g = 0.5, b = 0.5, a = 0.9 } }
local numerals = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9' }

local char_offset = 0;
for i=1, 10 do
	local char_width = getTextManager():MeasureStringX(UIFont.NewSmall, numerals[i]);
	char_offset = char_width > char_offset and char_width or char_offset;
end

local function getFontOffset(text)
	return getTextManager():MeasureStringX(UIFont.NewSmall, text) + (char_offset - getTextManager():MeasureStringX(UIFont.NewSmall, string.sub(text, -1)));
end

function MerchantPanel:drawStock(y, entry, alt)
	self:setStencilRect(0, 0, self.width, self.height);
    if self.selected == entry.index then self:drawRect(0, (y), self.width, self.itemheight - 1, 0.3, 0.7, 0.35, 0.15); end
	self:clearStencilRect();

	local offset = char_offset * 3 + 30*SSRLoader.scale;
	local stock = math.floor(entry.item.amount / entry.item.pack_size) - entry.item.pending;
	local c = entry.item.buyback and 2 or 1;
	local a = stock == 0 and 0.5 or color[c].a;

	self:setStencilRect(0, 0, self.width - offset, self.height);
	self:drawTextureScaledAspect(entry.item.texture, 5, y + 2, 18, 18, a, color[c].r, color[c].g, color[c].b);
	self:drawText(entry.text..(entry.item.pack_size > 1 and " (x"..tostring(entry.item.pack_size)..")" or ""), 25, y + 2, color[c].r, color[c].g, color[c].b, a, self.font);
	self:clearStencilRect();

	self:setStencilRect(self.width - offset, 0, offset, self.height);
	local amount = tostring(stock);
	if entry.item.pending > 0 then
		self:drawText(amount, self.width - 20*SSRLoader.scale - getFontOffset(amount), y + 2, 1, 0.95, 0.3, 0.9, self.font);
	else
		self:drawText(amount, self.width - 20*SSRLoader.scale - getFontOffset(amount), y + 2, color[c].r, color[c].g, color[c].b, a, self.font);
	end
	self:clearStencilRect();
    return y + self.itemheight;
end

function MerchantPanel:drawDemand(y, entry, alt)
	self:setStencilRect(0, 0, self.width, self.height);
    if self.selected == entry.index then self:drawRect(0, (y), self.width, self.itemheight - 1, 0.3, 0.7, 0.35, 0.15); end
	self:clearStencilRect();

	local offset = char_offset * 3 + 30*SSRLoader.scale;
	self:setStencilRect(0, 0, self.width - offset, self.height);
	self:drawTextureScaledAspect(entry.item.texture, 5, y + 2, 18, 18, 1, 1, 1, 1);
	self:drawText(entry.text..(entry.item.pack_size > 1 and " (x"..tostring(entry.item.pack_size)..")" or ""), 25, y + 2, 1, 1, 1, 0.9, self.font);
	self:clearStencilRect();

	self:setStencilRect(self.width - offset, 0, offset, self.height);
	local amount = tostring(entry.item.pending);
	self:drawText(amount, self.width - 20*SSRLoader.scale - getFontOffset(amount), y + 2, 1, 1, 1, 0.9, self.font);
	self:clearStencilRect();
	return y + self.itemheight;
end

function MerchantPanel:drawOffer(y, entry, alt)
	local offset = char_offset * 3 + 30*SSRLoader.scale;
	self:setStencilRect(0, 0, self.width - offset, self.height);
	self:drawTextureScaledAspect(entry.item.items[1]:getTex(), 5, y + 2, 18, 18, 1, entry.item.items[1]:getR(), entry.item.items[1]:getG(), entry.item.items[1]:getB());
	self:drawText(entry.text, 25, y + 2, 1, 1, 1, 0.9, self.font);
	self:clearStencilRect();

	self:setStencilRect(self.width - offset, 0, offset, self.height);
	local amount = tostring(entry.item.amount);
	self:drawText(amount, self.width - 20*SSRLoader.scale - getFontOffset(amount), y + 2, 1, 1, 1, 0.9, self.font);
	self:clearStencilRect();
	return y + self.itemheight;
end

function MerchantPanel:calculateValue(item)
	return math.ceil(item.value * item.pack_size * (item.buyback and 1 or self.discount));
end

local total_h = getTextManager():MeasureStringY(UIFont.Large, "0") / 2;
function MerchantPanel:prerender()
	ISPanel.prerender(self);
	self:drawTextCentre(label_list_1, (self.offerings.x + self.offerings.width/2), 15*SSRLoader.scale, 0.6, 0.6, 0.6, 1, UIFont.Medium);
	self:drawTextCentre(label_list_2, (self.demands.x + self.demands.width/2), 15*SSRLoader.scale, 0.6, 0.6, 0.6, 1, UIFont.Medium);
	self:drawTextCentre(label_list_3, (self.stock.x + self.stock.width/2), 15*SSRLoader.scale, 0.6, 0.6, 0.6, 1, UIFont.Medium);
	if self.total > 0 then
		self:drawText(tostring(self.total), 60*SSRLoader.scale, self.height - total_h - 25*SSRLoader.scale, 0.4, 1, 0.4, 1, UIFont.Large);
		self:drawTextureScaled(self.scales_tex[1], 10*SSRLoader.scale, self.height-43*SSRLoader.scale, 40*SSRLoader.scale, 34*SSRLoader.scale, 1, 1, 1, 1)
	elseif self.total == 0 then
		self:drawText(tostring(self.total), 60*SSRLoader.scale, self.height - total_h - 25*SSRLoader.scale, 1, 1, 1, 1, UIFont.Large);
		self:drawTextureScaled(self.scales_tex[2], 10*SSRLoader.scale, self.height-43*SSRLoader.scale, 40*SSRLoader.scale, 34*SSRLoader.scale, 1, 1, 1, 1)
	else
		self:drawText(tostring(self.total), 60*SSRLoader.scale, self.height - total_h - 25*SSRLoader.scale, 1, 0.4, 0.4, 1, UIFont.Large);
		self:drawTextureScaled(self.scales_tex[3], 10*SSRLoader.scale, self.height-43*SSRLoader.scale, 40*SSRLoader.scale, 34*SSRLoader.scale, 1, 1, 1, 1)
	end

	if self.stock.items[1] and self.stock.mouseoverselected and self.stock.mouseoverselected ~= -1 then
		self:drawTextCentre(string.format(math.floor(self.stock.items[self.stock.mouseoverselected].item.amount / self.stock.items[self.stock.mouseoverselected].item.pack_size) > 1 and label_worth_m or label_worth_s, self:calculateValue(self.stock.items[self.stock.mouseoverselected].item)), self.width / 2, self.height-35*SSRLoader.scale, 1, 1, 1, 1, UIFont.Medium);
	elseif self.demands.items[1] and self.demands.mouseoverselected and self.demands.mouseoverselected ~= -1 then
		self:drawTextCentre(string.format(self.demands.items[self.demands.mouseoverselected].item.pending > 1 and label_worth_m or label_worth_s, self:calculateValue(self.demands.items[self.demands.mouseoverselected].item)), self.width / 2, self.height-35*SSRLoader.scale, 1, 1, 1, 1, UIFont.Medium);
	elseif self.offerings.items[1] and self.offerings.mouseoverselected and self.offerings.mouseoverselected ~= -1 then
		self:drawTextCentre(string.format(self.offerings.items[self.offerings.mouseoverselected].item.amount > 1 and label_worth_m or label_worth_s, self.offerings.items[self.offerings.mouseoverselected].item.value), self.width / 2, self.height-35*SSRLoader.scale, 1, 1, 1, 1, UIFont.Medium);
	end
end

local tt_w, tt_h = 128, 256;
function MerchantPanel:render()
	ISPanel.render(self);
	if not self.offerings.items[1] then
		self:drawTextCentre(label_tooltip, self.offerings.x + (self.offerings.width / 2), self.offerings.y + (self.offerings.height / 2) - 20*SSRLoader.scale, 0.5, 0.5, 0.5, 1, UIFont.NewSmall);
	end
	if self.stock.items[1] and self.stock.mouseoverselected and self.stock.mouseoverselected > 0 and self.stock.items[self.stock.mouseoverselected].item.w_texture then
		self:drawRect(self.stock.x - (tt_w+10)*SSRLoader.scale, self.stock.y + 10*SSRLoader.scale, tt_w*SSRLoader.scale, tt_h*SSRLoader.scale, 1, 0.5, 0.5, 0.5);
		self:drawTextureScaledAspect(self.stock.items[self.stock.mouseoverselected].item.w_texture, self.stock.x - (tt_w+10)*SSRLoader.scale, self.stock.y + 10*SSRLoader.scale, tt_w*SSRLoader.scale, tt_h*SSRLoader.scale, 1, 1, 1, 1);
		self:drawRectBorder(self.stock.x - (tt_w+10)*SSRLoader.scale, self.stock.y + 10*SSRLoader.scale, tt_w*SSRLoader.scale, tt_h*SSRLoader.scale, 1, 0.8, 0.8, 0.8);
	end
end

function MerchantPanel:updateButtons()
	if self.offerings.items[1] then
		self.btn_clear:setEnable(true);
	else
		self.btn_clear:setEnable(false);
	end

	if self.demands.items[1] and self.demands.selected > 0 then
		self.btn_remove:setEnable(true);
	else
		self.btn_remove:setEnable(false);
	end

	if self.stock.items[1] and self.stock.selected > 0 and (math.floor(self.stock.items[self.stock.selected].item.amount / self.stock.items[self.stock.selected].item.pack_size) - self.stock.items[self.stock.selected].item.pending > 0) then
		self.btn_demand:setEnable(true);
	else
		self.btn_demand:setEnable(false);
	end

	if (self.demands.items[1] or self.offerings.items[1]) and self.total >= 0 then
		self.barter:setEnable(true);
	else
		self.barter:setEnable(false);
	end
end

function MerchantPanel:onSelect(item)
	self:updateButtons();
end

local function isVisible(flag)
	if flag then
		if flag:starts_with('!') then
			return not CharacterManager.instance:isFlag(flag:sub(2));
		else
			return CharacterManager.instance:isFlag(flag);
		end
	end
	return true;
end

function MerchantPanel:populateList()
	self.stock:clear();
	for i=1, #MerchantManager.instance.items[self.index].stock do
		MerchantManager.instance.items[self.index].stock[i].pending = 0;
		if isVisible(MerchantManager.instance.items[self.index].stock[i].flag) then
			self.stock:addItem(MerchantManager.instance.items[self.index].stock[i].name, MerchantManager.instance.items[self.index].stock[i]);
		end
	end
	if MerchantManager.settings.buyback then
		local m = getPlayer():getModData();
		if m.buyback then
			for i=1, #m.buyback do
				if m.buyback[i].id == MerchantManager.instance.items[self.index].id then
					for j=1, #m.buyback[i].stock do
						m.buyback[i].stock[j].pending = 0;
						if math.floor(m.buyback[i].stock[j].amount / m.buyback[i].stock[j].pack_size) > 0 then
							self.stock:addItem(tostring(m.buyback[i].stock[j].name), m.buyback[i].stock[j]);
						end
					end
					break;
				end
			end
		end
	end
end


local function validate(item)
	if not MerchantPanel.instance.inventory:contains(item) then
		return false;
	elseif MerchantPanel.instance.player:isEquipped(item) or MerchantPanel.instance.player:isEquippedClothing(item) then
		return false;
	elseif item:isFavorite() then
		return false;
	end
	return true;
end

function MerchantPanel.OnRefreshInventoryWindowContainers()
	if MerchantPanel.instance then
		local update = false;
		for i=#MerchantPanel.instance.offerings.items, 1, -1 do
			for j=#MerchantPanel.instance.offerings.items[i].item.items, 1, -1 do
				if not validate(MerchantPanel.instance.offerings.items[i].item.items[j]) then
					update = true;
					MerchantPanel.instance.total = MerchantPanel.instance.total - MerchantPanel.instance.offerings.items[i].item.value;
					MerchantPanel.instance.offerings.items[i].item.amount = MerchantPanel.instance.offerings.items[i].item.amount - 1;
					if MerchantPanel.instance.offerings.items[i].item.amount > 0 then
						table.remove(MerchantPanel.instance.offerings.items[i].item.items, j);
					else
						table.remove(MerchantPanel.instance.offerings.items, i);
					end
				end
			end
		end
		if update then MerchantPanel.instance:updateButtons(); end
	end
end

Events.OnRefreshInventoryWindowContainers.Add(MerchantPanel.OnRefreshInventoryWindowContainers)


local function addToOfferings(self, item, value)
	for i=1, #self.offerings.items do
		if self.offerings.items[i].text == item:getName() then
			table.insert(self.offerings.items[i].item.items, item);
			self.offerings.items[i].item.amount = self.offerings.items[i].item.amount + 1;
			return;
		end
	end
	self.offerings:addItem(item:getName(), { items = { item }, amount = 1, value = value } );
end

function MerchantPanel:addToOfferings(item)
	if luautils.haveToBeTransfered(self.player, item) or not validate(item) then return; end

	local itemType = item:getFullType();
	for i=1, #self.offerings.items do
		if self.offerings.items[i].item.items[1]:getFullType() == itemType then
			for j=1, #self.offerings.items[i].item.items do
				if self.offerings.items[i].item.items[j] == item then
					return;
				end
			end
		end
	end

	local value = 0;
	for i=#MerchantManager.instance.items[self.index].demands, 1, -1  do
		if MerchantManager.instance.items[self.index].demands[i].item then
			if itemType == MerchantManager.instance.items[self.index].demands[i].item then
				if not MerchantManager.instance.items[self.index].demands[i].ruleset or ItemFetcher.validate(item, MerchantManager.instance.items[self.index].demands[i].ruleset) then
					value = MerchantManager.instance.items[self.index].demands[i].value;
					break;
				end
			end
		elseif ItemFetcher.validate(item, MerchantManager.instance.items[self.index].demands[i].ruleset) then
			value = MerchantManager.instance.items[self.index].demands[i].value;
			break;
		end
	end
	if value == 0 then return end

	addToOfferings(self, item, value);
	self.total = self.total + value;
	self:updateButtons();
end

function MerchantPanel:offeringMouseUp(x, y)
	self.parent:updateButtons();
    if self.vscroll then
        self.vscroll.scrolling = false;
    end
    local count = 1;
    if ISMouseDrag.dragging then
        for i=1, #ISMouseDrag.dragging do
			count = 1;
			if instanceof(ISMouseDrag.dragging[i], "InventoryItem") then
				self.parent:addToOfferings(ISMouseDrag.dragging[i]);
			else
				if ISMouseDrag.dragging[i].invPanel.collapsed[ISMouseDrag.dragging[i].name] then
					count = 1;
					for j=1, #ISMouseDrag.dragging[i].items do
						if count > 1 then
							self.parent:addToOfferings(ISMouseDrag.dragging[i].items[j]);
						end
						count = count + 1;
					end
				end
			end
		end
	end
end

function MerchantPanel:clearOffer()
	for i=1, #self.offerings.items do
		self.total = self.total - (self.offerings.items[i].item.value * self.offerings.items[i].item.amount);
	end
	self.offerings:clear();
	self:updateButtons();
end


local function addToDemands(self)
	for i=1, #self.demands.items do
		if self.demands.items[i].text == self.stock.items[self.stock.selected].text then return; end
	end
	self.demands:addItem(self.stock.items[self.stock.selected].text, self.stock.items[self.stock.selected].item);
	if self.demands.selected == 0 then self.demands.selected = 1; end
end

function MerchantPanel:addToDemands(n)
	self.stock.items[self.stock.selected].item.pending = self.stock.items[self.stock.selected].item.pending + n;
	addToDemands(self);
	self.total = self.total - self:calculateValue(self.stock.items[self.stock.selected].item) * n;
	self:updateButtons();
end

function MerchantPanel:removeFromDemands(n)
	self.demands.items[self.demands.selected].item.pending = self.demands.items[self.demands.selected].item.pending - n;
	self.total = self.total + self:calculateValue(self.demands.items[self.demands.selected].item) * n;
	if self.demands.items[self.demands.selected].item.pending < 1 then table.remove(self.demands.items, self.demands.selected); end
	self:updateButtons();
end

function MerchantPanel:addToBuyback(itemType, amount, value)
	local m = getPlayer():getModData();
	if not m.buyback then m.buyback = {}; end
	local item = getScriptManager():FindItem(itemType);
	if item then
		for i=1, #m.buyback do
			if m.buyback[i].id == MerchantManager.instance.items[self.index].id then
				for j=1, #m.buyback[i].stock do
					if m.buyback[i].stock[j].type == itemType then
						m.buyback[i].stock[j].amount = m.buyback[i].stock[j].amount + amount;
						return;
					end
				end
				m.buyback[i].stock[#m.buyback[i].stock+1] = { name = item:getDisplayName(), type = item:getFullName(), amount = amount, pack_size = item:getCount(), texture = QItemFactory.getTextureFromItem(item), value = value, buyback = true };
				return;
			end
		end
		m.buyback[#m.buyback+1] = {
			id = MerchantManager.instance.items[self.index].id,
			stock = {
				{ name = item:getDisplayName(), type = item:getFullName(), amount = amount, pack_size = item:getCount(), texture = QItemFactory.getTextureFromItem(item), value = value, buyback = true }
			}
		};
	end
end

function MerchantPanel:confirmBarter()
	MerchantPanel.OnRefreshInventoryWindowContainers();
	if self.barter.enable then
		local remainder, cost = self.total, 0;
		for i=1, #self.offerings.items do
			local itemType = self.offerings.items[i].item.items[1]:getFullType();
			for j=1, #self.offerings.items[i].item.items do
				self.inventory:Remove(self.offerings.items[i].item.items[j]);
			end
			self.total = self.total - (self.offerings.items[i].item.value * self.offerings.items[i].item.amount);
			local create_entry = true;
			for j=1, #self.stock.items do
				if self.stock.items[j].item.type == itemType then
					self.stock.items[j].item.amount = self.stock.items[j].item.amount + self.offerings.items[i].item.amount;
					if self.stock.items[j].item.unique and self.stock.items[j].item.amount > self.stock.items[j].item.default then
						self.stock.items[j].item.amount = self.stock.items[j].item.default;
					end
					create_entry = false;
					break;
				end
			end
			if create_entry and MerchantManager.settings.buyback then
				self:addToBuyback(itemType, self.offerings.items[i].item.amount, math.ceil(self.offerings.items[i].item.value * MerchantManager.settings.buyback_m));
			end
		end
		self.offerings:clear();
		if self.demands.items[1] then
			local demands = {}
			for i=1, #self.demands.items do
				demands[#demands+1] = QItemFactory.createEntry(self.demands.items[i].item.type, self.demands.items[i].item.pending);
				local value = self:calculateValue(self.demands.items[i].item) * self.demands.items[i].item.pending;
				self.total = self.total + value; cost = cost + value;
				self.demands.items[i].item.amount = self.demands.items[i].item.amount - (self.demands.items[i].item.pending * self.demands.items[i].item.pack_size);
				self.demands.items[i].item.pending = 0;
			end
			self.demands:clear();
			QItemFactory.request(string.format("barter, %s", MerchantManager.instance.items[self.index].id), demands, nil);
			remainder = MerchantManager.calculateReputation(remainder, cost);
		end
		if self.stat and remainder > 0 then
			remainder = remainder * MerchantManager.settings.reputation_m;
			self.reputation = CharacterManager.instance.items[MerchantManager.instance.items[self.index].index]:increaseStat(self.stat, remainder); -- update reputation
			self.discount = MerchantManager.calculateDiscount(self.reputation); -- update discount
		end
		if MerchantManager.settings.buyback then
			local m = getPlayer():getModData();
			if not m.buyback then m.buyback = {}; end
			for i=1, #m.buyback do
				if m.buyback[i].id == MerchantManager.instance.items[self.index].id then
					for j=#m.buyback[i].stock, 1, -1  do
						if m.buyback[i].stock[j].amount == 0 then
							table.remove(m.buyback[i].stock, j);
						end
					end
					break;
				end
			end
			self:populateList();
		end
		self.success = true;
		self:updateButtons();
		SaveManager.onMerchantDataChange();
		SaveManager.save();
	end
end

local function confirmBarter(self, button)
	if button.internal == "YES" then
		self:confirmBarter();
	end
end

function MerchantPanel:createModal(mode)
	local function close()
		if self.modal then
			self:removeChild(self.modal);
			self.modal = nil;
		end
	end
	if mode == 1 then
		MerchantPanel.instance.btn_demand.textColor = {r=0.0, g=1.0, b=1.0, a=1.0};
	else
		MerchantPanel.instance.btn_remove.textColor = {r=0.0, g=1.0, b=1.0, a=1.0};
	end
	self.modal = entryBox:new(self.width / 2 - 100*SSRLoader.scale, self.height / 2 - 50*SSRLoader.scale, mode == 1 and (self.stock.items[self.stock.selected].item.amount - self.stock.items[self.stock.selected].item.pending) or self.stock.items[self.stock.selected].item.pending, mode, close)
	self.modal:initialise();
	self.modal:setCapture(true);
	self:addChild(self.modal);
end

function MerchantPanel:onButtonPressed(button)
	if button.internal == 0 then -- clear
		self:clearOffer();
	elseif button.internal == 1 then -- remove from demands
		if self.stock.items[self.stock.selected].item.pending > 9 then
			self:createModal(2);
		else
			self:removeFromDemands(1);
		end
	elseif button.internal == 2 then -- add to demands
		if self.stock.items[self.stock.selected].item.amount > 9 then
			self:createModal(1);
		else
			self:addToDemands(1);
		end
	elseif button.internal == 3 then -- barter
		if self.total > 0 then
			local modal = ISModalDialogMod:new(self:getX() + (self:getWidth() / 2) - 175*SSRLoader.scale, self:getY() + (self:getHeight() / 2) - 75*SSRLoader.scale, 350*SSRLoader.scale, 130*SSRLoader.scale, true, self, confirmBarter);
			modal.text = label_confirm;
			modal.backgroundColor = {r=0.3, g=0.1, b=0.1, a=0.8};
			modal.borderColor = {r=0.4, g=0.4, b=0.4, a=1};
			modal:initialise();
			modal:addToUIManager();
			modal:setCapture(true);
			modal:paginate();
		else
			self:confirmBarter();
		end
	elseif button.internal == 4 then -- close
		if self.success and self.onConfirm then
			self.onConfirm();
		elseif self.onCancel then
			self.onCancel();
		end
		self:close();
	end
end

function MerchantPanel:createChildren()
	self.offerings = ISScrollingListBox:new(10*SSRLoader.scale, 40*SSRLoader.scale, 260*SSRLoader.scale, 280*SSRLoader.scale);
    self.offerings:initialise();
    self.offerings:instantiate();
    self.offerings.itemheight = 22*SSRLoader.scale;
    self.offerings.selected = 0;
    self.offerings.joypadParent = self;
    self.offerings.font = UIFont.NewSmall;
    self.offerings.doDrawItem = self.drawOffer;
	self.offerings:setOnMouseDownFunction(self, self.onSelect);
	self.offerings.onMouseUp = self.offeringMouseUp;
	self.offerings.onMouseDown = function () end
    self.offerings.drawBorder = true;
    self:addChild(self.offerings);

    self.demands = ISScrollingListBox:new(self.offerings.x+self.offerings.width, 40*SSRLoader.scale, 260*SSRLoader.scale, 280*SSRLoader.scale);
    self.demands:initialise();
    self.demands:instantiate();
    self.demands.itemheight = 22*SSRLoader.scale;
    self.demands.selected = 0;
    self.demands.joypadParent = self;
    self.demands.font = UIFont.NewSmall;
    self.demands.doDrawItem = self.drawDemand;
	self.demands.onMouseUp = function () end
	self.demands:setOnMouseDownFunction(self, self.onSelect);
    self.demands.backgroundColor.a = 0.5;
	self.demands.drawBorder = true;
    self:addChild(self.demands);

	self.stock = ISScrollingListBox:new(self.demands.x+self.demands.width, 40*SSRLoader.scale, 260*SSRLoader.scale, 280*SSRLoader.scale);
    self.stock:initialise();
    self.stock:instantiate();
    self.stock.itemheight = 22*SSRLoader.scale;
    self.stock.selected = 0;
    self.stock.joypadParent = self;
    self.stock.font = UIFont.NewSmall;
    self.stock.doDrawItem = self.drawStock;
	self.stock.onMouseUp = function () end
	self.stock:setOnMouseDownFunction(self, self.onSelect);
	self.stock.backgroundColor.a = 0.5;
    self.stock.drawBorder = true;
    self:addChild(self.stock);

	local function createButton(i, text, x, y, width, height)
		local button = ISButton:new(x or (10*SSRLoader.scale), y or (self.height - 35*SSRLoader.scale), width or (getTextManager():MeasureStringX(UIFont.Medium, text) + 20*SSRLoader.scale), height or (25*SSRLoader.scale), text, self, MerchantPanel.onButtonPressed);
		button.font = UIFont.Medium;
		button:initialise();
		button:instantiate();
		button.internal = i;
		button.borderColor = {r=1, g=1, b=1, a=0.3};
		button.textColor =  {r=1, g=1, b=1, a=0.5};
		return button;
	end

	self.btn_clear = createButton(0, getTextOrNull("UI_QSystem_Trade_Clear") or "Clear", self.offerings.x, self.offerings.y + self.offerings.height + 5, self.offerings.width);
    self:addChild(self.btn_clear);

	self.btn_remove = createButton(1, "->", self.demands.x, self.demands.y + self.demands.height + 5, self.demands.width);
    self:addChild(self.btn_remove);

	self.btn_demand = createButton(2, "<-", self.stock.x, self.stock.y + self.stock.height + 5, self.stock.width);
    self:addChild(self.btn_demand);

	self.cancel = createButton(4, getTextOrNull("UI_QSystem_Trade_Close") or "Close", nil, self.height - 40*SSRLoader.scale, nil, 30*SSRLoader.scale);
	self.cancel:setX(self.width - self.cancel.width - 10*SSRLoader.scale);
    self:addChild(self.cancel);

	self.barter = createButton(3, getTextOrNull("UI_QSystem_Trade_Barter") or "Barter", nil, self.height - 40*SSRLoader.scale, nil, 30*SSRLoader.scale);
	self.barter:setX(self.cancel.x - self.barter.width - 10*SSRLoader.scale);
    self:addChild(self.barter);

	self:populateList();
	self:updateButtons();
end

function MerchantPanel:new(index, onConfirm, onCancel)
	local w, h = 800*SSRLoader.scale, 400*SSRLoader.scale;
    local o = ISPanel:new((getCore():getScreenWidth() / 2) - (w / 2), (getCore():getScreenHeight() / 2) - (h / 2), w, h);
    setmetatable(o, self);
    self.__index = self;
	o.backgroundColor = {r=0.2, g=0.2, b=0.2, a=0.95};
	o.player = getPlayer();
	o.inventory = o.player:getInventory();
    o.index = index;
	o.onConfirm = onConfirm;
	o.onCancel = onCancel;
	o.total = 0;
	o.stat = MerchantManager.instance.items[index].stat;
	o.reputation = o.stat and CharacterManager.instance.items[MerchantManager.instance.items[index].index]:getStat(o.stat) or 0;
	o.discount = o.stat and MerchantManager.calculateDiscount(o.reputation) or 1;
	o.scales_tex = { getTexture("media/ui/scales_good.png"), getTexture("media/ui/scales_normal.png"), getTexture("media/ui/scales_bad.png") }
	o.modal = nil;
	if MerchantPanel.instance then
		MerchantPanel.instance:removeFromUIManager();
	end
	MerchantPanel.instance = o;
	return o;
end

function MerchantPanel.close()
	if MerchantPanel.instance then
		MerchantPanel.instance:removeFromUIManager();
		MerchantPanel.instance = nil;
		DialogueManager.pause = false;
	end
end

function MerchantPanel.onQSystemUpdate(code)
	if code == 4 then
		MerchantPanel.close();
	end
end

Events.OnQSystemReset.Add(MerchantPanel.close);
Events.OnQSystemUpdate.Add(MerchantPanel.onQSystemUpdate);
Events.OnScriptExit.Add(MerchantPanel.close);
Events.OnPlayerDeath.Add(MerchantPanel.close);

MerchantPanel.create = function(character, onConfirm, onCancel)
	if MerchantPanel.instance then return end
	local index = MerchantManager.instance:indexOf(character);
    if index then
		DialogueManager.pause = true;
		local ui = MerchantPanel:new(index, onConfirm, onCancel);
		ui:initialise();
		ui:addToUIManager();
		return true;
	end
end

MerchantPanel.onResolutionChange = function()
	if MerchantPanel.instance then
		local x = getCore():getScreenWidth() / 2 - MerchantPanel.instance:getWidth() / 2;
		local y = getCore():getScreenHeight() / 2 - MerchantPanel.instance:getHeight() / 2;
		MerchantPanel.instance:setX(x);
		MerchantPanel.instance:setY(y);
	end
end

Events.OnResolutionChange.Add(MerchantPanel.onResolutionChange);
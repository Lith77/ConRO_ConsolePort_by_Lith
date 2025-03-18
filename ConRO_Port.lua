local addonName, addon = ...
local ConROConsolePortSupport = LibStub("AceAddon-3.0"):NewAddon("ConRO_ConsolePort", "AceEvent-3.0")

-- Default settings
local defaults = {
    profile = {
        enableConsolePort = true,
        consolePortZoom = 1.0,
        overlayMainbutton = false,
    }
}

-- Local cache for button combinations during this session
local CPButtonsCache = {}

-- Store original function references
local originalInvokeNextSpell = ConRO and ConRO.InvokeNextSpell
local originalInvokeNextDef = ConRO and ConRO.InvokeNextDef
local originalFindKeybinding = ConRO and ConRO.FindKeybinding
local originalGlowSpell = ConRO.GlowSpell
local originalGlowClear = ConRO.GlowClear
local originalGlowClearDef = ConRO.GlowClearDef
local originalDamageGlow = ConRO.DamageGlow
local originalDefenseGlow = ConRO.DefenseGlow
local originalHideDamageGlow = ConRO.HideDamageGlow
local originalHideDefenseGlow = ConRO.HideDefenseGlow

local damageOverlay = nil
local defenseOverlay = nil

-- Initialize the addon
function ConROConsolePortSupport:OnInitialize()
    -- Initialize database with defaults
    self.db = LibStub("AceDB-3.0"):New("ConROConsolePortDB", defaults)
    
    -- Check if dependencies are loaded
    if not ConRO or not ConsolePort then
        self:RegisterEvent("ADDON_LOADED", "CheckDependencies")
        return
    end
    self:RegisterEvent("ACTIONBAR_SLOT_CHANGED", "OnActionBarChanged")
    -- Both dependencies loaded, proceed with setup
    self:SetupHooks()
    self:SetupOptions()
    print("ConRO ConsolePort support loaded successfully!")
end

-- Check for dependencies
function ConROConsolePortSupport:CheckDependencies(event, loadedAddonName)
    if loadedAddonName == "ConRO" or loadedAddonName == "ConsolePort" then
        if ConRO and ConsolePort then
            -- Both dependencies are now loaded
            self:UnregisterEvent("ADDON_LOADED")
            self:SetupHooks()
            self:SetupOptions()
            print("ConRO ConsolePort support loaded successfully!")
        end
    end
end
function ConROConsolePortSupport:OnActionBarChanged(event, slot)
    -- Clear the cache when any action bar slot changes
    self:ClearConsolePortCache()
    
    -- Force ConRO to update its displays
    if ConRO then
        ConRO:Fetch()
        ConRO:FetchDef()
    end
end
-- Set up function hooks
function ConROConsolePortSupport:SetupHooks()
    -- Check if we've already hooked
    if ConRO._hooked_by_consoleport then
        return
    end
    
    print("Hooking ConRO functions for ConsolePort support...")
    
    -- Replace ConRO's FindKeybinding
    function ConRO:FindKeybinding(id)
        -- Check for ConsolePort first if it's loaded
        if ConsolePort and ConROConsolePortSupport.db.profile.enableConsolePort then
            local cpKeybind = ConROConsolePortSupport:GetConsolePortBindingForAction(id)
            if cpKeybind then
                return cpKeybind
            end
        end
        
        -- Fall back to original behavior if no ConsolePort binding found
        local keybind;
        if self.Keybinds[id] ~= nil then
            for k, button in pairs(self.Keybinds[id]) do
                for i = 1, 12 do
                    if button == 'ActionButton' .. i then
                        button = 'ACTIONBUTTON' .. i;
                    elseif button == 'MultiBarBottomLeftButton' .. i then
                        button = 'MULTIACTIONBAR1BUTTON' .. i;
                    elseif button == 'MultiBarBottomRightButton' .. i then
                        button = 'MULTIACTIONBAR2BUTTON' .. i;
                    elseif button == 'MultiBarRightButton' .. i then
                        button = 'MULTIACTIONBAR3BUTTON' .. i;
                    elseif button == 'MultiBarLeftButton' .. i then
                        button = 'MULTIACTIONBAR4BUTTON' .. i;
                    elseif button == 'MultiBar5Button' .. i then
                        button = 'MULTIACTIONBAR5BUTTON' .. i;
                    elseif button == 'MultiBar6Button' .. i then
                        button = 'MULTIACTIONBAR6BUTTON' .. i;
                    elseif button == 'MultiBar7Button' .. i then
                        button = 'MULTIACTIONBAR7BUTTON' .. i;
                    end
                    keybind = GetBindingKey(button);
                    if keybind ~= nil then
                        return keybind;
                    end
                end
            end
        end
        return keybind;
    end
    
    -- Replace ConRO's InvokeNextSpell
    ConRO.InvokeNextSpell = function(self)
        local oldSkill = self.Spell;
        local timeShift, currentSpell, gcd = ConRO:EndCast();
        local iterate = self:NextSpell(timeShift, currentSpell, gcd, self.PlayerTalents, self.PvPTalents);
        self.Spell = self.SuggestedSpells[1];
        ConRO:GetTimeToDie();
        
        local spellName, spellTexture;
        -- Get info for the first suggested spell
        if self.Spell then
            if type(self.Spell) == "string" then
                self.Spell = tonumber(self.Spell)
                spellName, _, _, _, _, _, _, _, _, spellTexture = GetItemInfo(self.Spell);
            else
                local spellInfo1 = C_Spell.GetSpellInfo(self.Spell);
                spellName = spellInfo1 and spellInfo1.name;
                spellTexture = spellInfo1 and spellInfo1.originalIconID;
            end
        end
        
        local spellTexture2;
        -- Get info for the second suggested spell, only if it exists
        if self.SuggestedSpells[2] then
            if type(self.SuggestedSpells[2]) == "string" then
                spell_2 = tonumber(self.SuggestedSpells[2])
                _, _, _, _, _, _, _, _, _, spellTexture2 = GetItemInfo(self.SuggestedSpells[2]);
            else
                local spellInfo2 = C_Spell.GetSpellInfo(self.SuggestedSpells[2]);
                spellTexture2 = spellInfo2 and spellInfo2.originalIconID;
            end
        end
        
        local spellTexture3;
        -- Get info for the third suggested spell, only if it exists
        if self.SuggestedSpells[3] then
            if type(self.SuggestedSpells[3]) == "string" then
                spell_3 = tonumber(self.SuggestedSpells[3])
                _, _, _, _, _, _, _, _, _, spellTexture3 = GetItemInfo(self.SuggestedSpells[3]);
            else
                local spellInfo3 = C_Spell.GetSpellInfo(self.SuggestedSpells[3]);
                spellTexture3 = spellInfo3 and spellInfo3.originalIconID;
            end
        end
        
        if (oldSkill ~= self.Spell or oldSkill == nil) and self.Spell ~= nil then
            self:GlowNextSpell(self.Spell);
            -- Process keybindings first, get the proper text -- ConsolePort support
            local keybindText1, _ = ConRO:ProcessKeybind(ConRO:improvedGetBindingText(ConRO:FindKeybinding(self.Spell)), ConROWindow.fontkey);
            local keybindText2, _ = ConRO:ProcessKeybind(ConRO:improvedGetBindingText(ConRO:FindKeybinding(self.SuggestedSpells[2])), ConROWindow2.fontkey);
            local keybindText3, _ = ConRO:ProcessKeybind(ConRO:improvedGetBindingText(ConRO:FindKeybinding(self.SuggestedSpells[3])), ConROWindow3.fontkey);
            
            -- Now set the text
            ConROWindow.fontkey:SetText(keybindText1);
            ConROWindow2.fontkey:SetText(keybindText2);
            ConROWindow3.fontkey:SetText(keybindText3);
            
            if spellName ~= nil then
                ConROWindow.texture:SetTexture(spellTexture);
                ConROWindow.font:SetText(spellName);
                ConROWindow2.texture:SetTexture(spellTexture2);
                ConROWindow3.texture:SetTexture(spellTexture3);
            else
                local itemName, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(self.Spell);
                local _, _, _, _, _, _, _, _, _, itemTexture2 = GetItemInfo(self.SuggestedSpells[2]);
                local _, _, _, _, _, _, _, _, _, itemTexture3 = GetItemInfo(self.SuggestedSpells[3]);
                ConROWindow.texture:SetTexture(itemTexture);
                ConROWindow.font:SetText(itemName);
                ConROWindow2.texture:SetTexture(itemTexture2);
                ConROWindow3.texture:SetTexture(itemTexture3);
            end
        end
        
        if self.Spell == nil and oldSkill ~= nil then
            self:GlowClear();
            ConROWindow.texture:SetTexture('Interface\\AddOns\\ConRO\\images\\Bigskull');
            ConROWindow.font:SetText(" ");
            ConROWindow.fontkey:SetText(" ");
            -- Reset the position to default
            ConROWindow.fontkey:ClearAllPoints();
            ConROWindow.fontkey:SetPoint('TOPRIGHT', ConROWindow, 'TOPRIGHT', 3, -2);
            
            ConROWindow2.texture:SetTexture('Interface\\AddOns\\ConRO\\images\\Bigskull');
            ConROWindow2.fontkey:SetText(" ");
            -- Reset the position to default
            ConROWindow2.fontkey:ClearAllPoints();
            ConROWindow2.fontkey:SetPoint('TOPRIGHT', ConROWindow2, 'TOPRIGHT', 3, -2);
            
            ConROWindow3.texture:SetTexture('Interface\\AddOns\\ConRO\\images\\Bigskull');
            ConROWindow3.fontkey:SetText(" ");
            -- Reset the position to default
            ConROWindow3.fontkey:ClearAllPoints();
            ConROWindow3.fontkey:SetPoint('TOPRIGHT', ConROWindow3, 'TOPRIGHT', 3, -2);
        end
    end
    
    -- Replace ConRO's InvokeNextDef
    ConRO.InvokeNextDef = function(self)
        local oldSkill = self.Def;
        local timeShift, currentSpell, gcd = ConRO:EndCast();
        local iterateDef = self:NextDef(timeShift, currentSpell, gcd, self.PlayerTalents, self.PvPTalents);
        self.Def = self.SuggestedDefSpells[1];
        local spellName, spellTexture;
        if self.Def then
            local spellInfo = C_Spell.GetSpellInfo(self.Def);
            if spellInfo then
                spellName = spellInfo.name;
                spellTexture = spellInfo.originalIconID;
            end
        end
        local color = ConRO.db.profile._Defense_Overlay_Color;
        if (oldSkill ~= self.Def or oldSkill == nil) and self.Def ~= nil then
            self:GlowNextDef(self.Def);
            ConRODefenseWindow.texture:SetVertexColor(1, 1, 1);
            -- Process keybindings first, get the proper text -- ConsolePort support
            local keybindText, _ = ConRO:ProcessKeybind(ConRO:improvedGetBindingText(ConRO:FindKeybinding(self.Def)), ConRODefenseWindow.fontkey);
            -- Now set the text
            ConRODefenseWindow.fontkey:SetText(keybindText);
            if spellName ~= nil then
                ConRODefenseWindow.texture:SetTexture(spellTexture);
                ConRODefenseWindow.font:SetText(spellName);
            else
                local itemName, _, _, _, _, _, _, _, _, itemTexture = GetItemInfo(self.Def);
                ConRODefenseWindow.texture:SetTexture(itemTexture);
                ConRODefenseWindow.font:SetText(itemName);
            end
        end
        if self.Def == nil and oldSkill ~= nil then
            self:GlowClearDef();
            ConRODefenseWindow.texture:SetTexture('Interface\\AddOns\\ConRO\\images\\shield2');
            ConRODefenseWindow.texture:SetVertexColor(color.r, color.g, color.b);
            ConRODefenseWindow.font:SetText(" ");
            ConRODefenseWindow.fontkey:SetText(" ");
            -- Reset the position to default
            ConRODefenseWindow.fontkey:ClearAllPoints();
            ConRODefenseWindow.fontkey:SetPoint('TOPRIGHT', ConRODefenseWindow, 'TOPRIGHT', 3, -2);
        end
    end
    
    -- Add and replace other ConRO functions
    function ConRO:ProcessKeybind(keybind, display)
        if not keybind then return "", false end
        
        local isConsolePortBinding = false
        
        if ConsolePort and ConROConsolePortSupport.db.profile.enableConsolePort then
            local zoom = ConROConsolePortSupport.db.profile.consolePortZoom or 1.0
            local baseSize = 32
            local scaledSize = math.floor(baseSize * zoom)
            
            -- Use ConsolePort API to get binding texture
            if ConsolePort.GetBindingTextureWithSize then
                keybind = ConsolePort:GetBindingTextureWithSize(keybind, scaledSize) or keybind
            end
            
            isConsolePortBinding = true
            
            -- Update the fontkey if it exists
            if display then
                display:ClearAllPoints()
                display:SetPoint('BOTTOM', display:GetParent(), 'BOTTOM', 0, -4 * zoom)
                display:SetScale(zoom)
            end
        elseif display then
            -- Reset to original position for regular keybinds
            display:ClearAllPoints()
            display:SetPoint('TOPRIGHT', display:GetParent(), 'TOPRIGHT', 3, -2)
            display:SetScale(1.0)
        end
        
        return keybind, isConsolePortBinding
    end

    function ConRO:DamageGlow(button, type)
        if self.Spell == nil then
            -- Hide any existing overlay
            if damageOverlay then
                damageOverlay:Hide()
            end
            return
        end
        
        -- Call the original function to create the overlay if needed
        if not damageOverlay then
            originalDamageGlow(self, button, type)
            -- Find and store the overlay for future use
            damageOverlay = _G["ConRO_DamageOverlay_next"]
        end
        
        -- If this is a ConsolePort button, adjust the overlay
        if button and button:GetName() and button:GetName():match("^CPB_") and damageOverlay then
            if not ConROConsolePortSupport.db.profile.overlayMainbutton then
                local isFlyoutButton = button:GetName():match("SHIFT") or button:GetName():match("CTRL")
                -- If it's a flyout button, make sure it's visible and notify CP
                if isFlyoutButton then
                    -- Force show the button
                    --button:Show()
                    
                    -- If the button has the OnOverlayGlow method from ConsolePort, use it
                    if button.OnOverlayGlow then
                        button:OnOverlayGlow(true)
                    end
                    
                    -- This sets a flag that might be used by ConsolePort's alpha management
                    if button.UpdateAlpha and button.AlphaState and button.AlphaState.OverlayActive then
                        button:UpdateAlpha(button.AlphaState.OverlayActive, true)
                    end
                end
            end
            local glowOverlay = damageOverlay.GlowDamageOverlay
            
            -- Set appropriate strata and level
            damageOverlay:SetFrameStrata("MEDIUM")
            
            local buttonLevel = button:GetFrameLevel()
            damageOverlay:SetFrameLevel(buttonLevel + 1)
            
            -- Adjust the glow child
            if glowOverlay then
                glowOverlay:SetFrameStrata("MEDIUM")
                glowOverlay:SetFrameLevel(buttonLevel)
            end
            
            -- Position correctly
            damageOverlay:ClearAllPoints()
            damageOverlay:SetAllPoints(button)
            
            -- Now adjust to make it larger while keeping it centered
            local buttonWidth = button:GetWidth()
            local buttonHeight = button:GetHeight()
            local extraSize = 8  -- 8 pixels larger on each side

            -- Clear points again before setting custom size
            damageOverlay:ClearAllPoints()
            damageOverlay:SetPoint("CENTER", button, "CENTER", 0, 0)
            damageOverlay:SetSize(buttonWidth + extraSize*2, buttonHeight + extraSize*2)
            
            -- Ensure it's visible
            damageOverlay:Show()
            
            -- Mark the spell as glowing
            self.SpellsGlowing[self.Spell] = 1
            
            -- Skip the original function since we handled it
            return
        end
        
        -- Not a ConsolePort button, use original function
        originalDamageGlow(self, button, type)
    end

    function ConRO:DefenseGlow(button, type)
        if self.Def == nil then
            -- Hide any existing overlay
            if defenseOverlay then
                defenseOverlay:Hide()
            end
            return
        end
        -- Call the original function to create the overlay if needed
        if not defenseOverlay then
            originalDefenseGlow(self, button, type)
            -- Find and store the overlay for future use
            defenseOverlay = _G["ConRO_DefenseOverlay_next"]
        end
        
        -- If this is a ConsolePort button, adjust the overlay
        if button and button:GetName() and button:GetName():match("^CPB_") and defenseOverlay then
            if not ConROConsolePortSupport.db.profile.overlayMainbutton then
                local isFlyoutButton = button:GetName():match("SHIFT") or button:GetName():match("CTRL")
                -- If it's a flyout button, make sure it's visible and notify CP
                if isFlyoutButton then
                    -- Force show the button
                    --button:Show()
                    
                    -- If the button has the OnOverlayGlow method from ConsolePort, use it
                    if button.OnOverlayGlow then
                        button:OnOverlayGlow(true)
                    end
                    
                    -- This sets a flag that might be used by ConsolePort's alpha management
                    if button.UpdateAlpha and button.AlphaState and button.AlphaState.OverlayActive then
                        button:UpdateAlpha(button.AlphaState.OverlayActive, true)
                    end
                end
            end
            local glowOverlay = defenseOverlay.GlowDefenseOverlay
            
            -- Set appropriate strata and level
            defenseOverlay:SetFrameStrata("MEDIUM")
            
            local buttonLevel = button:GetFrameLevel()
            defenseOverlay:SetFrameLevel(buttonLevel + 1)
            
            -- Adjust the glow child
            if glowOverlay then
                glowOverlay:SetFrameStrata("MEDIUM")
                glowOverlay:SetFrameLevel(buttonLevel)
            end
            
            -- Position correctly
            defenseOverlay:ClearAllPoints()
            defenseOverlay:SetAllPoints(button)
            -- Now adjust to make it larger while keeping it centered
            local buttonWidth = button:GetWidth()
            local buttonHeight = button:GetHeight()
            local extraSize = 8  -- 8 pixels larger on each side

            -- Clear points again before setting custom size
            defenseOverlay:ClearAllPoints()
            defenseOverlay:SetPoint("CENTER", button, "CENTER", 0, 0)
            defenseOverlay:SetSize(buttonWidth + extraSize*2, buttonHeight + extraSize*2)
            -- Ensure it's visible
            defenseOverlay:Show()
            
            -- Set the button as glowing in ConRO's tracking
            self.DefGlowing[self.Def] = 1
            
            -- Skip the original function since we handled it
            return
        end
        
        -- Not a ConsolePort button, use original function
        originalDefenseGlow(self, button, type)
    end
    function ConRO:GlowSpell(spellID)
        local spellName;
        local spellInfo = C_Spell.GetSpellInfo(spellID);
        spellName = spellInfo and spellInfo.name
        local _IsSwapSpell = false;
        for k, swapSpellID in pairs(ConROSwapSpells) do
            if spellID == swapSpellID then
                _IsSwapSpell = true;
                break;
            end
        end
        
        if ConsolePort and ConROConsolePortSupport.db.profile.enableConsolePort then
            local binding, cpButton = ConROConsolePortSupport:GetConsolePortBindingForAction(spellID)

            if cpButton then
                if not self.Spells[spellID] then
                    self.Spells[spellID] = {}
                else
                    wipe(self.Spells[spellID])
                end
                tinsert(self.Spells[spellID], cpButton)
                
                self:DamageGlow(cpButton, 'next');
                self.SpellsGlowing[spellID] = 1;
                return
            end
        end
        if self.Spells[spellID] ~= nil then
            for k, button in pairs(self.Spells[spellID]) do
                self:DamageGlow(button, 'next');
            end
            self.SpellsGlowing[spellID] = 1;
        else
            if UnitAffectingCombat('player') and not _IsSwapSpell then
                if spellName ~= nil then
                    self:Print(self.Colors.Error .. 'Spell not found on action bars: ' .. ' ' .. spellName .. ' ' .. '(' .. spellID .. ')');
                else
                    local itemName = GetItemInfo(spellID);
                    if itemName ~= nil then
                        self:Print(self.Colors.Error .. 'Item not found on action bars: ' .. ' ' .. itemName .. ' ' .. '(' .. spellID .. ')');
                    end
                end
            end
            ConRO:ButtonFetch();
        end
    end
    
    function ConRO:GlowDef(spellID)
        local spellName;
        local spellInfo = C_Spell.GetSpellInfo(spellID);
        spellName = spellInfo and spellInfo.name
        local _IsSwapSpell = false;
        for k, swapSpellID in pairs(ConROSwapSpells) do
            if spellID == swapSpellID then
                _IsSwapSpell = true;
                break;
            end
        end
        
        if ConsolePort and ConROConsolePortSupport.db.profile.enableConsolePort then
            local binding, cpButton = ConROConsolePortSupport:GetConsolePortBindingForAction(spellID)
            
            if cpButton then
                if not self.DefSpells[spellID] then
                    self.DefSpells[spellID] = {}
                else
                    wipe(self.DefSpells[spellID])
                end
                tinsert(self.DefSpells[spellID], cpButton)
                
                self:DefenseGlow(cpButton, 'next');
                self.DefGlowing[spellID] = 1;
                return
            end
        end
        if self.DefSpells[spellID] ~= nil then
            for k, button in pairs(self.DefSpells[spellID]) do
                self:DefenseGlow(button, 'next');
            end
            self.DefGlowing[spellID] = 1;
        else
            if UnitAffectingCombat('player') and not _IsSwapSpell then
                if spellName ~= nil then
                    self:Print(self.Colors.Error .. 'Spell not found on action bars: ' .. ' ' .. spellName .. ' ' .. '(' .. spellID .. ')');
                else
                    local itemName = GetItemInfo(spellID);
                    if itemName ~= nil then
                        self:Print(self.Colors.Error .. 'Item not found on action bars: ' .. ' ' .. itemName .. ' ' .. '(' .. spellID .. ')');
                    end
                end
            end
            ConRO:ButtonFetch();
        end
    end

    function ConRO:HideDamageGlow(button, type)
        -- If this is a ConsolePort flyout button, handle visibility
        if button and button:GetName() and button:GetName():match("^CPB_") then
            local isFlyoutButton = button:GetName():match("SHIFT") or button:GetName():match("CTRL")
            if isFlyoutButton then
                -- If the button has the OnOverlayGlow method from ConsolePort, use it
                if button.OnOverlayGlow then
                    button:OnOverlayGlow(false)
                end
                
                -- This sets a flag that might be used by ConsolePort's alpha management
                if button.UpdateAlpha and button.AlphaState and button.AlphaState.OverlayActive then
                    button:UpdateAlpha(button.AlphaState.OverlayActive, false)
                end
                
                -- Let ConsolePort handle visibility management again
                -- If the button has an FadeOut method, use it
                if button.FadeOut then
                    button:FadeOut(0.25, button:GetAlpha())
                end
            end
        end
        
        -- Call original function
        return originalHideDamageGlow(self, button, type)
    end

    function ConRO:HideDefenseGlow(button, type)
        -- If this is a ConsolePort flyout button, handle visibility
        if button and button:GetName() and button:GetName():match("^CPB_") then
            local isFlyoutButton = button:GetName():match("SHIFT") or button:GetName():match("CTRL")
            if isFlyoutButton then
                -- If the button has the OnOverlayGlow method from ConsolePort, use it
                if button.OnOverlayGlow then
                    button:OnOverlayGlow(false)
                end
                
                -- This sets a flag that might be used by ConsolePort's alpha management
                if button.UpdateAlpha and button.AlphaState and button.AlphaState.OverlayActive then
                    button:UpdateAlpha(button.AlphaState.OverlayActive, false)
                end
            end
        end
        
        -- Call original function
        return originalHideDefenseGlow(self, button, type)
    end

    function ConRO:GlowClear()
        -- Make sure SpellsGlowing exists
        if not self.SpellsGlowing then
            self.SpellsGlowing = {}
            return
        end
        
        for spellID, v in pairs(self.SpellsGlowing) do
            if v == 1 then
                -- Make sure Spells exists and has the spellID entry
                if self.Spells and self.Spells[spellID] then
                    for k, button in pairs(self.Spells[spellID]) do
                        -- Check if this is a ConsolePort flyout button
                        if button:GetName() and button:GetName():match("^CPB_") then
                            local isFlyoutButton = button:GetName():match("SHIFT") or button:GetName():match("CTRL")
                            if isFlyoutButton then
                                -- Tell ConsolePort the overlay is gone
                                if button.OnOverlayGlow then
                                    button:OnOverlayGlow(false)
                                end
                                
                                -- Update alpha state
                                if button.UpdateAlpha and button.AlphaState and button.AlphaState.OverlayActive then
                                    button:UpdateAlpha(button.AlphaState.OverlayActive, false)
                                end
                            end
                        end
                        
                        -- Hide the glow with standard function
                        self:HideDamageGlow(button, 'next')
                    end
                end
                self.SpellsGlowing[spellID] = 0
            end
        end
    end

    function ConRO:GlowClearDef()
        -- Make sure DefGlowing exists
        if not self.DefGlowing then
            self.DefGlowing = {}
            return
        end
        
        for spellID, v in pairs(self.DefGlowing) do
            if v == 1 then
                -- Make sure DefSpells exists and has the spellID entry
                if self.DefSpells and self.DefSpells[spellID] then
                    for k, button in pairs(self.DefSpells[spellID]) do
                        -- Check if this is a ConsolePort flyout button
                        if button:GetName() and button:GetName():match("^CPB_") then
                            local isFlyoutButton = button:GetName():match("SHIFT") or button:GetName():match("CTRL")
                            if isFlyoutButton then
                                -- Tell ConsolePort the overlay is gone
                                if button.OnOverlayGlow then
                                    button:OnOverlayGlow(false)
                                end
                                
                                -- Update alpha state
                                if button.UpdateAlpha and button.AlphaState and button.AlphaState.OverlayActive then
                                    button:UpdateAlpha(button.AlphaState.OverlayActive, false)
                                end
                            end
                        end
                        
                        -- Hide the glow with standard function
                        self:HideDefenseGlow(button, 'nextdef')
                    end
                end
                self.DefGlowing[spellID] = 0
            end
        end
    end

    self:RegisterEvent("ACTIONBAR_SLOT_CHANGED", "OnActionBarChanged")
    -- Mark as hooked
    ConRO._hooked_by_consoleport = true
end

-- Function to update the icon positioning
function ConROConsolePortSupport:UpdateIconPositioning()
    if self.db.profile.enableConsolePort then
        -- When using ConsolePort icons, align to BOTTOM
        ConROWindow.fontkey:ClearAllPoints()
        ConROWindow.fontkey:SetPoint("BOTTOM", ConROWindow, "BOTTOM", 0, 0)
        
        ConROWindow2.fontkey:ClearAllPoints()
        ConROWindow2.fontkey:SetPoint("BOTTOM", ConROWindow2, "BOTTOM", 0, 0)
        
        ConROWindow3.fontkey:ClearAllPoints()
        ConROWindow3.fontkey:SetPoint("BOTTOM", ConROWindow3, "BOTTOM", 0, 0)
        
        ConRODefenseWindow.fontkey:ClearAllPoints()
        ConRODefenseWindow.fontkey:SetPoint("BOTTOM", ConRODefenseWindow, "BOTTOM", 0, 0)
    else
        -- When using normal keybinds, position at TOPRIGHT
        ConROWindow.fontkey:ClearAllPoints()
        ConROWindow.fontkey:SetPoint("TOPRIGHT", ConROWindow, "TOPRIGHT", 3, -2)
        
        ConROWindow2.fontkey:ClearAllPoints()
        ConROWindow2.fontkey:SetPoint("TOPRIGHT", ConROWindow2, "TOPRIGHT", 3, -2)
        
        ConROWindow3.fontkey:ClearAllPoints()
        ConROWindow3.fontkey:SetPoint("TOPRIGHT", ConROWindow3, "TOPRIGHT", 3, -2)
        
        ConRODefenseWindow.fontkey:ClearAllPoints()
        ConRODefenseWindow.fontkey:SetPoint("TOPRIGHT", ConRODefenseWindow, "TOPRIGHT", 3, -2)
    end
end

-- Get ConsolePort binding for an action
function ConROConsolePortSupport:GetConsolePortBindingForAction(spellID)
    if not ConsolePort then return nil end
    if not spellID then return nil end
    
    CPButtonsCache[spellID] = nil
    
    local binding = nil
    local button = nil
    
    -- Try to find the action ID for this spell
    for i = 1, 180 do
        local actionType, id = GetActionInfo(i)
        if (actionType == "spell" and id == spellID) or 
           (actionType == "macro" and GetMacroSpell(id) == spellID) then
            
            local actionBinding = ConsolePort:GetActionBinding(i)
            local key, mod = ConsolePort:GetCurrentBindingOwner(actionBinding)
            
            if key then
                binding = ConsolePort:GetFormattedButtonCombination(key, mod)
                
                if binding and binding ~= "" then
                    local mainButtonName = "CPB_" .. key
                    local mainButton = _G[mainButtonName]

                    if mod and mod ~= "" and not self.db.profile.overlayMainbutton then
                        local modString = self:transformString(mod)
                        local modButtonName = mainButtonName .. "_" .. modString
                        local modButton = _G[modButtonName]
                        
                        if modButton then
                            button = modButton
                            -- print("Using modifier button:", modButtonName)
                        else
                            button = mainButton
                            -- print("Modifier button not found, using main button:", mainButtonName)
                        end
                    else
                        button = mainButton
                        -- print("Using main button:", mainButtonName)
                    end
                    
                    if button then
                        -- Cache the result
                        CPButtonsCache[spellID] = {
                            binding = binding,
                            button = button
                        }
                        
                        return binding, button
                    end
                end
            end
        end
    end
    
    return nil, nil
end

function ConROConsolePortSupport:transformString(str)
    -- Check if the string is nil or empty
    if not str or str == "" then
        return str
    end
    
    -- Remove the last hyphen if the string ends with one
    if str:sub(-1) == "-" then
        str = str:sub(1, -2)
    end
    
    -- Replace any remaining hyphens with underscores
    str = str:gsub("-", "_")
    
    return str
end

-- Clear ConsolePort cache
function ConROConsolePortSupport:ClearConsolePortCache()
    --print("Clearing ConsolePort button cache...")
    wipe(CPButtonsCache)
    
    if ConRO then
        -- Clear ConRO's spell tracking
        if ConRO.SpellsGlowing then
            wipe(ConRO.SpellsGlowing)
        end
        
        if ConRO.DefGlowing then
            wipe(ConRO.DefGlowing)
        end
        
        -- Clear any active glows
        ConRO:GlowClear()
        ConRO:GlowClearDef()
        ConRO:Fetch()
        ConRO:FetchDef()
    end
end

-- Set up options panel
function ConROConsolePortSupport:SetupOptions()
    -- Ensure we have access to the Ace libraries
    local AceConfig = LibStub("AceConfig-3.0")
    local AceConfigDialog = LibStub("AceConfigDialog-3.0")
    
    if not AceConfig or not AceConfigDialog then
        print("Could not find required Ace3 libraries")
        return false
    end
    
    -- Get addon version
    local version = "1.0"
    if C_AddOns and C_AddOns.GetAddOnMetadata then
        version = C_AddOns.GetAddOnMetadata('ConRO_ConsolePort_by_Lith', "Version") or version
    elseif GetAddOnMetadata then
        version = GetAddOnMetadata('ConRO_ConsolePort_by_Lith', "Version") or version
    end
    
    -- Define options table
    local options = {
        name = "-= |cffFFFFFFConRO|r ConsolePort support by |cFF8000FFLith|r =-",
        type = "group",
        args = {
            versionPull = {
                order = 1,
                type = "description",
                width = "normal",
                name = "Version: " .. version,
            },
            spacer2 = {
                order = 2,
                type = "description",
                width = "normal",
                name = "\n\n",
            },
            authorPull = {
                order = 3,
                type = "description",
                width = "normal",
                name = "Author: |cFF8000FFLith|r",
            },
            spacer10 = {
                order = 10,
                type = "description",
                width = "full",
                name = "\n\n",
            },
            header = {
                type = "header",
                name = "ConsolePort Integration Options",
                order = 20,
            },
            spacer22 = {
                order = 22,
                type = "description",
                width = "full",
                name = "\n",
            },
            description = {
                type = "description",
                name = "Configure how ConRO interacts with ConsolePort controller bindings",
                order = 24,
                fontSize = "medium",
            },
            enableConsolePort = {
                name = "Use ConsolePort Button Icons",
                desc = "Display ConsolePort button icons instead of keyboard keybinds",
                type = "toggle",
                width = 1.5,
                order = 26,
                disabled = function() return not ConsolePort end,
                set = function(info, val)
                    self.db.profile.enableConsolePort = val
                    self:UpdateIconPositioning()
                    self:ClearConsolePortCache()
                    ConRO:Fetch()
                    ConRO:FetchDef()
                end,
                get = function(info) return self.db.profile.enableConsolePort end
            },
            consolePortZoom = {
                name = "ConsolePort Icon Zoom",
                desc = "Adjust the zoom level of ConsolePort button icons",
                type = "range",
                width = 1.5,
                order = 27,
                min = 0.6,
                max = 2.0,
                step = 0.1,
                disabled = function() return not ConsolePort or not self.db.profile.enableConsolePort end,
                set = function(info, val)
                    self.db.profile.consolePortZoom = val
                    self:ClearConsolePortCache()
                    ConRO:Fetch()
                    ConRO:FetchDef()
                end,
                get = function(info) return self.db.profile.consolePortZoom or 1.0 end
            },
            overlayMainbutton = {
                name = "Show overlay on main button only",
                desc = "If checked the ConRO overlay is put on the main button, else it is displayed on the small alternative buttons if shift or ctrl is needed for the keybind.",
                type = "toggle",
                width = 3,
                order = 28,
                disabled = function() return not ConsolePort end,
                set = function(info, val)
                    -- Store the old value for comparison
                    --local oldVal = self.db.profile.overlayMainbutton
                    
                    -- Set the new value
                    self.db.profile.overlayMainbutton = val
                    
                    -- Print debug info
                    --print("ConRO ConsolePort: Changing overlayMainbutton from", oldVal, "to", val)
                    
                    -- ALWAYS do these steps when changing the option:
                    
                    -- First, clear all existing glows
                    if ConRO then
                        ConRO:GlowClear()
                        ConRO:GlowClearDef()
                    end
                    
                    -- Completely clear the cache
                    self:ClearConsolePortCache()
                    --[[
                    -- Force a complete ButtonFetch to rebuild all button references
                    if ConRO then
                        -- Clear ALL button assignments
                        for spellID, _ in pairs(ConRO.Spells or {}) do
                            wipe(ConRO.Spells[spellID])
                        end
                        
                        for spellID, _ in pairs(ConRO.DefSpells or {}) do
                            wipe(ConRO.DefSpells[spellID])
                        end
                        
                        -- Re-fetch all buttons
                        ConRO:ButtonFetch()
                        
                        -- Refresh displays
                        ConRO:Fetch()
                        ConRO:FetchDef()
                    end
                    ]]
                    -- Print confirmation
                    --print("ConRO ConsolePort: Overlay button preference updated to:", val and "Main buttons" or "Modifier buttons")
                end,
                get = function(info) return self.db.profile.overlayMainbutton end
            },
        }
    }
    
    -- Register the options with AceConfig
    LibStub("AceConfig-3.0"):RegisterOptionsTable("ConRO_ConsolePort", options)
    LibStub("AceConfigDialog-3.0"):AddToBlizOptions("ConRO_ConsolePort", "ConsolePort", "ConRO")
    
    return true
end
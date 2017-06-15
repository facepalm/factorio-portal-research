local Gui = {}

local buttonDefs = {
  { name="portal-research", sprite = "item/medium-portal" },
  { name="emergency-home", sprite = "portal-research.site-type-home" }
}

local tabDefs = {
  { name="orbitals", sprite = "item/satellite" },
  { name="sites", sprite = "portal-research.site-type-very-large-asteroid" },
  { name="portals", sprite = "item/medium-portal" },
  { name="power", sprite = "item/microwave-antenna" },
}

function Gui.initForPlayer(player)

  -- XXX: Cleanup old buttons
  local button_flow = mod_gui.get_button_flow(player)
  if button_flow["portal-research-gui-button"] then
    button_flow["portal-research-gui-button"].destroy()
  end
  if button_flow["portal-research-emergency-home-button"] then
    button_flow["portal-research-emergency-home-button"].destroy()
  end
  -- XXX: End

  local playerData = getPlayerData(player)
  playerData.buttons = playerData.buttons or {}
  playerData.window_buttons = playerData.window_buttons or {}

  local flow = button_flow["portal-research-buttons"] or button_flow.add {
    type="flow",
    name="portal-research-buttons"
  }

  for i,buttonDef in pairs(buttonDefs) do
    if playerData.buttons[buttonDef.name] ~= nil then
      playerData.buttons[buttonDef.name].button.destroy()
    end
    buttonDef.button = button_flow.add {
      type = buttonDef.sprite and "sprite-button" or "button",
      name = buttonDef.name .. "-button",
      sprite = buttonDef.sprite,
      style = mod_gui.button_style,
      caption = buttonDef.sprite == nil and {"gui-portal-research." .. buttonDef.name .. "-button-caption"} or nil,
      tooltip = {"gui-portal-research." .. buttonDef.name .. "-button-tooltip"}
    }
    playerData.buttons[buttonDef.button.name] = buttonDef
  end

  -- TODO: Don't necessarily destroy every init - just refresh open windows
  local frame_flow = mod_gui.get_frame_flow(player)
  if frame_flow.portal_research_gui then
    frame_flow.portal_research_gui.destroy()
  end

  playerData.gui = frame_flow.add{type="flow", name="portal_research_gui_flow", direction="horizontal"}
  playerData.gui.add{name="tabs", type="frame", direction="vertical"}
  playerData.gui.tabs.style.visible = false
  --playerData.gui.tabs.add{name="flow", type="flow"}

  playerData.tabs = playerData.tabs or {}
  for i,tabDef in pairs(tabDefs) do
    tabDef.tab = playerData.gui.tabs.add { -- playerData.gui.tabs.flow.add {
      type = "sprite-button",
      name = tabDef.name .. "-tab",
      sprite = tabDef.sprite,
      style = mod_gui.button_style,
      tooltip = {"gui-portal-research." .. tabDef.name .. "-tab-tooltip"}
    }
    playerData.tabs[tabDef.tab.name] = tabDef
  end

  playerData.windows = {}
  local windows = { "primary-tab", "object-detail", "secondary-pane", "hover-detail" }
  for i,windowName in pairs(windows) do
    local window = {
      frame = playerData.gui.add{name=windowName, type="frame", direction="vertical"}
    }
    window.frame.style.visible = false
    window.scroll = window.frame.add{name="scroll", type="scroll-pane", direction="vertical"}
    window.scroll.horizontal_scroll_policy = "never"
    window.scroll.vertical_scroll_policy = "auto"
    window.scroll.style.maximal_height = 500
    window.scroll.style.bottom_padding = 9

    playerData.windows[windowName] = window
  end

  Gui.updateForPlayer(player)
end

function Gui.updateForPlayer(player)
  -- TODO: Only show buttons as appropriate for player entities / tech level
  local playerData = getPlayerData(player)

  -- Emergency home button needs to show whenever not on Nauvis (at least by teleportation). Some of these surfaces
  -- could be from other mods (e.g. Factorissimo) and since we have no idea how these are created
  -- and interlinked there are all kinds of ways players could make broken situations and not be able to get home!
  playerData.buttons["emergency-home-button"].button.style.visible = (player.surface.name ~= "nauvis")
end

local function spriteNameForSite(site)
  local sprite = "unknown"
  if site.is_offworld then
    local size = Sites.getSize(site.size)
    sprite = size.name .. "-asteroid" -- TODO: Comets
  end
  if site.surface and site.surface.name == "nauvis" then
    sprite = "home"
  end
  return "portal-research.site-type-" .. sprite
end

local function openWindow(player, options)
  -- TODO: Clean up existing frame data
  local playerData = getPlayerData(player)
  local window = playerData.windows[options.window]
  window.frame.style.visible = true
  window.frame.caption = options.caption
  window.scroll.clear()
  return window.scroll
end

local function closeWindow(player, options)
  local playerData = getPlayerData(player)
  local frame = playerData.gui[options.window]
  frame.style.visible = false
  cleanUpButtons(player)
  -- TODO: Actually delete gui, cancel ticks
  -- TODO: Also nilify playerData.current_tab if window was primary-tab
end

local function createButton(player, gui_parent, options)
  local playerData = getPlayerData(player)
  local element = gui_parent.add{
    type = (options.sprite and "sprite-button" or "button"),
    name = options.name, -- TODO: Concatenate window name as well?
    caption = (not options.sprite and options.caption or nil)
  }

  -- TODO: Should display a warning if conflicting with an existing button id?
  playerData.window_buttons[options.name] = options
  options.element = element
end

local function cleanUpButtons(player)
  local playerData = getPlayerData(player)
  for i,button in pairs(playerData.window_buttons) do
    if not button.element.valid then
      playerData.window_buttons[i] = nil
    end
  end
  -- TODO: Cleanup could be specific to the window that's been closed/changed,
  -- however unless I see severe performance problems this is simple enough right now
end

local function buildNameEditor(player, gui, object, window_options)
end

local function siteMiniDetails(player, site, parent)
  local flow = parent.add{type="flow", direction="vertical"}
  local line1 = flow.add{type="flow", direction="horizontal"}
  local line2 = flow.add{type="flow", direction="horizontal"}
  local line3 = flow.add{type="flow", direction="horizontal"}

  local spriteName = spriteNameForSite(site)
  line1.add{type="sprite",sprite=spriteName,tooltip={spriteName}}
  line1.add{type="label",caption=site.custom_name or site.name}
  if site.resources then
    local tooltip = "portal-research.resource-quantity" .. (site.resources_estimated and "-estimated" or "")
    for i,resource in pairs(site.resources) do
      -- TODO: Display friendly numbers on button
      line2.add{
        type="sprite",
        sprite="entity/" .. resource.resource.name,
        tooltip={tooltip, {"entity-name." .. resource.resource.name}, resource.amount}
      }
    end
  end
end

local function buildSitesList(player, root, options)
  local options = options or {}
  for site in Sites.list(player.force) do
    local row = root.add{type="flow",direction="horizontal"}
    siteMiniDetails(player, site, row)
    -- Add buttons for 
    local name_base = "-" .. site.name .. "-button"
    --createButton(player, row, {name="site-details" .. name_base,caption="view-button-caption",action={name="site-details",site=site}, windowTarget)
  end
end

function Gui.showSiteDetails(player, site)
  local flow = mod_gui.get_frame_flow(player)

  local detailsFrame = flow.add{type="frame", name="portal-site-details", caption={"site-details-caption", site.name}}
  local detailsFlow = detailsFrame.add{type="scroll-pane", direction="vertical"}
  detailsFlow.horizontal_scroll_policy = "never"
  detailsFlow.vertical_scroll_policy = "auto"
  local detailsTable = detailsFlow.add{type="table", colspan="2"}
  local function addDetailRow(label, value)
    --local detailRow = detailsTable.add{type="flow", direction="horizontal"}
    detailsTable.add{type="label", caption={"site-details-label-"..label}}
    detailsTable.add{type="label", caption=value}
  end

  addDetailRow("name", site.name)
  addDetailRow("size", {"site-size-" .. Sites.getSize(site.size).name})
  addDetailRow("distance", site.distance)

  detailsFlow.add{type="label", caption={"estimated-resources-label"}}

  if #site.resources == 0 then
    detailsFlow.add{type="label", caption={"estimated-resources-none"}}
  else
    local resourceTable = detailsFlow.add{type="table", colspan="2"}

    for i,estimate in pairs(site.resources) do
      resourceTable.add{type="label", caption={"entity-name."..estimate.resource.name}}
      resourceTable.add{type="label", caption=estimate.amount}
    end
  end

  detailsFlow.add{type="button", name="close-site-details-button", caption={"close-dialog-caption"}}
end

local function pickPortalTargets(player, portal)
  local window_options = {
    window="secondary-pane",
    caption={"gui-portal-research.portal-target-select-caption." .. portal.entity.name},
    object=portal
  }
  local gui = openWindow(player, window_options)
  local playerData = getPlayerData(player)

  -- TODO: List resources on both types of button

  -- List sites that don't yet have a portal
  local allowLongRange = player.force.technologies["interplanetary-teleportation"]
    and player.force.technologies["interplanetary-teleportation"].researched

  -- TODO: However, for box portals do check they're close enough on the surface until interplanetary is unlocked
  -- TODO: Maybe shorter distances initially, go to 50 on long-range, go to infinite on interplanetary
  if portal.entity.name == "medium-portal" and allowLongRange then  
    for site in Sites.list(player.force) do
      if not site.surface_generated and site.has_portal then
        local row = gui.add{
          type="flow",
          direction="horizontal"
        }

        --local name_base = "-" .. site.name .. "-button"
        siteMiniDetails(player, site, row)
        -- TODO: sprite buttons instead of captions
        createButton(player, row, {
          name="view-site-details-" .. site.name,
          caption={"gui-portal-research.site-details-button-caption"},
          action={name="site-details",site=site},
          window="secondary-pane"
        })
        createButton(player, row, {
          name="portal-" .. portal.id .. "-pick-target-" .. site.name,
          caption={"gui-portal-research.pick-portal-button-caption"},
          action={name="pick-portal-target",portal=portal,target_site=site},
          window="secondary-pane"
        })
      end
    end
  end
  --[[
  -- List actual portals (of the same type and within range) that don't have a target
  for i,target in pairs(global.portals) do
    if portal.entity.name == target.entity.name and target.entity.force == player.force and portal ~= target and target.teleport_target == nil
      -- Note: It seems like long range shouldn't happen before lander is created,
      -- however we're also checking for different surfaces e.g. those created by Factorissimo
      and (allowLongRange or target.entity.surface == portal.entity.surface) then
      local buttonId = "portal-target-select-" .. target.entity.unit_number
      local newButton = targetsFlow.add{
        type="button",
        name=buttonId,
        caption=target.site.name -- And an additional identifier :(
      }
      playerData.guiPortalTargetButtons[newButton.name] = {portal=target}
    end
  end
  ]]
  -- TODO: X close buttons
  --targetsFlow.add{type="button", name="cancel-portal-target-select", caption={"cancel-dialog-caption"}}
end

-- TODO: Too much of this is in Gui rather than Portals
-- TODO: Close GUI when running away from portal.
function Gui.showPortalDetails(player, portal)
  local playerData = getPlayerData(player)
  -- TODO: Check this doesn't get executed too much when walking through a portal
  local window_options = {
    window="object-detail",
    caption={"gui-portal-research.portal-details-caption"},
    object=portal
  }
  local gui = openWindow(player, window_options)

  local playerData = getPlayerData(player)
  -- TODO: Handle this in the openWindow stuff?
  playerData.current_detail_object = portal

  buildNameEditor(player, gui, window_options)

  local preview_size = 200
  -- TODO: Add a function to build a "standard" camera widget with map toggle and zoom support
  local camera = gui.add{
    type="camera",
    position=portal.entity.position,
    surface_index = portal.entity.surface.index,
    zoom = 1
  }
  camera.style.minimal_width = preview_size
  camera.style.minimal_height = preview_size

  gui.add{type="label", caption={"portal-research.portal-target-heading"}}
  if portal.teleport_target then
    local site = getSiteForEntity(portal.teleport_target)
    gui.add{type="label", caption=site.name}
    local target_camera = gui.add{
      type="camera",
      position=portal.teleport_target.entity.position,
      surface_index = portal.teleport_target.entity.surface.index,
      zoom = 1
    }
    target_camera.style.minimal_width = preview_size
    target_camera.style.minimal_height = preview_size
  else
    gui.add{type="label", caption={"portal-research.no-target-portal"}}
    pickPortalTargets(player, portal)
  end
end

local function onGuiClick(event)
  local player = game.players[event.element.player_index]
  local playerData = getPlayerData(player)
  local name = event.element.name
  if name == "portal-research-button" then
    playerData.gui.style.visible = not playerData.gui.style.visible
    return
  end
  if name == "emergency-home-button" then
    Portals.emergencyHomeTeleport(player)
    return
  end

  if playerData.tabs[name] and playerData.tabs[name].tab == event.element then
    local clicked_tab = playerData.tabs[name]
    local options = {
      window="primary-tab",
      caption={"gui-portal-research."..clicked_tab.name.."-tab-caption"}
    }
    if playerData.current_tab == clicked_tab then
      closeWindow(player, options)
      playerData.current_tab = nil
    else
      local gui = openWindow(player, options)
      if clicked_tab.name == "sites" then
        buildSitesList(player, gui, options)
      end
      playerData.current_tab = clicked_tab
    end
    return
  end

  if playerData.window_buttons[name] then
    local button = playerData.window_buttons[name]
    -- TODO: Action handlers definitely need moving out of this
    -- function before it gets out of control
    if button.action.name == "site-details" then

    elseif button.action.name == "pick-portal-target" then
        -- action={name="pick-portal-target",portal=portal,target_site=site},

      local chosen = button.action.target_portal
      if button.action.target_site ~= nil then
        -- Generate the site now to establish a link to the portal entity
        chosen = Sites.generateSurface(chosen.site)
      end

      button.action.portal.teleport_target = chosen
      chosen.teleport_target = button.action.portal

      -- TODO: Allow this to be toggled in GUI (and even using circuits?) and leave GUI open...
      -- TODO: Allow naming things (soon). Open portal GUI on mouse hover.
      -- TODO: (Much later) GUI can show connections diagrammatically
      if chosen.portal.entity.name == "portal-chest" then
        chosen.portal.is_sender = false
        chosen.portal.teleport_target.is_sender = true
      end

      -- Buffer size will need to change
      Portals.updateEnergyProperties(chosen)
      Portals.updateEnergyProperties(chosen.teleport_target)
      -- TODO: Window should be closed automagically by the below call to showPortalDetails
      -- but this doesn't work yet
      closeWindow(player, button.window)
      -- Refresh portal details
      Gui.showPortalDetails(player, button.action.portal)
      -- TODO: If other players had GUI open for the same portal, should update all their views
      -- Need better tracking of what models are shown in the windows and what their original render
      -- path was
    elseif button.action.name == "pick-orbital-target" then
      -- Send orbital to selected site
      -- TODO: Instant right now, need to introduce travel times
    end
  end
end
script.on_event(defines.events.on_gui_click, onGuiClick)

function onPlayerJoinedGame(event)
  local player = game.players[event.player_index]
  Gui.initForPlayer(player)
end
script.on_event(defines.events.on_player_joined_game, onPlayerJoinedGame)

-- TODO: Need to also remove GUI when player leaves?

return Gui
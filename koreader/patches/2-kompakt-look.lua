--[[
KOReader on the Mudita Kompakt, made to read like the phone's own apps.

A user patch: KOReader runs every file in koreader/patches/ at startup, so
nothing in KOReader itself is changed and it updates as usual. Delete this
file and everything it does is gone; it writes none of KOReader's settings.

What it does:
  - the interface in Lato, the typeface of the Kompakt's own apps, when
    Lato-Regular.ttf and Lato-Bold.ttf are in koreader/fonts/;
  - all interface type a size larger, for a 4.3" screen held at reading
    distance - menus, lists, dialogs, the status bar and the settings panel;
  - icons a size larger, in the menu bars, title bars and the settings panel;
  - taller rows in the top menu, so a thumb finds one;
  - lines and switches in black: KOReader draws them grey, and grey on this
    screen is dithered into a faint speckle;
  - dialogs with a firmer edge, taller buttons and black lines between them.

Book text is untouched: that stays whatever the reader chooses in the book.
]]

local Blitbuffer = require("ffi/blitbuffer")
local DataStorage = require("datastorage")
local Font = require("ui/font")
local lfs = require("libs/libkoreader-lfs")
local logger = require("logger")
local Screen = require("device").screen

-- How much larger interface type and icons are drawn.
local TYPE_SCALE = 1.15
local ICON_SIZE = 48 -- KOReader's is 40

-- Lato, if it has been put where KOReader looks for fonts.
local fontdir = DataStorage:getDataDir() .. "/fonts"
local function present(name)
    return lfs.attributes(fontdir .. "/" .. name, "mode") == "file"
end
-- Some widgets name Noto Sans by its path rather than by role (the status bar
-- under the page does); those are pointed at Lato too.
local by_path = {}
if present("Lato-Regular.ttf") and present("Lato-Bold.ttf") then
    by_path["./fonts/noto/NotoSans-Regular.ttf"] = fontdir .. "/Lato-Regular.ttf"
    by_path["./fonts/noto/NotoSans-Bold.ttf"] = fontdir .. "/Lato-Bold.ttf"
    local regular, bold = "Lato-Regular.ttf", "Lato-Bold.ttf"
    Font.bold_font_variant[regular] = bold
    Font.regular_font_variant[bold] = regular
    for role, file in pairs(Font.fontmap) do
        if file == "NotoSans-Regular.ttf" then
            Font.fontmap[role] = regular
        elseif file == "NotoSans-Bold.ttf" then
            Font.fontmap[role] = bold
        end
    end
else
    logger.warn("kompakt-look: Lato not found in", fontdir, "- keeping Noto Sans")
end

-- Every interface font is asked for through Font:getFace, either by role or
-- with a number, so scaling here reaches all of them at once, including the
-- many places that pass a number of their own.
--
-- The face remembers the size as it was asked for, not as drawn: some widgets
-- ask again with face.orig_size (to step a title down, or for a fallback
-- font), and without this they would be scaled a second time.
local getFace = Font.getFace
function Font:getFace(font, size, faceindex)
    font = by_path[font] or font
    local asked = size or self.sizemap[font or "cfont"] or self.sizemap.cfont
    local face = getFace(self, font, math.floor(asked * TYPE_SCALE + 0.5), faceindex)
    if face then face.orig_size = asked end
    return face
end

-- Icons: KOReader reads this default once, as each widget is loaded. It is
-- changed in memory only, never saved, and only if the reader has not set
-- one of their own.
if G_defaults.rw.DGENERIC_ICON_SIZE == nil then
    G_defaults.ro.DGENERIC_ICON_SIZE = ICON_SIZE
end

local Size = require("ui/size")

-- Dialogs and windows: a 2dp rim, like the phone's own dialogs.
Size.border.window = Screen:scaleBySize(2)

-- Top menu: taller rows, black dividers.
local TouchMenu = require("ui/widget/touchmenu")
TouchMenu.item_height = math.floor(Size.item.height_large * 1.2)
TouchMenu.split_color = Blitbuffer.COLOR_BLACK

-- Lists and the file browser: black row lines.
local Menu = require("ui/widget/menu")
Menu.line_color = Blitbuffer.COLOR_BLACK
local FileChooser = require("ui/widget/filechooser")
FileChooser.line_color = Blitbuffer.COLOR_BLACK

-- Switches (Two Columns, and the like): the chosen side filled black with
-- white type, and a black frame, instead of grey on grey.
local ToggleSwitch = require("ui/widget/toggleswitch")
ToggleSwitch.fgcolor = Blitbuffer.COLOR_BLACK
local toggleInit = ToggleSwitch.init
function ToggleSwitch:init(...)
    toggleInit(self, ...)
    if self.toggle_frame then
        self.toggle_frame.color = Blitbuffer.COLOR_BLACK
    end
end

-- Dialog buttons: taller, so each is an easier target, and the lines between
-- them black. ButtonTable draws those lines grey when it is built, so they
-- are found and recoloured just after.
Size.padding.buttontable = Screen:scaleBySize(8)
local ButtonTable = require("ui/widget/buttontable")
local function shade(color)
    local ok, value = pcall(function() return color.a end)
    return ok and value or nil
end
local GREY = shade(Blitbuffer.COLOR_GRAY)
local THIN = Screen:scaleBySize(4)
local function blackenLines(widget, depth)
    if type(widget) ~= "table" or depth > 6 then return end
    local d = widget.dimen
    if widget.background and d and (d.w <= THIN or d.h <= THIN)
            and shade(widget.background) == GREY then
        widget.background = Blitbuffer.COLOR_BLACK
    end
    for _, child in ipairs(widget) do
        blackenLines(child, depth + 1)
    end
end
local buttonTableInit = ButtonTable.init
function ButtonTable:init(...)
    buttonTableInit(self, ...)
    blackenLines(self.container, 0)
end

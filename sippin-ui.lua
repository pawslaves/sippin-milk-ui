-- ver 1.1.1

local sm = {}

local DEF_FONT = 16658246179
local DEF_LOGO = "https://r2.highpulse.lol/c61a71e36e7ad294ce3833de07de47a1e04e1f8f_full.jpg"
local DIR = "sippin-milk"
local LOGO_FILE = DIR .. "/logo.jpeg"
local CFG_DIR = DIR .. "/configs"
local CFG_FILE = CFG_DIR .. "/default.lua"
local LOAD_MIN = 1.15

local UIS = game:GetService("UserInputService")
local CG = game:GetService("CoreGui")

local pal = {
    bg = Color3.fromRGB(32, 29, 29),
    bg2 = Color3.fromRGB(48, 44, 44),
    bg3 = Color3.fromRGB(241, 238, 238),
    text = Color3.fromRGB(253, 252, 252),
    dim = Color3.fromRGB(154, 152, 152),
    mute = Color3.fromRGB(110, 110, 115),
    line = Color3.fromRGB(100, 98, 98),
    warm = Color3.fromRGB(15, 0, 0),
    blue = Color3.fromRGB(0, 122, 255),
    red = Color3.fromRGB(255, 59, 48),
    green = Color3.fromRGB(48, 209, 88),
    orange = Color3.fromRGB(255, 159, 10)
}

local function clamp(v, a, b)
    return math.max(a, math.min(b, v))
end

local function snap(v, s)
    if not s or s <= 0 then
        return v
    end
    return math.floor((v / s) + 0.5) * s
end

local function deep_copy(t)
    local n = {}
    for k, v in pairs(t or {}) do
        n[k] = v
    end
    return n
end

local function shift(c, k)
    return Color3.new(
        clamp(c.R * k, 0, 1),
        clamp(c.G * k, 0, 1),
        clamp(c.B * k, 0, 1)
    )
end

local function asset(v)
    if type(v) == "number" then
        return "rbxassetid://" .. v
    end
    if type(v) ~= "string" or v == "" then
        return nil
    end
    if v:match("^rbxassetid://") or v:match("^https?://") then
        return v
    end
    if tonumber(v) then
        return "rbxassetid://" .. v
    end
    return v
end

local function fn(name)
    local f
    if type(getgenv) == "function" then
        local ok, env = pcall(getgenv)
        if ok and type(env) == "table" then
            f = rawget(env, name)
        end
    end
    if type(f) ~= "function" and type(getfenv) == "function" then
        local ok, env = pcall(getfenv)
        if ok and type(env) == "table" then
            f = rawget(env, name)
        end
    end
    if type(f) ~= "function" and type(_G) == "table" then
        f = rawget(_G, name)
    end
    if type(f) ~= "function" and name == "request" and type(http) == "table" then
        f = http.request
    end
    return type(f) == "function" and f or nil
end

local function hasfn(name)
    return fn(name) ~= nil
end

local function ensure_dir()
    local isf = fn("isfolder")
    local mkf = fn("makefolder")
    if isf and mkf then
        local ok, exists = pcall(isf, DIR)
        if not ok or not exists then
            pcall(mkf, DIR)
        end
        local ok2, exists2 = pcall(isf, CFG_DIR)
        if not ok2 or not exists2 then
            pcall(mkf, CFG_DIR)
        end
    end
end

local function load_url(url)
    if type(url) ~= "string" or not url:match("^https?://") then
        return nil
    end
    local ok, data = pcall(function()
        if game.HttpGet then
            return game:HttpGet(url)
        end
    end)
    if ok and type(data) == "string" and #data > 0 then
        return data
    end
    for _, name in ipairs({ "request", "http_request", "syn.request" }) do
        local req
        if name == "syn.request" and type(syn) == "table" then
            req = syn.request
        else
            req = fn(name)
        end
        if req then
            local ok2, res = pcall(req, {
                Url = url,
                Method = "GET"
            })
            if ok2 then
                if type(res) == "table" and type(res.Body) == "string" and #res.Body > 0 then
                    return res.Body
                end
                if type(res) == "string" and #res > 0 then
                    return res
                end
            end
        end
    end
    return nil
end

local function logo_status(v)
    ensure_dir()
    local isf = fn("isfile")
    local custom = fn("getcustomasset")
    local write = fn("writefile")
    local exists = false
    if isf then
        local ok, res = pcall(isf, LOGO_FILE)
        exists = ok and res == true
    end
    if exists and custom then
        local ok, src = pcall(custom, LOGO_FILE)
        if ok and src then
            return src, "loaded " .. LOGO_FILE
        end
    end
    if type(v) == "string" and v:match("^https?://") then
        if not write then
            return asset(v), "writefile missing"
        end
        if not custom then
            return asset(v), "getcustomasset missing"
        end
        local data = load_url(v)
        if not data then
            return asset(v), "download failed"
        end
        local ok = pcall(write, LOGO_FILE, data)
        if not ok then
            return asset(v), "write failed"
        end
        local ok2, src = pcall(custom, LOGO_FILE)
        if ok2 and src then
            return src, "wrote " .. LOGO_FILE
        end
        return asset(v), "custom asset failed"
    end
    return asset(v), "asset fallback"
end

local function enc(v)
    local tv = type(v)
    if tv == "string" then
        return string.format("%q", v)
    end
    if tv == "number" or tv == "boolean" then
        return tostring(v)
    end
    return "nil"
end

local function cfg_name(v)
    v = tostring(v or "default"):gsub("%.lua$", "")
    v = v:gsub("[^%w_%-%s]", ""):gsub("%s+", "_")
    if v == "" then
        v = "default"
    end
    return v
end

local function cfg_path(v)
    return CFG_DIR .. "/" .. cfg_name(v) .. ".lua"
end

local function write_cfg(path, tbl)
    ensure_dir()
    local write = fn("writefile")
    if not write then
        return false
    end
    local out = { "return {" }
    for k, v in pairs(tbl or {}) do
        out[#out + 1] = "[" .. enc(k) .. "]=" .. enc(v) .. ","
    end
    out[#out + 1] = "}"
    return pcall(write, path, table.concat(out, "\n")) == true
end

local function list_cfg()
    ensure_dir()
    local listf = fn("listfiles")
    local out = {}
    if listf then
        local ok, files = pcall(listf, CFG_DIR)
        if ok and type(files) == "table" then
            for _, file in ipairs(files) do
                local s = tostring(file)
                local name = s:match("([^/\\]+)%.lua$")
                if name then
                    out[#out + 1] = name
                end
            end
        end
    end
    table.sort(out)
    if #out == 0 then
        out[1] = "default"
    end
    return out
end

local function read_cfg(name)
    local read = fn("readfile")
    if not read then
        return nil
    end
    local ok, src = pcall(read, cfg_path(name))
    if not ok or type(src) ~= "string" then
        return nil
    end
    local loadf = loadstring or load
    if not loadf then
        return nil
    end
    local ok2, chunk = pcall(loadf, src)
    if not ok2 or type(chunk) ~= "function" then
        return nil
    end
    local ok3, tbl = pcall(chunk)
    if ok3 and type(tbl) == "table" then
        return tbl
    end
    return nil
end

local function cfg_export(tbl)
    local out = {}
    for k, v in pairs(tbl or {}) do
        if k ~= "ui_config_name" and k ~= "ui_config_selected" then
            out[k] = v
        end
    end
    return out
end

local function cfg_import(tbl)
    local out = {}
    for k, v in pairs(tbl or {}) do
        if k ~= "ui_config_name" and k ~= "ui_config_selected" then
            out[k] = v
        end
    end
    return out
end

local function clip(text)
    local set = fn("setclipboard") or fn("toclipboard")
    if not set then
        return false
    end
    return pcall(set, tostring(text)) == true
end

local function mk(c, p)
    local o = Instance.new(c)
    for k, v in pairs(p or {}) do
        o[k] = v
    end
    return o
end

local function zset(o, z)
    pcall(function()
        o.ZIndex = z
    end)
    return o
end

local function corner(o, r)
    local u = mk("UICorner", {
        CornerRadius = UDim.new(0, r or 4)
    })
    u.Parent = o
    return u
end

local function stroke(o, color, tr, th)
    local s = mk("UIStroke", {
        Color = color or pal.warm,
        Transparency = tr == nil and 0.88 or tr,
        Thickness = th or 1
    })
    s.Parent = o
    return s
end

local function pad(o, l, t, r, b)
    local p = mk("UIPadding", {
        PaddingLeft = UDim.new(0, l or 0),
        PaddingTop = UDim.new(0, t or 0),
        PaddingRight = UDim.new(0, r or l or 0),
        PaddingBottom = UDim.new(0, b or t or 0)
    })
    p.Parent = o
    return p
end

local function list(o, gap)
    local l = mk("UIListLayout", {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, gap or 8)
    })
    l.Parent = o
    return l
end

local function maid()
    local m = { bag = {}, dead = false }

    function m:give(x)
        if x == nil then
            return x
        end
        self.bag[#self.bag + 1] = x
        return x
    end

    function m:clean()
        if self.dead then
            return
        end
        self.dead = true
        for i = #self.bag, 1, -1 do
            local x = self.bag[i]
            local tx = typeof(x)
            if tx == "RBXScriptConnection" then
                pcall(function()
                    x:Disconnect()
                end)
            elseif tx == "Instance" then
                pcall(function()
                    x:Destroy()
                end)
            elseif type(x) == "table" and x.Destroy then
                pcall(function()
                    x:Destroy()
                end)
            elseif type(x) == "function" then
                pcall(x)
            end
            self.bag[i] = nil
        end
    end

    function m:Destroy()
        self:clean()
    end

    return m
end

local function font_pick(fid, weight)
    weight = weight or Enum.FontWeight.Regular
    if fid and Font and Font.fromId then
        local ok, ff = pcall(Font.fromId, fid, weight, Enum.FontStyle.Normal)
        if ok and ff then
            return ff
        end
    end
    if Font and Font.fromName then
        for _, name in ipairs({ "RobotoMono", "BuilderMono" }) do
            local ok, ff = pcall(Font.fromName, name, weight, Enum.FontStyle.Normal)
            if ok and ff then
                return ff
            end
        end
    end
    if Font and Font.fromEnum then
        local enums = {}
        pcall(function()
            enums[#enums + 1] = Enum.Font.RobotoMono
        end)
        pcall(function()
            enums[#enums + 1] = Enum.Font.Code
        end)
        for _, en in ipairs(enums) do
            local ok, ff = pcall(Font.fromEnum, en)
            if ok and ff then
                if Font and Font.new then
                    local ok2, nf = pcall(Font.new, ff.Family, weight, Enum.FontStyle.Normal)
                    if ok2 and nf then
                        return nf
                    end
                end
                return ff
            end
        end
    end
    return nil
end

local function set_font(o, ctx, size, color, align, weight, yalign)
    o.TextSize = size or 14
    o.TextColor3 = color or pal.text
    o.TextXAlignment = align or Enum.TextXAlignment.Left
    o.TextYAlignment = yalign or Enum.TextYAlignment.Center
    pcall(function()
        o.RichText = false
    end)
    local ff = ctx:font(weight)
    local ok = false
    if ff then
        ok = pcall(function()
            o.FontFace = ff
        end)
    end
    if not ok then
        local set = pcall(function()
            o.Font = Enum.Font.RobotoMono
        end)
        if not set then
            o.Font = Enum.Font.Code
        end
    end
end

local function auto_canvas(scroller, lay, extra)
    local function sync()
        scroller.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + (extra or 0))
    end
    sync()
    return lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(sync)
end

local function new_store()
    local st = {
        vals = {},
        meta = {},
        refs = {}
    }

    function st:reg(flag, kind, def, cb, vr)
        if not flag then
            return def
        end
        if self.vals[flag] == nil then
            self.vals[flag] = def
        end
        self.meta[flag] = {
            kind = kind,
            cb = cb,
            vr = vr
        }
        return self.vals[flag]
    end

    function st:bind(flag, ref)
        if flag then
            self.refs[flag] = ref
        end
    end

    function st:drop(flag, ref)
        if flag and self.refs[flag] == ref then
            self.refs[flag] = nil
        end
    end

    function st:fix(flag, v)
        local m = self.meta[flag]
        if not m or not m.vr then
            return true, v
        end
        return m.vr(v)
    end

    function st:set(flag, v, silent, src)
        if not flag then
            return false
        end
        local ok, nv = self:fix(flag, v)
        if not ok then
            return false
        end
        self.vals[flag] = nv
        if src and src._pull then
            src:_pull(nv, true)
        end
        local ref = self.refs[flag]
        if ref and ref ~= src and ref._pull then
            ref:_pull(nv, true)
        end
        local m = self.meta[flag]
        if m and m.cb and not silent then
            m.cb(nv)
        end
        return true, nv
    end

    function st:get(flag)
        return self.vals[flag]
    end

    function st:export()
        return deep_copy(self.vals)
    end

    function st:import(tbl, silent)
        for k, v in pairs(tbl or {}) do
            self:set(k, v, silent)
        end
    end

    return st
end

local function hot(btn, base, hover, down)
    btn.AutoButtonColor = false
    local state = base
    btn.BackgroundColor3 = state
    local function paint(c)
        state = c
        btn.BackgroundColor3 = c
    end
    local m = maid()
    m:give(btn.MouseEnter:Connect(function()
        paint(hover or base)
    end))
    m:give(btn.MouseLeave:Connect(function()
        paint(base)
    end))
    m:give(btn.MouseButton1Down:Connect(function()
        paint(down or hover or base)
    end))
    m:give(btn.MouseButton1Up:Connect(function()
        if btn:IsDescendantOf(game) then
            paint(hover or base)
        end
    end))
    return m
end

local function ctrl(w, objs, paint)
    w._disabled = false
    function w:SetDisabled(state)
        self._disabled = state == true
        for _, o in ipairs(objs or {}) do
            if o and o:IsA("GuiObject") then
                o.Active = not self._disabled
            end
        end
        if paint then
            paint(self._disabled)
        end
        return self
    end

    function w:IsDisabled()
        return self._disabled
    end

    return w
end

local function line(o, x, y, w, h, c, z)
    local f = mk("Frame", {
        BorderSizePixel = 0,
        BackgroundColor3 = c or pal.line,
        Position = UDim2.new(0, x or 0, 0, y or 0),
        Size = UDim2.new(0, w or 1, 0, h or 1),
        ZIndex = z or 1
    })
    f.Parent = o
    return f
end

local function loader(ctx, sg, img)
    local root = mk("Frame", {
        Name = "loading",
        BackgroundColor3 = pal.bg,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(260, 116),
        ZIndex = 200,
        Parent = sg
    })
    corner(root, 4)
    stroke(root, pal.warm, 0.88, 1)
    if img then
        mk("ImageLabel", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.new(0.5, 0, 0, 18),
            Size = UDim2.fromOffset(34, 34),
            Image = img,
            ScaleType = Enum.ScaleType.Fit,
            ZIndex = 201,
            Parent = root
        })
    end
    local text = mk("TextLabel", {
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 16, 0, img and 58 or 30),
        Size = UDim2.new(1, -32, 0, 18),
        Text = "loading",
        ZIndex = 201,
        Parent = root
    })
    set_font(text, ctx, 13, pal.dim, Enum.TextXAlignment.Center, Enum.FontWeight.Medium)
    local rail = mk("Frame", {
        BackgroundColor3 = pal.bg2,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 16, 1, -28),
        Size = UDim2.new(1, -32, 0, 4),
        ClipsDescendants = true,
        ZIndex = 201,
        Parent = root
    })
    corner(rail, 2)
    local bar = mk("Frame", {
        BackgroundColor3 = ctx.cfg.accent,
        BorderSizePixel = 0,
        Position = UDim2.new(-0.35, 0, 0, 0),
        Size = UDim2.new(0.35, 0, 1, 0),
        ZIndex = 202,
        Parent = rail
    })
    corner(bar, 2)
    local alive = true
    local cn = game:GetService("RunService").RenderStepped:Connect(function()
        if not alive or not bar.Parent then
            return
        end
        local x = bar.Position.X.Scale + 0.018
        if x > 1 then
            x = -0.35
        end
        bar.Position = UDim2.new(x, 0, 0, 0)
    end)
    return {
        Destroy = function()
            alive = false
            cn:Disconnect()
            root:Destroy()
        end
    }
end

local function root_size(v)
    if typeof(v) == "Vector2" then
        return UDim2.fromOffset(v.X, v.Y)
    end
    if typeof(v) == "UDim2" then
        return v
    end
    return UDim2.fromOffset(640, 430)
end

local function rid()
    local abc = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    local n = math.random(18, 28)
    local out = {}
    for i = 1, n do
        local x = math.random(1, #abc)
        out[i] = abc:sub(x, x)
    end
    return table.concat(out)
end

local function nkey(v)
    if typeof(v) == "EnumItem" and v.EnumType == Enum.KeyCode then
        return v.Name
    end
    if type(v) == "string" and v ~= "" then
        return v
    end
    return nil
end

local function get_keycode(name)
    if not name then
        return nil
    end
    local ok, code = pcall(function()
        return Enum.KeyCode[name]
    end)
    if ok then
        return code
    end
    return nil
end

function sm:Window(o)
    o = o or {}
    local cfg = {
        id = o.id or rid(),
        name = o.name or "sippin' milk",
        logo_raw = o.logo_url or (o.logo ~= nil and o.logo or DEF_LOGO),
        logo = nil,
        font_id = tonumber(o.font ~= nil and o.font or DEF_FONT) or (o.font ~= nil and o.font or DEF_FONT),
        size = root_size(o.size),
        accent = o.accent or pal.blue,
        hide_key = nkey(o.hide_key or o.hideKey) or "RightShift",
        multi = o.multi == true
    }

    if not cfg.multi then
        local old = CG:FindFirstChild(cfg.id)
        if old then
            old:Destroy()
        end
    end

    local win
    local ctx = {
        cfg = cfg,
        maid = maid(),
        store = new_store(),
        acc = {},
        binds = {},
        fonts = {},
        drag = nil,
        capture = nil,
        active_tab = nil,
        hidden = false,
        unloading = false
    }

    function ctx:font(weight)
        local key = tostring(weight and weight.Value or "r")
        if not self.fonts[key] then
            self.fonts[key] = font_pick(self.cfg.font_id, weight)
        end
        return self.fonts[key]
    end

    function ctx:on_acc(fn)
        self.acc[#self.acc + 1] = fn
        pcall(fn, self.cfg.accent)
    end

    function ctx:set_acc(c)
        self.cfg.accent = c
        for i = #self.acc, 1, -1 do
            local ok = pcall(self.acc[i], c)
            if not ok then
                table.remove(self.acc, i)
            end
        end
    end

    ctx.maid:give(UIS.InputChanged:Connect(function(input)
        if ctx.drag and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            ctx.drag.step(input)
        end
    end))

    ctx.maid:give(UIS.InputEnded:Connect(function(input)
        if not ctx.drag then
            return
        end
        local t = input.UserInputType
        if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
            local stop = ctx.drag.stop
            ctx.drag = nil
            if stop then
                stop()
            end
        end
    end))

    ctx.maid:give(UIS.InputBegan:Connect(function(input, gp)
        if gp then
            return
        end
        if ctx.capture then
            if input.UserInputType ~= Enum.UserInputType.Keyboard then
                return
            end
            local cap = ctx.capture
            ctx.capture = nil
            if input.KeyCode == Enum.KeyCode.Escape then
                cap:_listen(false)
                return
            end
            if input.KeyCode == Enum.KeyCode.Backspace then
                cap:Set(nil)
                cap:_listen(false)
                return
            end
            cap:Set(input.KeyCode.Name)
            cap:_listen(false)
            return
        end
        if UIS:GetFocusedTextBox() then
            return
        end
        if input.UserInputType ~= Enum.UserInputType.Keyboard then
            return
        end
        if ctx.cfg.hide_key and input.KeyCode.Name == ctx.cfg.hide_key and win then
            win:Toggle()
            return
        end
        for _, kb in ipairs(ctx.binds) do
            if kb and kb._val and kb._press and kb._val == input.KeyCode.Name then
                kb._press(kb._val)
            end
        end
    end))

    local sg = mk("ScreenGui", {
        Name = cfg.id,
        IgnoreGuiInset = true,
        ResetOnSpawn = false,
        DisplayOrder = 1999,
        ZIndexBehavior = Enum.ZIndexBehavior.Global
    })
    sg.Parent = CG
    ctx.maid:give(sg)

    local logo_img = nil
    local logo_note = nil
    pcall(function()
        logo_img, logo_note = logo_status(cfg.logo_raw)
    end)
    cfg.logo = logo_img
    cfg.logo_note = logo_note

    local load = loader(ctx, sg, logo_img)
    ctx.maid:give(load)
    local load_at = tick and tick() or 0

    local main = mk("Frame", {
        Name = "main",
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = cfg.size,
        BorderSizePixel = 0,
        BackgroundColor3 = pal.bg,
        ClipsDescendants = true,
        Visible = false,
        ZIndex = 10,
        Parent = sg
    })
    corner(main, 4)
    stroke(main, pal.warm, 0.88, 1)

    local head = mk("Frame", {
        Name = "head",
        BackgroundColor3 = pal.bg,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 0, 36),
        ZIndex = 11,
        Parent = main
    })
    pad(head, 12, 0, 12, 0)
    local head_line = line(head, 0, 35, 9999, 1, pal.warm, 11)
    head_line.BackgroundTransparency = 0.88

    local logo = mk("ImageLabel", {
        Name = "logo",
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(22, 22),
        Position = UDim2.new(0, 0, 0.5, -11),
        Image = logo_img or "",
        Visible = logo_img ~= nil,
        ScaleType = Enum.ScaleType.Fit,
        ZIndex = 12,
        Parent = head
    })

    local title = mk("TextLabel", {
        Name = "title",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, logo_img and 30 or 0, 0, 0),
        Size = UDim2.new(1, -150, 1, 0),
        Text = cfg.name,
        ZIndex = 12,
        Parent = head
    })
    set_font(title, ctx, 16, pal.text, Enum.TextXAlignment.Left, Enum.FontWeight.Bold)

    local close = mk("TextButton", {
        Name = "close",
        AnchorPoint = Vector2.new(1, 0.5),
        Position = UDim2.new(1, -2, 0.5, 0),
        Size = UDim2.fromOffset(30, 24),
        BackgroundColor3 = pal.bg,
        BorderSizePixel = 0,
        Text = "x",
        ZIndex = 12,
        Parent = head
    })
    corner(close, 4)
    set_font(close, ctx, 14, pal.dim, Enum.TextXAlignment.Center, Enum.FontWeight.Medium)
    ctx.maid:give(hot(close, pal.bg, pal.bg2, shift(pal.bg2, 0.85)))

    local body = mk("Frame", {
        Name = "body",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 0, 0, 36),
        Size = UDim2.new(1, 0, 1, -36),
        Parent = main
    })

    local side = mk("Frame", {
        Name = "side",
        BackgroundColor3 = pal.bg,
        BorderSizePixel = 0,
        Size = UDim2.new(0, 148, 1, 0),
        ZIndex = 11,
        Parent = body
    })
    local side_line = line(side, 147, 0, 1, 9999, pal.warm, 11)
    side_line.BackgroundTransparency = 0.88

    local tabs = mk("ScrollingFrame", {
        Name = "tabs",
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0, 0),
        Size = UDim2.new(1, 0, 1, 0),
        CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.None,
        ScrollBarThickness = 2,
        ScrollBarImageColor3 = pal.line,
        ZIndex = 12,
        Parent = side
    })
    pad(tabs, 10, 10, 10, 10)
    local tabs_l = list(tabs, 6)
    ctx.maid:give(auto_canvas(tabs, tabs_l, 20))

    local view = mk("Frame", {
        Name = "view",
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 148, 0, 0),
        Size = UDim2.new(1, -148, 1, 0),
        Parent = body
    })

    local pages = mk("Frame", {
        Name = "pages",
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = view
    })

    local stack = mk("Frame", {
        Name = "stack",
        AnchorPoint = Vector2.new(1, 0),
        Position = UDim2.new(1, -12, 0, 12),
        Size = UDim2.new(0, 260, 1, -24),
        BackgroundTransparency = 1,
        ZIndex = 80,
        Parent = sg
    })
    local stack_l = list(stack, 8)
    stack_l.HorizontalAlignment = Enum.HorizontalAlignment.Right

    local modal = mk("Frame", {
        Name = "modal",
        BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.35,
        Visible = false,
        BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0),
        ZIndex = 70,
        Parent = sg
    })

    win = {
        _ctx = ctx,
        _gui = sg,
        _main = main,
        _tabs = {},
        _pages = {},
        _stack = stack,
        _modal = modal
    }

    function win:Ready()
        local function show()
            if load then
                load:Destroy()
                load = nil
            end
            if not ctx.unloading then
                main.Visible = not ctx.hidden
            end
        end
        local now = tick and tick() or load_at + LOAD_MIN
        local wait_left = LOAD_MIN - (now - load_at)
        if wait_left > 0 then
            task.delay(wait_left, show)
        else
            show()
        end
    end

    local function start_drag(frame)
        ctx.maid:give(frame.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            local start = input.Position
            local pos = main.Position
            ctx.drag = {
                step = function(now)
                    local d = now.Position - start
                    main.Position = UDim2.new(pos.X.Scale, pos.X.Offset + d.X, pos.Y.Scale, pos.Y.Offset + d.Y)
                end
            }
        end))
    end

    start_drag(head)
    ctx.maid:give(close.MouseButton1Click:Connect(function()
        win:Hide(true)
    end))

    function win:SetAccent(c)
        if typeof(c) == "Color3" then
            ctx:set_acc(c)
        end
    end

    function win:SetHideKey(key)
        local k = nkey(key)
        if k then
            ctx.cfg.hide_key = k
        end
        return ctx.cfg.hide_key
    end

    function win:GetHideKey()
        return ctx.cfg.hide_key
    end

    function win:Show()
        if ctx.unloading then
            return
        end
        ctx.hidden = false
        main.Visible = true
    end

    function win:Hide(note)
        if ctx.unloading then
            return
        end
        ctx.hidden = true
        main.Visible = false
        if note then
            self:Notify({
                title = cfg.name,
                body = "gui hidden; press " .. tostring(ctx.cfg.hide_key or "the hide key") .. " to view it again",
                time = 3
            })
        end
    end

    function win:Toggle()
        if ctx.hidden then
            self:Show()
        else
            self:Hide(true)
        end
    end

    function win:SaveConfig()
        return cfg_export(ctx.store:export())
    end

    function win:WriteConfig(path)
        local p = path or CFG_FILE
        if type(p) == "string" and not p:match("[/\\]") then
            p = cfg_path(p)
        end
        return write_cfg(p, self:SaveConfig())
    end

    function win:Configs()
        return list_cfg()
    end

    function win:LoadConfigFile(name, silent)
        local data = read_cfg(name or "default")
        if not data then
            return false
        end
        self:LoadConfig(cfg_import(data), silent)
        local hk = ctx.store:get("ui_hide_key")
        if hk then
            self:SetHideKey(hk)
        end
        return true
    end

    function win:LoadConfig(tbl, silent)
        ctx.store:import(cfg_import(tbl), silent)
    end

    function win:Notify(no)
        no = no or {}
        local tone = no.tone or no.color or cfg.accent
        local hold = tonumber(no.time) or 4
        local box = mk("Frame", {
            BackgroundColor3 = pal.bg,
            BorderSizePixel = 0,
            Size = UDim2.fromOffset(260, no.body and 70 or 48),
            ZIndex = 81,
            Parent = stack
        })
        corner(box, 4)
        stroke(box, pal.warm, 0.88, 1)
        local bar = mk("Frame", {
            BorderSizePixel = 0,
            BackgroundColor3 = tone,
            Size = UDim2.new(0, 2, 1, 0),
            ZIndex = 82,
            Parent = box
        })
        local ttl = mk("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 12, 0, 8),
            Size = UDim2.new(1, -24, 0, 16),
            Text = no.title or cfg.name,
            ZIndex = 82,
            Parent = box
        })
        set_font(ttl, ctx, 14, pal.text, Enum.TextXAlignment.Left, Enum.FontWeight.Bold)
        local body_t = mk("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 12, 0, 24),
            Size = UDim2.new(1, -24, 1, -30),
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
            Text = no.body or no.text or "",
            ZIndex = 82,
            Parent = box
        })
        set_font(body_t, ctx, 13, pal.dim, Enum.TextXAlignment.Left, Enum.FontWeight.Regular, Enum.TextYAlignment.Top)

        local note = { box = box }
        function note:Destroy()
            box:Destroy()
        end

        task.delay(hold, function()
            if box.Parent then
                box:Destroy()
            end
        end)

        return note
    end

    function win:Dialog(no)
        no = no or {}
        for _, child in ipairs(modal:GetChildren()) do
            child:Destroy()
        end
        modal.Visible = true

        local card = mk("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new(0.5, 0, 0.5, 0),
            Size = UDim2.fromOffset(320, 170),
            BackgroundColor3 = pal.bg,
            BorderSizePixel = 0,
            ZIndex = 71,
            Parent = modal
        })
        corner(card, 4)
        stroke(card, pal.warm, 0.88, 1)

        local ttl = mk("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 14, 0, 12),
            Size = UDim2.new(1, -28, 0, 18),
            Text = no.title or cfg.name,
            ZIndex = 72,
            Parent = card
        })
        set_font(ttl, ctx, 15, pal.text, Enum.TextXAlignment.Left, Enum.FontWeight.Bold)

        local body_t = mk("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 14, 0, 38),
            Size = UDim2.new(1, -28, 1, -92),
            TextWrapped = true,
            TextYAlignment = Enum.TextYAlignment.Top,
            Text = no.body or no.text or "",
            ZIndex = 72,
            Parent = card
        })
        set_font(body_t, ctx, 13, pal.dim, Enum.TextXAlignment.Left, Enum.FontWeight.Regular, Enum.TextYAlignment.Top)

        local cancel = mk("TextButton", {
            BackgroundColor3 = pal.bg2,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 14, 1, -38),
            Size = UDim2.fromOffset(92, 24),
            Text = no.cancel_text or "cancel",
            ZIndex = 72,
            Parent = card
        })
        corner(cancel, 4)
        set_font(cancel, ctx, 13, pal.text, Enum.TextXAlignment.Center, Enum.FontWeight.Medium)
        local okc = mk("TextButton", {
            BackgroundColor3 = cfg.accent,
            BorderSizePixel = 0,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -14, 1, -38),
            Size = UDim2.fromOffset(92, 24),
            Text = no.ok_text or "ok",
            ZIndex = 72,
            Parent = card
        })
        corner(okc, 4)
        set_font(okc, ctx, 13, pal.text, Enum.TextXAlignment.Center, Enum.FontWeight.Medium)
        ctx:on_acc(function(c)
            okc.BackgroundColor3 = c
        end)
        local m1 = hot(cancel, pal.bg2, shift(pal.bg2, 1.08), shift(pal.bg2, 0.9))
        local m2 = hot(okc, cfg.accent, shift(cfg.accent, 0.86), shift(cfg.accent, 0.72))

        local dlg = {}
        function dlg:Close()
            m1:Destroy()
            m2:Destroy()
            modal.Visible = false
            card:Destroy()
        end

        cancel.MouseButton1Click:Connect(function()
            dlg:Close()
            if no.cancel then
                no.cancel()
            end
        end)
        okc.MouseButton1Click:Connect(function()
            dlg:Close()
            if no.ok then
                no.ok()
            end
        end)

        return dlg
    end

    function win:Unload()
        if ctx.unloading then
            return
        end
        ctx.unloading = true
        ctx.capture = nil
        ctx.drag = nil
        for _, d in ipairs(sg:GetDescendants()) do
            if d:IsA("GuiButton") then
                pcall(function()
                    d.Active = false
                    d.AutoButtonColor = false
                end)
            end
            if d:IsA("GuiObject") then
                pcall(function()
                    d.Visible = false
                end)
            end
        end
        pcall(function()
            sg.Enabled = false
        end)
        for _, tb in ipairs(ctx.binds) do
            if tb and tb._listen then
                tb:_listen(false)
            end
        end
        ctx.maid:Destroy()
    end

    function win:Destroy()
        self:Unload()
    end

    function win:Minimize()
        self:Hide(true)
    end

    function win:Close()
        self:Hide(true)
    end

    function win:ForceDestroy()
        for _, tb in ipairs(ctx.binds) do
            if tb and tb._listen then
                tb:_listen(false)
            end
        end
        ctx.maid:Destroy()
    end

    local section_mt = {}
    section_mt.__index = section_mt

    function section_mt:_row(h)
        local row = mk("Frame", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 0, h),
            Parent = self.body
        })
        if self._sync then
            self:_sync()
            self.maid:give(row:GetPropertyChangedSignal("Size"):Connect(function()
                self:_sync()
            end))
            task.spawn(function()
                if row.Parent then
                    self:_sync()
                end
            end)
        end
        return row
    end

    function section_mt:_bind(w, flag)
        if flag then
            ctx.store:bind(flag, w)
        end
        self.maid:give(function()
            ctx.store:drop(flag, w)
        end)
    end

    function section_mt:Label(o)
        o = o or {}
        local row = self:_row(18)
        zset(row, 13)
        local t = mk("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Text = o.text or o.name or "",
            Parent = row
        })
        zset(t, 14)
        set_font(t, ctx, 13, o.color or pal.dim, Enum.TextXAlignment.Left, Enum.FontWeight.Regular)
        local w = { row = row }
        function w:Destroy()
            row:Destroy()
        end

        return w
    end

    function section_mt:Button(o)
        o = o or {}
        local row = self:_row(30)
        zset(row, 13)
        local btn = mk("TextButton", {
            BackgroundColor3 = pal.bg2,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0),
            Text = o.name or "button",
            Parent = row
        })
        zset(btn, 14)
        corner(btn, 4)
        stroke(btn, pal.warm, 0.88, 1)
        set_font(btn, ctx, 13, pal.text, Enum.TextXAlignment.Center, Enum.FontWeight.Medium)
        local fx = hot(btn, pal.bg2, shift(pal.bg2, 1.08), shift(pal.bg2, 0.9))
        self.maid:give(fx)
        local w = { row = row }
        ctrl(w, { btn }, function(dis)
            btn.TextColor3 = dis and pal.mute or pal.text
            btn.BackgroundColor3 = dis and pal.bg or pal.bg2
        end)
        w:SetDisabled(o.disabled == true)
        self.maid:give(btn.MouseButton1Click:Connect(function()
            if not w._disabled and o.callback then
                o.callback()
            end
        end))
        function w:Destroy()
            row:Destroy()
        end

        return w
    end

    function section_mt:Toggle(o)
        o = o or {}
        local row = self:_row(28)
        zset(row, 13)
        local btn = mk("TextButton", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0),
            Text = "",
            Parent = row
        })
        zset(btn, 16)
        local name = mk("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -42, 1, 0),
            Text = o.name or "toggle",
            Parent = row
        })
        zset(name, 14)
        set_font(name, ctx, 13, pal.text, Enum.TextXAlignment.Left, Enum.FontWeight.Medium)
        local box = mk("Frame", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.fromOffset(28, 16),
            BackgroundColor3 = pal.bg,
            BorderSizePixel = 0,
            Parent = row
        })
        zset(box, 14)
        corner(box, 4)
        stroke(box, pal.line, 0, 1)
        local fill = mk("Frame", {
            Position = UDim2.new(0, 2, 0, 2),
            Size = UDim2.new(1, -4, 1, -4),
            BackgroundColor3 = cfg.accent,
            BorderSizePixel = 0,
            Parent = box
        })
        zset(fill, 15)
        corner(fill, 3)

        local w = {
            row = row,
            flag = o.flag,
            _val = false
        }
        ctrl(w, { btn }, function(dis)
            name.TextColor3 = dis and pal.mute or (w._val and pal.text or pal.dim)
            box.BackgroundColor3 = dis and shift(pal.bg, 0.85) or pal.bg
            fill.BackgroundTransparency = dis and 0.45 or 0
        end)

        local function norm(v)
            return true, not not v
        end

        local function paint(v)
            w._val = v
            fill.Visible = v
            name.TextColor3 = v and pal.text or pal.dim
        end

        function w:_pull(v)
            paint(v)
        end

        function w:Set(v, silent)
            if self._disabled then
                return
            end
            v = not not v
            if self.flag then
                ctx.store:set(self.flag, v, silent, self)
            else
                paint(v)
                if o.callback and not silent then
                    o.callback(v)
                end
            end
        end

        function w:Get()
            return self._val
        end

        function w:Destroy()
            ctx.store:drop(self.flag, self)
            row:Destroy()
        end

        local dv = ctx.store:reg(o.flag, "toggle", o.value == true, o.callback, norm)
        self:_bind(w, o.flag)
        paint(dv)
        w:SetDisabled(o.disabled == true)
        ctx:on_acc(function(c)
            fill.BackgroundColor3 = c
        end)
        self.maid:give(btn.MouseButton1Click:Connect(function()
            if not w._disabled then
                w:Set(not w._val)
            end
        end))
        return w
    end

    function section_mt:Textbox(o)
        o = o or {}
        local row = self:_row(30)
        zset(row, 13)
        local name = mk("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0.4, 0, 1, 0),
            Text = o.name or "textbox",
            Parent = row
        })
        zset(name, 14)
        set_font(name, ctx, 13, pal.text, Enum.TextXAlignment.Left, Enum.FontWeight.Medium)
        local box = mk("TextBox", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0.58, 0, 1, 0),
            BackgroundColor3 = pal.bg,
            BorderSizePixel = 0,
            Text = "",
            ClearTextOnFocus = false,
            PlaceholderText = o.placeholder or "",
            Parent = row
        })
        zset(box, 14)
        corner(box, 6)
        stroke(box, pal.warm, 0.88, 1)
        set_font(box, ctx, 13, pal.text, Enum.TextXAlignment.Left, Enum.FontWeight.Regular)
        box.PlaceholderColor3 = pal.mute
        pad(box, 8, 0, 8, 0)

        local w = {
            row = row,
            flag = o.flag,
            _val = ""
        }
        ctrl(w, { box }, function(dis)
            name.TextColor3 = dis and pal.mute or pal.text
            box.TextEditable = not dis
            box.BackgroundColor3 = dis and shift(pal.bg, 0.85) or pal.bg
        end)

        local function norm(v)
            if v == nil then
                return true, ""
            end
            return true, tostring(v)
        end

        local function paint(v)
            w._val = v
            box.Text = v
        end

        function w:_pull(v)
            paint(v)
        end

        function w:Set(v, silent)
            if self._disabled then
                return
            end
            v = v == nil and "" or tostring(v)
            if self.flag then
                ctx.store:set(self.flag, v, silent, self)
            else
                paint(v)
                if o.callback and not silent then
                    o.callback(v)
                end
            end
        end

        function w:Get()
            return self._val
        end

        function w:Destroy()
            ctx.store:drop(self.flag, self)
            row:Destroy()
        end

        local dv = ctx.store:reg(o.flag, "textbox", o.value or "", o.callback, norm)
        self:_bind(w, o.flag)
        paint(dv)
        w:SetDisabled(o.disabled == true)
        self.maid:give(box.FocusLost:Connect(function()
            if not w._disabled then
                w:Set(box.Text)
            end
        end))
        return w
    end

    function section_mt:Slider(o)
        o = o or {}
        local min = tonumber(o.min) or 0
        local max = tonumber(o.max) or 100
        if max < min then
            min, max = max, min
        end
        local step = tonumber(o.step) or 1
        local row = self:_row(50)
        zset(row, 13)
        local name = mk("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -66, 0, 16),
            Text = o.name or "slider",
            Parent = row
        })
        zset(name, 14)
        set_font(name, ctx, 13, pal.text, Enum.TextXAlignment.Left, Enum.FontWeight.Medium)
        local num = mk("TextBox", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.fromOffset(58, 18),
            BackgroundColor3 = pal.bg,
            BorderSizePixel = 0,
            Text = "",
            ClearTextOnFocus = false,
            Parent = row
        })
        zset(num, 14)
        corner(num, 6)
        stroke(num, pal.warm, 0.88, 1)
        set_font(num, ctx, 12, pal.text, Enum.TextXAlignment.Center, Enum.FontWeight.Regular)
        local rail = mk("Frame", {
            Position = UDim2.new(0, 0, 0, 30),
            Size = UDim2.new(1, 0, 0, 10),
            BackgroundColor3 = pal.bg2,
            BorderSizePixel = 0,
            Parent = row
        })
        zset(rail, 14)
        corner(rail, 4)
        stroke(rail, pal.warm, 0.88, 1)
        local fill = mk("Frame", {
            Size = UDim2.new(0, 0, 1, 0),
            BackgroundColor3 = cfg.accent,
            BorderSizePixel = 0,
            Parent = rail
        })
        zset(fill, 15)
        corner(fill, 4)
        local drag = mk("TextButton", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0),
            Text = "",
            Parent = rail
        })
        zset(drag, 16)

        local w = {
            row = row,
            flag = o.flag,
            _val = min
        }
        ctrl(w, { num, drag }, function(dis)
            name.TextColor3 = dis and pal.mute or pal.text
            num.TextEditable = not dis
            rail.BackgroundColor3 = dis and pal.bg or pal.bg2
            fill.BackgroundTransparency = dis and 0.45 or 0
        end)

        local function norm(v)
            v = tonumber(v)
            if not v then
                return false
            end
            v = clamp(snap(v, step), min, max)
            return true, v
        end

        local function paint(v)
            w._val = v
            local p = max == min and 0 or (v - min) / (max - min)
            fill.Size = UDim2.new(p, 0, 1, 0)
            num.Text = tostring(v)
        end

        function w:_pull(v)
            paint(v)
        end

        function w:Set(v, silent)
            if self._disabled then
                return
            end
            local ok, nv = norm(v)
            if not ok then
                return
            end
            if self.flag then
                ctx.store:set(self.flag, nv, silent, self)
            else
                paint(nv)
                if o.callback and not silent then
                    o.callback(nv)
                end
            end
        end

        function w:Get()
            return self._val
        end

        function w:Destroy()
            ctx.store:drop(self.flag, self)
            row:Destroy()
        end

        local function grab(input)
            local p = clamp((input.Position.X - rail.AbsolutePosition.X) / math.max(rail.AbsoluteSize.X, 1), 0, 1)
            w:Set(min + ((max - min) * p))
        end

        local dv = ctx.store:reg(o.flag, "slider", clamp(snap(tonumber(o.value) or min, step), min, max), o.callback,
            norm)
        self:_bind(w, o.flag)
        paint(dv)
        w:SetDisabled(o.disabled == true)
        ctx:on_acc(function(c)
            fill.BackgroundColor3 = c
        end)
        self.maid:give(num.FocusLost:Connect(function()
            if not w._disabled then
                w:Set(num.Text, false)
            end
        end))
        self.maid:give(drag.InputBegan:Connect(function(input)
            if w._disabled then
                return
            end
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then
                return
            end
            grab(input)
            ctx.drag = {
                step = function(now)
                    grab(now)
                end
            }
        end))
        return w
    end

    function section_mt:Dropdown(o)
        o = o or {}
        local vals = {}
        for _, v in ipairs(o.values or o.list or {}) do
            vals[#vals + 1] = tostring(v)
        end
        local row = self:_row(32)
        zset(row, 13)
        row.ClipsDescendants = true
        local name = mk("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0.4, 0, 0, 30),
            Text = o.name or "dropdown",
            Parent = row
        })
        zset(name, 14)
        set_font(name, ctx, 13, pal.text, Enum.TextXAlignment.Left, Enum.FontWeight.Medium)
        local btn = mk("TextButton", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, 0, 0, 0),
            Size = UDim2.new(0.58, 0, 0, 30),
            BackgroundColor3 = pal.bg2,
            BorderSizePixel = 0,
            Text = "",
            Parent = row
        })
        zset(btn, 14)
        corner(btn, 4)
        stroke(btn, pal.warm, 0.88, 1)
        local val_t = mk("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, -22, 1, 0),
            Text = "",
            Parent = btn
        })
        zset(val_t, 15)
        set_font(val_t, ctx, 12, pal.text, Enum.TextXAlignment.Left, Enum.FontWeight.Regular)
        pad(val_t, 8, 0, 8, 0)
        local arrow = mk("TextLabel", {
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -6, 0, 0),
            Size = UDim2.fromOffset(14, 30),
            BackgroundTransparency = 1,
            Text = "+",
            Parent = btn
        })
        zset(arrow, 15)
        set_font(arrow, ctx, 12, pal.dim, Enum.TextXAlignment.Center, Enum.FontWeight.Medium)

        local list_box = mk("ScrollingFrame", {
            Position = UDim2.new(0.42, 0, 0, 34),
            Size = UDim2.new(0.58, 0, 0, 0),
            BackgroundColor3 = pal.bg,
            BorderSizePixel = 0,
            Visible = false,
            ClipsDescendants = true,
            CanvasSize = UDim2.new(),
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = pal.line,
            Parent = row
        })
        zset(list_box, 20)
        corner(list_box, 4)
        stroke(list_box, pal.warm, 0.88, 1)
        pad(list_box, 6, 6, 6, 6)
        local list_l = list(list_box, 4)
        self.maid:give(auto_canvas(list_box, list_l, 12))

        local item_maids = {}
        local w = {
            row = row,
            flag = o.flag,
            _val = nil,
            _open = false
        }
        ctrl(w, { btn }, function(dis)
            name.TextColor3 = dis and pal.mute or pal.text
            btn.BackgroundColor3 = dis and pal.bg or pal.bg2
            val_t.TextColor3 = dis and pal.mute or (w._val and pal.text or pal.dim)
        end)

        local function clear_items()
            for _, m in ipairs(item_maids) do
                if typeof(m) == "RBXScriptConnection" then
                    m:Disconnect()
                else
                    m:Destroy()
                end
            end
            for i = #item_maids, 1, -1 do
                item_maids[i] = nil
            end
            for _, child in ipairs(list_box:GetChildren()) do
                if child:IsA("TextButton") then
                    child:Destroy()
                end
            end
        end

        local function has(v)
            for _, x in ipairs(vals) do
                if x == v then
                    return true
                end
            end
            return false
        end

        local function norm(v)
            if v == nil then
                return true, nil
            end
            v = tostring(v)
            if not has(v) then
                return false
            end
            return true, v
        end

        local function resize()
            if not w._open then
                row.Size = UDim2.new(1, 0, 0, 32)
                list_box.Visible = false
                list_box.Size = UDim2.new(0.58, 0, 0, 0)
                arrow.Text = "+"
                return
            end
            local h = clamp((#vals * 26) + 12, 24, 144)
            row.Size = UDim2.new(1, 0, 0, 38 + h)
            list_box.Visible = true
            list_box.Size = UDim2.new(0.58, 0, 0, h)
            arrow.Text = "-"
        end

        local function paint(v)
            w._val = v
            val_t.Text = v or "none"
            val_t.TextColor3 = v and pal.text or pal.dim
        end

        function w:_pull(v)
            paint(v)
        end

        function w:Set(v, silent)
            if self._disabled then
                return
            end
            local ok, nv = norm(v)
            if not ok then
                return
            end
            if self.flag then
                ctx.store:set(self.flag, nv, silent, self)
            else
                paint(nv)
                if o.callback and not silent then
                    o.callback(nv)
                end
            end
        end

        function w:Get()
            return self._val
        end

        function w:Open(state)
            if self._disabled then
                return
            end
            self._open = state == nil and not self._open or state
            resize()
        end

        function w:Destroy()
            ctx.store:drop(self.flag, self)
            clear_items()
            row:Destroy()
        end

        local function add_item(v)
            local item = mk("TextButton", {
                BackgroundColor3 = pal.bg2,
                BorderSizePixel = 0,
                Size = UDim2.new(1, 0, 0, 22),
                Text = tostring(v),
                Parent = list_box
            })
            zset(item, 21)
            corner(item, 4)
            set_font(item, ctx, 12, pal.text, Enum.TextXAlignment.Left, Enum.FontWeight.Regular)
            pad(item, 8, 0, 8, 0)
            local fx = hot(item, pal.bg2, shift(pal.bg2, 1.08), shift(pal.bg2, 0.9))
            local cn = item.MouseButton1Click:Connect(function()
                w:Set(v)
                w:Open(false)
            end)
            item_maids[#item_maids + 1] = fx
            item_maids[#item_maids + 1] = cn
            item_maids[#item_maids + 1] = {
                Destroy = function()
                    item:Destroy()
                end
            }
        end

        for _, v in ipairs(vals) do
            add_item(v)
        end

        function w:SetValues(next_vals, keep)
            clear_items()
            for i = #vals, 1, -1 do
                vals[i] = nil
            end
            for _, v in ipairs(next_vals or {}) do
                vals[#vals + 1] = tostring(v)
            end
            for _, v in ipairs(vals) do
                add_item(v)
            end
            if not keep or (self._val and not has(self._val)) then
                self:Set(vals[1], true)
            end
            resize()
        end

        local dval = o.value ~= nil and tostring(o.value) or nil
        if dval == nil and #vals > 0 then
            dval = vals[1]
        end
        local dv = ctx.store:reg(o.flag, "dropdown", dval, o.callback, norm)
        self:_bind(w, o.flag)
        paint(dv)
        w:SetDisabled(o.disabled == true)
        resize()
        self.maid:give(btn.MouseButton1Click:Connect(function()
            if not w._disabled then
                w:Open()
            end
        end))
        return w
    end

    function section_mt:Keybind(o)
        o = o or {}
        local row = self:_row(30)
        zset(row, 13)
        local name = mk("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(0.4, 0, 1, 0),
            Text = o.name or "keybind",
            Parent = row
        })
        zset(name, 14)
        set_font(name, ctx, 13, pal.text, Enum.TextXAlignment.Left, Enum.FontWeight.Medium)
        local btn = mk("TextButton", {
            AnchorPoint = Vector2.new(1, 0.5),
            Position = UDim2.new(1, 0, 0.5, 0),
            Size = UDim2.new(0.58, 0, 1, 0),
            BackgroundColor3 = pal.bg2,
            BorderSizePixel = 0,
            Text = "",
            Parent = row
        })
        zset(btn, 14)
        corner(btn, 4)
        stroke(btn, pal.warm, 0.88, 1)
        local txt = mk("TextLabel", {
            BackgroundTransparency = 1,
            Size = UDim2.new(1, 0, 1, 0),
            Text = "",
            Parent = btn
        })
        zset(txt, 15)
        set_font(txt, ctx, 12, pal.text, Enum.TextXAlignment.Center, Enum.FontWeight.Regular)

        local w = {
            row = row,
            flag = o.flag,
            _val = nil,
            _wait = false,
            _press = o.callback
        }
        ctrl(w, { btn }, function(dis)
            name.TextColor3 = dis and pal.mute or pal.text
            btn.BackgroundColor3 = dis and pal.bg or pal.bg2
            txt.TextColor3 = dis and pal.mute or (w._wait and cfg.accent or (w._val and pal.text or pal.dim))
        end)

        local function norm(v)
            local k = nkey(v)
            return true, k
        end

        local function paint(v)
            w._val = v
            txt.Text = w._wait and "press key" or (v or "none")
            txt.TextColor3 = w._wait and cfg.accent or (v and pal.text or pal.dim)
        end

        function w:_listen(state)
            if self._disabled then
                return
            end
            self._wait = state
            if state then
                ctx.capture = self
            elseif ctx.capture == self then
                ctx.capture = nil
            end
            paint(self._val)
        end

        function w:_pull(v)
            paint(v)
        end

        function w:Set(v, silent)
            if self._disabled then
                return
            end
            local _, nv = norm(v)
            if self.flag then
                ctx.store:set(self.flag, nv, silent, self)
            else
                paint(nv)
                if o.changed and not silent then
                    o.changed(nv)
                end
            end
        end

        function w:Get()
            return self._val
        end

        function w:Destroy()
            ctx.store:drop(self.flag, self)
            for i, kb in ipairs(ctx.binds) do
                if kb == self then
                    table.remove(ctx.binds, i)
                    break
                end
            end
            row:Destroy()
        end

        local dv = ctx.store:reg(o.flag, "keybind", nkey(o.value), o.changed, norm)
        self:_bind(w, o.flag)
        paint(dv)
        w:SetDisabled(o.disabled == true)
        ctx.binds[#ctx.binds + 1] = w
        local fx = hot(btn, pal.bg2, shift(pal.bg2, 1.08), shift(pal.bg2, 0.9))
        self.maid:give(fx)
        self.maid:give(btn.MouseButton1Click:Connect(function()
            if not w._disabled then
                w:_listen(not w._wait)
            end
        end))
        ctx:on_acc(function(c)
            if w._wait then
                txt.TextColor3 = c
            end
        end)
        return w
    end

    function section_mt:HideKeybind(o)
        o = o or {}
        local old = o.changed
        o.name = o.name or "hide key"
        o.flag = o.flag or "ui_hide_key"
        o.value = o.value or win:GetHideKey()
        o.changed = function(key)
            if key then
                win:SetHideKey(key)
            end
            if old then
                old(key)
            end
        end
        local kb = self:Keybind(o)
        win:SetHideKey(kb:Get())
        return kb
    end

    local tab_mt = {}
    tab_mt.__index = tab_mt

    function tab_mt:Section(o)
        o = o or {}
        local sec = {
            tab = self,
            maid = maid()
        }
        self.maid:give(sec.maid)
        local frame = mk("Frame", {
            BackgroundColor3 = pal.bg2,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 38),
            Parent = self.page
        })
        zset(frame, 12)
        corner(frame, 4)
        stroke(frame, pal.warm, 0.88, 1)
        local head_btn = mk("TextButton", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 30),
            Text = "",
            Parent = frame
        })
        zset(head_btn, 13)
        local head_t = mk("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 12, 0, 8),
            Size = UDim2.new(1, -44, 0, 16),
            Text = o.name or "section",
            Parent = frame
        })
        zset(head_t, 14)
        set_font(head_t, ctx, 13, pal.text, Enum.TextXAlignment.Left, Enum.FontWeight.Bold)
        local chev = mk("TextLabel", {
            BackgroundTransparency = 1,
            AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -12, 0, 8),
            Size = UDim2.fromOffset(16, 16),
            Text = "-",
            Parent = frame
        })
        zset(chev, 14)
        set_font(chev, ctx, 13, pal.dim, Enum.TextXAlignment.Center, Enum.FontWeight.Bold)
        local body = mk("Frame", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 12, 0, 30),
            Size = UDim2.new(1, -24, 0, 0),
            ClipsDescendants = false,
            Parent = frame
        })
        zset(body, 12)
        local lay = list(body, 8)
        sec.collapsed = o.collapsed == true
        local function sync()
            local h = lay.AbsoluteContentSize.Y
            local manual = 0
            local n = 0
            for _, child in ipairs(body:GetChildren()) do
                if child:IsA("GuiObject") then
                    manual = manual + child.Size.Y.Offset
                    n = n + 1
                end
            end
            if n > 1 then
                manual = manual + ((n - 1) * lay.Padding.Offset)
            end
            if manual > h then
                h = manual
            end
            body.Size = UDim2.new(1, -24, 0, h)
            body.Visible = not sec.collapsed
            chev.Text = sec.collapsed and "+" or "-"
            frame.Size = UDim2.new(1, 0, 0, sec.collapsed and 34 or (42 + h))
        end
        function sec:_sync()
            sync()
        end
        sec.maid:give(lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(sync))
        sec.maid:give(head_btn.MouseButton1Click:Connect(function()
            sec:SetCollapsed(not sec.collapsed)
        end))
        sync()
        sec.frame = frame
        sec.body = body
        function sec:SetCollapsed(state)
            self.collapsed = state == true
            sync()
            return self
        end

        function sec:Toggle()
            return self:SetCollapsed(not self.collapsed)
        end

        return setmetatable(sec, section_mt)
    end

    function win:Tab(o)
        o = o or {}
        local page = mk("ScrollingFrame", {
            BackgroundTransparency = 1,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0),
            CanvasSize = UDim2.new(),
            ScrollBarThickness = 2,
            ScrollBarImageColor3 = pal.line,
            Visible = false,
            Parent = pages
        })
        zset(page, 11)
        pad(page, 12, 12, 12, 12)
        local page_l = list(page, 12)
        ctx.maid:give(auto_canvas(page, page_l, 24))

        local btn = mk("TextButton", {
            BackgroundColor3 = pal.bg,
            BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 0, 26),
            Text = "",
            Parent = tabs
        })
        zset(btn, 13)
        corner(btn, 4)
        local bar = mk("Frame", {
            BackgroundColor3 = cfg.accent,
            BorderSizePixel = 0,
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(0, 2, 1, 0),
            Visible = false,
            Parent = btn
        })
        zset(bar, 14)
        local txt = mk("TextLabel", {
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 10, 0, 0),
            Size = UDim2.new(1, -10, 1, 0),
            Text = o.name or "tab",
            Parent = btn
        })
        zset(txt, 15)
        set_font(txt, ctx, 13, pal.dim, Enum.TextXAlignment.Left, Enum.FontWeight.Medium)

        local tab = {
            win = win,
            page = page,
            btn = btn,
            maid = maid()
        }
        ctx.maid:give(tab.maid)

        function tab:Set(state)
            page.Visible = state
            bar.Visible = state
            btn.BackgroundColor3 = state and pal.bg2 or pal.bg
            txt.TextColor3 = state and pal.text or pal.dim
            if state then
                ctx.active_tab = self
            end
        end

        function tab:Destroy()
            self.maid:Destroy()
            page:Destroy()
            btn:Destroy()
        end

        ctx:on_acc(function(c)
            bar.BackgroundColor3 = c
        end)
        tab._hover = false
        local function tab_paint()
            if ctx.active_tab == tab then
                btn.BackgroundColor3 = pal.bg2
                txt.TextColor3 = pal.text
                bar.Visible = true
            else
                btn.BackgroundColor3 = tab._hover and pal.bg2 or pal.bg
                txt.TextColor3 = tab._hover and pal.text or pal.dim
                bar.Visible = false
            end
        end
        tab.maid:give(btn.MouseEnter:Connect(function()
            tab._hover = true
            tab_paint()
        end))
        tab.maid:give(btn.MouseLeave:Connect(function()
            tab._hover = false
            tab_paint()
        end))
        tab.maid:give(btn.MouseButton1Down:Connect(function()
            if ctx.active_tab ~= tab then
                btn.BackgroundColor3 = shift(pal.bg2, 0.9)
            end
        end))
        tab.maid:give(btn.MouseButton1Up:Connect(function()
            tab_paint()
        end))
        tab.maid:give(btn.MouseButton1Click:Connect(function()
            for _, t in ipairs(win._tabs) do
                t:Set(false)
            end
            tab:Set(true)
            tab_paint()
        end))

        win._tabs[#win._tabs + 1] = tab
        if not ctx.active_tab and o.active ~= false then
            tab:Set(true)
        end
        tab_paint()
        return setmetatable(tab, tab_mt)
    end

    if o.settings ~= false then
        local set_tab = win:Tab({
            name = "settings",
            active = false
        })
        local set_sec = set_tab:Section({
            name = "gui settings"
        })
        local name_box = set_sec:Textbox({
            name = "config name",
            flag = "ui_config_name",
            value = "default"
        })
        local cfg_drop = set_sec:Dropdown({
            name = "configs",
            flag = "ui_config_selected",
            values = list_cfg(),
            value = "default"
        })
        set_sec:Button({
            name = "refresh configs",
            callback = function()
                cfg_drop:SetValues(win:Configs(), true)
            end
        })
        set_sec:Button({
            name = "save config",
            callback = function()
                local nm = cfg_name(name_box:Get())
                local ok = win:WriteConfig(nm)
                cfg_drop:SetValues(win:Configs(), true)
                cfg_drop:Set(nm, true)
                win:Notify({
                    title = "config",
                    body = ok and ("saved " .. nm) or "save failed",
                    time = 2
                })
            end
        })
        set_sec:Button({
            name = "load config",
            callback = function()
                local nm = cfg_drop:Get() or name_box:Get()
                local ok = win:LoadConfigFile(nm, true)
                if ok then
                    name_box:Set(nm, true)
                end
                win:Notify({
                    title = "config",
                    body = ok and ("loaded " .. tostring(nm)) or "load failed",
                    time = 2
                })
            end
        })
        set_sec:HideKeybind({
            name = "hide key",
            flag = "ui_hide_key",
            value = win:GetHideKey(),
            changed = function(key)
                win:Notify({
                    title = "hide key",
                    body = "set to " .. tostring(key),
                    time = 2
                })
            end
        })
        set_sec:Button({
            name = "unload gui",
            callback = function()
                win:Unload()
            end
        })
        local credit_sec = set_tab:Section({
            name = "credits"
        })
        credit_sec:Label({
            text = "credits to @pawslaves on discord"
        })
        credit_sec:Button({
            name = "copy discord server",
            callback = function()
                local ok = clip("https://discord.gg/CgAR5J6KpM")
                win:Notify({
                    title = "discord",
                    body = ok and "server link copied" or "clipboard unavailable on this executor",
                    time = 2
                })
            end
        })
    end

    return win
end

return sm

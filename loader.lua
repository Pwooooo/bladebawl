local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local httpRequest = (syn and syn.request) or request or http_request

local JUNKIE_API = "https://api.jnkie.com/api/v1/whitelist"
local JUNKIE_SCRIPT_DOWNLOAD = "https://api.jnkie.com/api/v1/luascripts/public/%s/download"

local SERVICE = "Sky - Blade Ball"
local IDENTIFIER = "35800"
local PROVIDER = "Sky"
local SCRIPT_ID = "YOUR_SCRIPT_ID_HERE" -- Replace with your Junkie script ID after uploading main.lua

local KeyValidated = false

local KeyGui = Instance.new("ScreenGui")
KeyGui.Name = "SkyKeySystem"
KeyGui.ResetOnSpawn = false
KeyGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
pcall(function() KeyGui.Parent = CoreGui end)
if not KeyGui.Parent then KeyGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end

local MainFrame = Instance.new("Frame", KeyGui)
MainFrame.Size = UDim2.new(0, 320, 0, 240)
MainFrame.Position = UDim2.new(0.5, -160, 0.5, -120)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 12, 12)
MainFrame.BorderSizePixel = 0

Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)
local Stroke = Instance.new("UIStroke", MainFrame)
Stroke.Color = Color3.fromRGB(40, 40, 40)

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, -20, 0, 30)
Title.Position = UDim2.new(0, 10, 0, 10)
Title.BackgroundTransparency = 1
Title.Text = "Sky"
Title.TextColor3 = Color3.fromRGB(200, 215, 230)
Title.TextSize = 18
Title.Font = Enum.Font.GothamBold
Title.TextXAlignment = Enum.TextXAlignment.Center

local Sub = Instance.new("TextLabel", MainFrame)
Sub.Size = UDim2.new(1, -20, 0, 20)
Sub.Position = UDim2.new(0, 10, 0, 38)
Sub.BackgroundTransparency = 1
Sub.Text = "Key System"
Sub.TextColor3 = Color3.fromRGB(136, 136, 136)
Sub.TextSize = 12
Sub.Font = Enum.Font.Gotham
Sub.TextXAlignment = Enum.TextXAlignment.Center

local KeyInput = Instance.new("TextBox", MainFrame)
KeyInput.Size = UDim2.new(1, -40, 0, 35)
KeyInput.Position = UDim2.new(0, 20, 0, 70)
KeyInput.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
KeyInput.BorderSizePixel = 0
KeyInput.PlaceholderText = "Enter your key..."
KeyInput.PlaceholderColor3 = Color3.fromRGB(100, 100, 100)
KeyInput.TextColor3 = Color3.fromRGB(255, 255, 255)
KeyInput.TextSize = 14
KeyInput.Font = Enum.Font.Gotham
KeyInput.ClearTextOnFocus = false
KeyInput.Text = ""
Instance.new("UICorner", KeyInput).CornerRadius = UDim.new(0, 4)

local SubmitBtn = Instance.new("TextButton", MainFrame)
SubmitBtn.Size = UDim2.new(1, -40, 0, 35)
SubmitBtn.Position = UDim2.new(0, 20, 0, 115)
SubmitBtn.BackgroundColor3 = Color3.fromRGB(200, 215, 230)
SubmitBtn.BorderSizePixel = 0
SubmitBtn.Text = "Submit"
SubmitBtn.TextColor3 = Color3.fromRGB(12, 12, 12)
SubmitBtn.TextSize = 14
SubmitBtn.Font = Enum.Font.GothamBold
Instance.new("UICorner", SubmitBtn).CornerRadius = UDim.new(0, 4)

local StatusLabel = Instance.new("TextLabel", MainFrame)
StatusLabel.Size = UDim2.new(1, -40, 0, 20)
StatusLabel.Position = UDim2.new(0, 20, 0, 160)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = ""
StatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
StatusLabel.TextSize = 12
StatusLabel.Font = Enum.Font.Gotham
StatusLabel.TextXAlignment = Enum.TextXAlignment.Center

local GetKeyBtn = Instance.new("TextButton", MainFrame)
GetKeyBtn.Size = UDim2.new(1, -40, 0, 20)
GetKeyBtn.Position = UDim2.new(0, 20, 0, 185)
GetKeyBtn.BackgroundTransparency = 1
GetKeyBtn.Text = "Don't have a key? Get one here"
GetKeyBtn.TextColor3 = Color3.fromRGB(0, 169, 239)
GetKeyBtn.TextSize = 11
GetKeyBtn.Font = Enum.Font.Gotham

local attempts = 0
local maxAttempts = 5

GetKeyBtn.MouseButton1Click:Connect(function()
    local ok, resp = pcall(function()
        return httpRequest({
            Method = "POST",
            Url = JUNKIE_API .. "/getKeyOpen",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({
                service = SERVICE,
                provider = PROVIDER,
                identifier = IDENTIFIER
            })
        })
    end)
    if ok and resp and resp.StatusCode == 200 then
        pcall(function() setclipboard(resp.Body) end)
        StatusLabel.Text = "Link copied to clipboard!"
        StatusLabel.TextColor3 = Color3.fromRGB(0, 200, 100)
    else
        StatusLabel.Text = "Rate limited - wait 5 min"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
    end
end)

local function DoValidate()
    local key = KeyInput.Text
    if key == "" then
        StatusLabel.Text = "Please enter a key"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        return
    end

    attempts = attempts + 1
    if attempts > maxAttempts then
        StatusLabel.Text = "Too many attempts"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        return
    end

    StatusLabel.Text = "Validating..."
    StatusLabel.TextColor3 = Color3.fromRGB(200, 215, 230)
    SubmitBtn.Text = "..."

    local ok, resp = pcall(function()
        return httpRequest({
            Method = "POST",
            Url = JUNKIE_API .. "/verifyOpen",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({
                key = tostring(key),
                service = SERVICE,
                identifier = IDENTIFIER
            })
        })
    end)

    if ok and resp and resp.StatusCode == 200 then
        local data = HttpService:JSONDecode(resp.Body)
        if data.valid then
            KeyValidated = true
            getgenv().SCRIPT_KEY = key
            StatusLabel.Text = "Key valid! Loading..."
            StatusLabel.TextColor3 = Color3.fromRGB(0, 200, 100)
            SubmitBtn.Text = "Success"
            SubmitBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 100)
        else
            local errMsg = data.error or data.message or "Invalid key"
            StatusLabel.Text = errMsg
            StatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
            SubmitBtn.Text = "Submit"
        end
    else
        StatusLabel.Text = "Connection error"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 80, 80)
        SubmitBtn.Text = "Submit"
    end
end

SubmitBtn.MouseButton1Click:Connect(DoValidate)
KeyInput.FocusLost:Connect(function(enter) if enter then DoValidate() end end)

while not KeyValidated do task.wait(0.1) end
task.wait(0.5)
KeyGui:Destroy()

if SCRIPT_ID == "YOUR_SCRIPT_ID_HERE" then
    error("Replace SCRIPT_ID in loader with your Junkie script ID")
end

loadstring(game:HttpGet(JUNKIE_SCRIPT_DOWNLOAD:format(SCRIPT_ID)))()
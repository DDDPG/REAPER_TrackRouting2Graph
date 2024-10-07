-- TrackRouting2dot, v0.1, M Fabian
-- Goes through the current project and generates a file (png or gif or jpg or...)
-- that graphically displays the track routing within the project
-- Uses the dot layout engine, available in the Graphviz package from http://graphviz.org/
-- TODO: 
-- * DONE! - Add send and receive channels at the respective ends of the arrows
-- * DONE! - Add "implicit" sends from children to parents, hatched lines
-- * Make edges orthogonal (splines=ortho should fix that but doesn't, probably not possible)
-- * DONE! - Make the track colors more like what the colors actually look in Reaper
-- * DONE! - Distinhguish MIDI sends
-- * Allow to graph only selected tracks
-- * Automagically load the generated gif/png/jpg/whatever into Reaper (possible?)

-- Optimization, v0.1, Lertoon Wang :-)
-- TODO:
-- * [DONE!] Simple GUI interface
-- * [DONE!] Graphviz path check
-- * [DONE!] IO path & item Check
-- * [DONE!] user message window
-- * Windows OS File manager API (I only have Mac so ...)

-- default setting
local default_dot_path = "/opt/homebrew/opt/graphviz/bin/"
local default_dot_out = "/Users/lertoon/Desktop/route_graph"
local default_dot_type = "png"
local default_dot_splines = "spline"
local default_dot_tshape = "node [shape=box style=filled]"
local default_dot_ext = ".gv"

local rpr = reaper
local GET_SENDS = 0
local MASTER_TRACK = -1
-----------------------------------------
local function pathValidCheck(path)
    local f = io.open(path, "r")
    if f ~= nil then
        io.close(f)
        return true
    else
        return false
    end
end
-----------------------------------------
local function validate_inputs(inputs)
    -- Validation for each input field
    
    -- Validate Graphviz path (check if it's non-empty and ends with a slash or backslash)
    if inputs[1] == "" or not (inputs[1]:sub(-1) == "\\" or inputs[1]:sub(-1) == "/") then
        return false, "Graphviz path must end with '\\' or '/'."
    end

    -- Validate Graphviz path (check if it's a valid path)
    if not pathValidCheck(inputs[1].."dot") then
        return false, "Graphviz path is invalid."
    end

    -- Validate output file name (check if non-empty)
    if inputs[2] == "" then
        return false, "Output file name cannot be empty."
    end

    -- Validate the prefix of the output file name (check if it's a valid path)
    if not pathValidCheck(string.match(inputs[2], "(.*[/\\])")) then
        return false, "Output path is invalid."
    end

    -- Validate output format (allow only certain formats)
    local valid_formats = {gif = true, png = true, pdf = true, jpg = true, svg = true}
    if not valid_formats[inputs[3]] then
        return false, "Invalid output format. Allowed formats: gif, png, pdf, jpg, svg."
    end

    -- Validate splines option (check if it's one of the allowed values)
    local valid_splines = {spline = true, line = true, polyline = true, ortho = true}
    if not valid_splines[inputs[4]] then
        return false, "Invalid splines value. Allowed values: spline, line, polyline, ortho."
    end

    return true, "Inputs are valid"
end
-----------------------------------------
local function get_inputs()

    -- Loop until valid input is provided
    local is_valid = false
    local user_input = ""
    
    while not is_valid do
        -- Get user inputs
        local guiret, user_input = reaper.GetUserInputs(
            "Graph Create Setting", 4, 
            "Graphviz path (with '\\' or '/' postfix),extrawidth=200," ..
            "Output path (without extension),Output file (gif, png, pdf, jpg...),Splines (spline/line/polyline/ortho)", 
            default_dot_path .. "," .. default_dot_out .. "," .. default_dot_type .. "," .. default_dot_splines
        )

        -- Exit if user cancels
        if not guiret then 
          return 
        end
        
        -- Process input into a table
        local inputs = {}
        for input in string.gmatch(user_input, "([^,]+)") do
            table.insert(inputs, input)
        end

        -- Validate inputs
        is_valid, error_msg = validate_inputs(inputs)
        if not is_valid then
            reaper.ShowMessageBox(error_msg, "Input Error", 0)
        else
            -- If valid, proceed with the next steps
            
            return inputs[1], inputs[2], inputs[3], inputs[4]
        end
    end
end

-----------------------------------------

-- Check if Graphviz path is valid
if not pathValidCheck(default_dot_path.."dot") then
    reaper.ShowMessageBox("Graphviz path is invalid. Please check the path in the script.", "Path Error", 0)
    return
end

-- Get user inputs
local dot_path, dot_out, dot_type, dot_splines = get_inputs()

-- Exit if inputs are not provided
if dot_path == nil then
    return
end


-- upload setting
local DOT_PATH = dot_path
local DOT_OUT = dot_out
local DOT_TYPE = dot_type
local DOT_SPLINES = dot_splines
local DOT_TSHAPE = default_dot_tshape
local DOT_EXT = default_dot_ext
local DOT_CMD = "dot -T " .. DOT_TYPE .. " -o \"" .. DOT_OUT .. "." .. DOT_TYPE .. "\" \"" .. DOT_OUT .. DOT_EXT .. "\""
local DOT_GRAPH = "graph [fontsize=24 labelloc=\"t\" label=\"_\" splines=" .. DOT_SPLINES .. " overlap=false rankdir=\"LR\"];"



-----------------------------------------
local function formatChanLabel(chanvalue)
-- For src and dest channels:
--    0 means stereo 1/2, 1 means stereo 2/3, 2 means stereo 3/4, etc. So: (srcchan+1)/(srcchan+2)
-- 1024 means mono 1,  1025 means mono 2,  1026 means mono 3, etc. So: srcchan-1023
-- negative values represent midi channels -17, 

  if 0 <= chanvalue then
    if chanvalue < 1024 then -- stero
      return (chanvalue+1).."/"..(chanvalue+2)
    else -- mono
      return ""..(chanvalue-1023)
    end
  else -- negative value means MIDI
    return "MIDI" -- simply this for now!
  end
  
end -- formatChanLabel
------------------------------------------
local function formatChanLabels(src, dest)

  local label = ""
  
  if src < 0 then -- this is MIDI
    assert(dest < 0, "Something seriuoly wrong here!")
    local midisrc = src + 17
    local mididest = dest + 17
    if midisrc == mididest then
      label = "label=\"MIDI "..midisrc.."\" style=dotted" 
    else
      label = "label=\"MIDI "..midisrc.." > "..mididest.."\" style=dotted" 
    end
  elseif src == dest then
    label = "label=\""..formatChanLabel(src).."\""
  else
    label ="taillabel=\""..formatChanLabel(src)..
            "\" headlabel=\""..formatChanLabel(dest).."\"".." labeldistance=2.0"
  end
  --Msg(label)
  return label
  
end -- formatChanLabels
----------------------------------------
local function getTrackColor(mediatrack)

  local color = math.floor(rpr.GetTrackColor(mediatrack))
  if color == 0 then
    return ""
  end
  
  local R, G, B = rpr.ColorFromNative(color)
  
  -- dot takes colors in rgb hex as "#FF0000" for red, "#00FF00" green, "#0000FF" blue. and all in-between
  -- The fourth hex "88" at the end is the alpha channel, without it the colors are a tad too strong
  local outstr = string.format("#%02x%02x%02x88", R, G, B)
  return outstr
  
end
-----------------------------
local function getTrackInfo()

  local tracks = {} -- collects all the tracks
  
  local numtracks = rpr.GetNumTracks()
  if numtracks == 0 then return tracks end
  
  for i = 0, numtracks-1 do
    local trackinfo = {}  -- mediatrack, num, name, color
    local mediatrack = rpr.GetTrack(0, i)
    trackinfo.mediatrack = mediatrack
    trackinfo.num = math.floor(rpr.GetMediaTrackInfo_Value(mediatrack, "IP_TRACKNUMBER"))
    _, trackinfo.name = rpr.GetTrackName(mediatrack, "")
    trackinfo.color = getTrackColor(mediatrack)
    table.insert(tracks, trackinfo)
  end
  
  return tracks
  
end -- getTrackInfo
----------------------------------
local function getSends(mediatrack)

  local sendstable = {}
  
  -- First handle the explicit sends
  local numsends = rpr.GetTrackNumSends(mediatrack, GET_SENDS)
  if numsends > 0 then
    for i = 0, numsends-1 do
      local sendstruct = {}
      local targettrack = rpr.GetTrackSendInfo_Value(mediatrack, GET_SENDS, i, "P_DESTTRACK")
      local targetnum = rpr.GetMediaTrackInfo_Value(targettrack, "IP_TRACKNUMBER")
      local srcchan = rpr.GetTrackSendInfo_Value(mediatrack, GET_SENDS, i, "I_SRCCHAN")
      local destchan = rpr.GetTrackSendInfo_Value(mediatrack, GET_SENDS, i, "I_DSTCHAN")

      sendstruct.targetnum = math.floor(targetnum)
      sendstruct.srcchan = math.floor(srcchan)
      sendstruct.destchan = math.floor(destchan)
      -- For src and dest channels:
      --    0 means stereo 1/2, 1 means stereo 2/3, 2 means stereo 3/4, etc. So: (srcchan+1)/(srcchan+2)
      -- 1024 means mono 1,  1025 means mono 2,  1026 means mono 3, etc. So: srcchan-1023
      -- -1 for src (dest is 0) means none (so there is a send, but not audio, thus MIDI, check "I_MIDIFLAGS")
      if sendstruct.srcchan == -1 then
        local midichannels = rpr.GetTrackSendInfo_Value(mediatrack, GET_SENDS, i, "I_MIDIFLAGS")
        local midisrc = midichannels&0x1F -- lo 5 bits is src channel, 0=all, else 1-16
        local mididest = (midichannels&0x3E0)>>5 -- next 5 bits are dest chan, 0=orig, else 1-16
        -- These are stored as negative numbers by subtracting 17, which makes -17 mean "all/orig"
        -- -16 mean midi channel 1, -15 midi channel 2 etc
        sendstruct.srcchan = midisrc - 17
        sendstruct.destchan = mididest - 17
      end
      table.insert(sendstable, sendstruct)
    end
  end

  -- Now handle the implicit sends, to parents and the master
  -- The implicit sends have their targettrack num negated to be able to make them hatched
  local parentsend = rpr.GetMediaTrackInfo_Value(mediatrack, "B_MAINSEND") -- returns 0.0 for false, 1.0 for true
  if parentsend > 0 then -- this track sends either to its parent or to the Master
    local sendstruct = {}
    local parenttrack = rpr.GetParentTrack(mediatrack)
    
    if parenttrack ~= nil then -- this track sends to parent, not the Master
      local targetnum = math.floor(rpr.GetMediaTrackInfo_Value(parenttrack, "IP_TRACKNUMBER"))
      sendstruct.targetnum = -targetnum-1 -- since the Master is num -1, we need to make these start 1 step lower
    else -- this track sends to the  master
      sendstruct.targetnum = MASTER_TRACK
    end
    
    sendstruct.srcchan = 0  -- Don't know yet how to get these
    sendstruct.destchan = 0
    table.insert(sendstable, sendstruct)
  end
  
  return sendstable
  
end -- getSends
-----------------------------------
local function writePreamble(fileh)
  
  fileh:write("digraph ")
  local pname = rpr.GetProjectName(0, "")
  if pname == "" then pname = "Unnamed project" end
  DOT_GRAPH = DOT_GRAPH:gsub("_", pname)

  fileh:write("\""..pname.."\" {\n\t"..DOT_GRAPH.."\n\t"..DOT_TSHAPE.."\n\t")

end -- writePreamble
----------------------------------------
local function writeNodes(fileh, tracks)

  for i = #tracks, 1, -1 do
    fileh:write("track"..tracks[i].num.." [label=\""..tracks[i].name.."\" fillcolor=\""..tracks[i].color.."\"]\n\t")
  end
  fileh:write("Master\n\t") -- Last in the line

end -- writeNodes
------------------------------------------
local function writeRouting(fileh, tracks)

  for t = 1, #tracks do
    local mediatrack = tracks[t].mediatrack -- rpr.GetTrack(0, i)
    local tracknum = tracks[t].num

    local sends = getSends(mediatrack)
    for i = 1, #sends do
      local sendstruct = sends[i]
      local sendtrack = "Master"
      local label = ""
   
      if sendstruct.targetnum < 0 then -- implicit send, either to Master or parent
        label = "[style=dashed]" -- implicit sends are denoted by dashed lines, no channels
        if sendstruct.targetnum < -1 then -- handle parent sends that are not to Master
          sendtrack = "track"..-(sendstruct.targetnum+1)
        end
      else -- explicit send, include channels label(s)
        sendtrack =  "track"..sendstruct.targetnum
      label = "["..formatChanLabels(sendstruct.srcchan, sendstruct.destchan).."]"
      end
  
      fileh:write("track"..tracknum.." -> "..sendtrack.." "..label.."\n\t")
    end
  end
  
end -- writeRouting
-------------------------------------------------------------------------
--------------------------------------------------- Open code starts here
local tracks = getTrackInfo()

local fileh = assert(io.open(DOT_OUT..DOT_EXT, "w"), "Error opening file "..DOT_OUT.." for writing")

writePreamble(fileh)
writeNodes(fileh, tracks)
writeRouting(fileh, tracks)

fileh:write("}")
fileh:flush()
fileh:close()

local command =""..DOT_PATH..DOT_CMD..""

local delete_command = "rm "..DOT_OUT..DOT_EXT..""

local open_command = "open "..DOT_OUT.."."..DOT_TYPE..""

-- local osbool, osstr, osint = os.execute(command)

os.execute(command)
os.execute(delete_command)
os.execute(open_command)

reaper.ShowMessageBox("Graphviz path: " .. DOT_PATH .. "\n" ..
                      "Output path: " .. DOT_OUT .. "\n" ..
                      "Output file: " .. DOT_OUT .. "." .. DOT_TYPE .. "\n" ..
                      "Output format: " .. DOT_TYPE .. "\n" ..
                      "Splines: " .. DOT_SPLINES .. "\n" ..
                      "Graph created successfully!", "Graphviz Graph Created", 0)

-- rpr.ShowConsoleMsg(command..", returned "..(osret and "true, " or "false, ")..osstr..", "..osint)


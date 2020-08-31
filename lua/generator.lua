----utility functions
local function save_data(filename,...)
    local file,err = io.open(filename,"w")
    if not file then error(err) end
    for i=1, select('#', ...) do
        local data = select(i, ...)
        file:write(data)
    end
    file:close()
end
----------------------------------------
local function  read_data(filename)
    local hfile,err = io.open(filename,"r")
    if not hfile then error(err) end
    local hstrfile = hfile:read"*a"
    hfile:close()
    return hstrfile
end

--iterates lines from a gcc -E in a specific location
local function location(file,locpathT)
    local location_re = '^# (%d+) "([^"]*)"'
    local path_reT = {}
    for i,locpath in ipairs(locpathT) do
        table.insert(path_reT,'^(.*[\\/])('..locpath..')%.h$')
    end
    local in_location = false
    local which_location = ""
	local loc_num
	local loc_num_incr
	local lineold = "" 
	local which_locationold,loc_num_realold
	local lastdumped = false
    local function location_it()
        repeat
            local line = file:read"*l"
            if not line then
				if not lastdumped then
					lastdumped = true
					return lineold, which_locationold,loc_num_realold
				else
					return nil
				end
			end
            if line:sub(1,1) == "#" then
                -- Is this a location pragma?
                local loc_num_t,location_match = line:match(location_re)
                if location_match then
                    in_location = false
                    for i,path_re in ipairs(path_reT) do
                        if location_match:match(path_re) then 
                            in_location = true;
							loc_num = loc_num_t
							loc_num_incr = 0
                            which_location = locpathT[i]
                            break 
                        end
                    end
                end
            elseif in_location then
				local loc_num_real = loc_num + loc_num_incr
				loc_num_incr = loc_num_incr + 1
				if loc_num_realold and loc_num_realold < loc_num_real then
					--old line complete
					local lineR,which_locationR,loc_num_realR = lineold, which_locationold,loc_num_realold
					lineold, which_locationold,loc_num_realold = line,which_location,loc_num_real
					return lineR,which_locationR,loc_num_realR
				else
					lineold=lineold..line
					which_locationold,loc_num_realold = which_location,loc_num_real
                --return line,loc_num_real, which_location
				end
            end
        until false
    end
    return location_it
end
local struct_re = "^%s*struct%s+([^%s;]+);$"
--------------------------------------------------------
--first cimgui
print"get cimgui cdefs"
local pipe,err = io.popen([[gcc -E -DCIMGUI_DEFINE_ENUMS_AND_STRUCTS ../cimgui/cimgui.h]],"r")
if not pipe then error("could not execute gcc "..err) end

local cdefs = {}
cdefs[1] = "typedef void FILE;"
for line in location(pipe,{"cimgui"}) do
	line = line:gsub("extern __attribute__%(%(dllexport%)%)%s*","")
	line = line:gsub("extern __declspec%(dllexport%)%s*","")
	if line~="" then table.insert(cdefs,line) end
end
pipe:close()

--then cimplot
print"get cimplot cdefs"
local pipe,err = io.popen([[gcc -E -DCIMGUI_DEFINE_ENUMS_AND_STRUCTS ../cimplot/cimplot.h]],"r")
if not pipe then error("could not execute gcc "..err) end
local cdefspl = {}
for line in location(pipe,{"cimplot"}) do
	line = line:gsub("extern __attribute__%(%(dllexport%)%)%s*","")
	line = line:gsub("extern __declspec%(dllexport%)%s*","")
	if line~="" then table.insert(cdefspl,line) end
end
pipe:close()

--then cimguizmo
print"get cimguizmo cdefs"
local pipe,err = io.popen([[gcc -E -DCIMGUI_DEFINE_ENUMS_AND_STRUCTS ../cimguizmo/cimguizmo.h]],"r")
if not pipe then error("could not execute gcc "..err) end
local cdefszmo = {}
for line in location(pipe,{"cimguizmo"}) do
	line = line:gsub("extern __attribute__%(%(dllexport%)%)%s*","")
	line = line:gsub("extern __declspec%(dllexport%)%s*","")
	if line~="" then table.insert(cdefszmo,line) end
end
pipe:close()

--then cimguizmo_quat
print"get cimguizmo_quat cdefs"
local pipe,err = io.popen([[gcc -E -DCIMGUI_DEFINE_ENUMS_AND_STRUCTS ../cimguizmo_quat/cimguizmo_quat.h]],"r")
if not pipe then error("could not execute gcc "..err) end
local cdefszmoquat = {}
for line in location(pipe,{"cimguizmo_quat"}) do
	line = line:gsub("extern __attribute__%(%(dllexport%)%)%s*","")
	line = line:gsub("extern __declspec%(dllexport%)%s*","")
	if line~="" then table.insert(cdefszmoquat,line) end
end
pipe:close()

----- cimgui_impl
print"get cimgui_impl cdefs"
local pipe,err = io.popen([[gcc -E -DCIMGUI_API="" ../cimgui/generator/output/cimgui_impl.h]],"r")
if not pipe then error("could not execute gcc "..err) end

local cdefs_im = {}
for line in location(pipe,{"cimgui_impl"}) do
	line = line:gsub("extern __attribute__%(%(dllexport%)%)%s*","")
	line = line:gsub("extern __declspec%(dllexport%)%s*","")
	if line~="" then table.insert(cdefs_im,line) end
	local stname = line:match(struct_re)
	if  stname then table.insert(cdefs_im,"typedef struct "..stname.." "..stname..";") end
end
pipe:close()

----- create imgui/cdefs.lua
print"save cdefs.lua"
local ini_cdef = "--[[ BEGIN AUTOGENERATED SEGMENT ]]\nlocal cdecl = [[\n"
local str_cdefs = table.concat(cdefs,"\n")
local str_cdefspl = table.concat(cdefspl,"\n")
local str_cdefszmo = table.concat(cdefszmo,"\n")
local str_cdefszmoquat = table.concat(cdefszmoquat,"\n")
local str_cdefs_im = table.concat(cdefs_im,"\n")
local hstrfile = read_data"./imgui_base_cdefs.lua"
save_data("./imgui/cdefs.lua", ini_cdef, str_cdefs,"\n", str_cdefspl,"\n", str_cdefszmo,"\n", str_cdefszmoquat,"\n",str_cdefs_im, "\n]]\n--[[ END AUTOGENERATED SEGMENT ]]\n", hstrfile)

----- generate imgui/glfw.lua
print"save glfw.lua"
local classes = require"class_gen"
local iniclass = "local cimguimodule = 'cimgui_glfw' --set imgui directory location\n"
local base = read_data("./imgui_base.lua")
save_data("./imgui/glfw.lua",iniclass, base, classes)

----- generate imgui/sdl.lua
print"save sdl.lua"
local iniclass = "local cimguimodule = 'cimgui_sdl' --set imgui directory location\n"
save_data("./imgui/sdl.lua",iniclass, base, classes)

print"-----------------------------done generation"
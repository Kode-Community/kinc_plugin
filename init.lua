-- mod-version:2 -- lite-xl 2.0
local core = require "core"
local command = require "core.command"
local keymap = require "core.keymap"
local common = require "core.common"


local function suggest_directory(text)
  text = common.home_expand(text)
  return common.home_encode_list(text == "" and core.recent_projects or common.dir_path_suggest(text))
end

local kinc = {
  path = "Kinc",
  nodePath = "node",
  isKore = true,
  isTerm = false,
  projectName = "New Project"
}

local function endsWith(str,endStr)
  local i = string.len(str)
  local y = string.len(endStr)
  local z = 0
  while(z < y) do
    if str[i-z] ~= endStr[y-z] then 
      break
    end
    z = z + 1
  end
  return z == y
end

local function startsWith(str,startStr)
  local i = string.len(str)
  local y = string.len(startStr)
  if i < y then
    return false
  end
  local z = 0
  while(z < y) do
    if str[z] ~= startStr[z] then 
      break
    end
    z = z + 1
  end
  return z == y
end

local function createFiles()
  local dir_path = core.project_dir .. PATHSEP
  local f = io.open(dir_path .. "kincfile.js","wb")
  
  f:write(string.format("let project = new Project('%s');\n\n",kinc.projectName))
  
  if not kinc.isKore then 
    f:write("project.kore = false;\n")
  end
  
  if kinc.isTerm then 
    f:write("project.setCmd();\n")
  end
  
  f:write("project.addFile('Sources/**');\nproject.setDebugDir('Deployment');\n")
  f:write("resolve(project);")
  
  f:close()
  
  common.mkdirp(dir_path .. "Deployment")
  
  f = io.open(dir_path .. "Deployment" .. PATHSEP .. "keepme","wb")
  f:write("Don't read me, but please keep me.")
  f:close()
  
  common.mkdirp(dir_path .. "Sources")
  
  f = io.open(dir_path .. "Sources" .. PATHSEP .. "main.c","wb")
  
  local main = ""
  if kinc.isKore then
    f:write("#include <kinc/global.h>\n\n")
    main = "kickstart"
  else
    f:write("#include <stdbool.h>\n")
    f:write("#include <stdint.h>\n\n")
    main = "main"
  end
  f:write(string.format("int %s(int argc, char** argv) {\n",main))
  f:write("\treturn 0;\n}\n")
  f:close(f)
  
  local stat = system.get_file_info(dir_path .. ".git")
  if stat and stat.type then
      f = io.open(dir_path .. ".gitignore","wb")
      f:write("build\n")
      f:write("Deployment/**\n")
      f:write("!Deployment/keepme\n")
      f:close()
  end
  
  core.reschedule_project_scan()
  
  local stat = system.get_file_info(dir_path .. ".lite_project.lua")
  if not stat then
    f = io.open(dir_path .. ".lite_project.lua","wb")
    f:write("local core = require \"core\"\nlocal command = require \"core.command\"\n")
    f:write("local keymap = require \"core.keymap\"\nlocal console = require \"plugins.console\"\n\n")
    f:write("command.add(nil, {\n")
    
    --- Default build no compile
    f:write("\t[\"kinc:build-project\"] = function()\n")
    f:write("\t\tcore.log \"Building...\"\n")
    f:write("\t\tconsole.run {\n")
    f:write(string.format("\t\t\tcommand = \"%s %s  \",\n",kinc.nodePath,kinc.path .. PATHSEP .. "make"))
    f:write("\t\t\tfile_pattern = \"(.*):(%d+):(%d+): (.*)$\",\n")
    f:write("\t\t\ton_complete = function() core.reschedule_project_scan() core.log \"Build complete\" end,\n")
    f:write("\t\t}\n\tend,\n")
    
    f:write("\t[\"kinc:compile-project\"] = function()\n")
    f:write("\t\tcore.log \"Building...\"\n")
    f:write("\t\tconsole.run {\n")
    f:write(string.format("\t\t\tcommand = \"%s %s --compile \",\n",kinc.nodePath,kinc.path .. PATHSEP .. "make"))
    f:write("\t\t\tfile_pattern = \"(.*):(%d+):(%d+): (.*)$\",\n")
    f:write("\t\t\ton_complete = function() core.reschedule_project_scan() core.log \"Build complete\" end,\n")
    f:write("\t\t}\n\tend,\n")
    
    f:write("})\n\n")
    
    f:write("keymap.add { [\"ctrl+b\"] = \"kinc:build-project\",[\"ctrl+shift+b\"] = \"kinc:compile-project\" }")
    
    f:close()
    
    core.restart()
  end
end
local function addKincPath(filepath,kincpath)
  local f = io.open(filepath,"a")
  f:write("local kinc = require \"plugins.kinc_plugin\"\n")
  f:write(string.format("kinc.path = \"%s\"",kincpath))
  f:close()
  core.restart()
end
command.add(nil, {
  
  ["kinc:create-kinc-project"] = function()
    core.log "Creating Kinc Project..."
    core.command_view:enter("Project Name", function(name)
      local stat = system.get_file_info(core.project_dir .. PATHSEP .. "kincfile.js")
      if not stat then
        if name ~= "" then
          kinc.projectName = name
        end
        createFiles()
      else
        core.log "Project already contains a kincfile.js ergo it already is a Kinc Project"
      end
    end)
  end,
  
  --- A kincmake project is a non-kinc based project
  ["kinc:create-kincmake-project"] = function()
    core.log "Creating kincmake based Project..."
    core.command_view:enter("Project Name", function(name)
      local stat = system.get_file_info(core.project_dir .. PATHSEP .. "kincfile.js")
      if not stat then
        if name ~= "" then
          kinc.projectName = name
        end
        core.command_view:enter("Is Terminal Application ? (i.e. 0 or 1)", function(choice)
          kinc.isKore = false
          if choice == "1" then 
            kinc.isTerm = true
          end
          createFiles()
        end)
      else
        core.log "Project already contains a kincfile.js ergo it already is a kincmake Project"
      end
    end)
  end,
  
  ["kinc:set-global-kinc-folder"] = function()
    local dir_path = core.project_dir .. PATHSEP
    local user_filename = system.absolute_path(USERDIR .. PATHSEP .. "init.lua")
    core.command_view:enter("Set Global Kinc Folder", function(text, item)
      text = item and item.text or text
      local isLocal = dir_path .. "Kinc" ~= text
      if endsWith(text,PATHSEP .. "Kinc") and isLocal then
        addKincPath(user_filename,text)
      else
        if isLocal then
          core.log "Path doesn't end with Kinc, make sure you are passing a the path to Kinc"
        else
          core.log "Can't set current Project Kinc folder as global Kinc folder"
        end
      end 
    end,suggest_directory)
  end,
  
  ["kinc:set-current-project-kinc-folder"] = function()
    local dir_path = core.project_dir .. PATHSEP
    core.command_view:enter("Set Current Project's Kinc Folder", function(text, item)
      text = item and item.text or text
      local stat = system.get_file_info(dir_path .. ".lite_project.lua")
      if stat and stat.type then
        if endsWith(text,PATHSEP .. "Kinc") and startsWith(core.project_dir,text) then
          addKincPath(dir_path .. ".lite_project.lua",text)
        else
          core.log "Path doesn't end with Kinc or isn't a directory in current project"
        end
      else 
        core.log "No project module created for current project"
      end
    end,suggest_directory)
  end,
})

keymap.add { 
  ["ctrl+k"] = "kinc:create-kinc-project",
  ["ctrl+alt+k"] = "kinc:create-kincmake-project", 
}

return kinc

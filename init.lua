-- mod-version:3 -- lite-xl 2.1
local core = require "core"
local command = require "core.command"
local keymap = require "core.keymap"
local common = require "core.common"


local noop = function() end

local function suggest_directory(text)
  text = common.home_expand(text)
  return common.home_encode_list(text == "" and core.recent_projects or common.dir_path_suggest(text))
end

local tmp = ""
if PLATFORM:find("Windows") then
  tmp = ".bat"
else
  tmp =".sh"
end
local kinc = {
  path = "./Kinc",
  script_ext = tmp,
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
  local f = io.open(dir_path .. "kfile.js","wb")
  
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
  local make_path = ""
  if not kinc.isKore then
    make_path = "." --- Default to kmake being at the root
    f = io.open(dir_path .. "make" .. kinc.script_ext,"wb")
    if PLATFORM:find("Windows") then
      f:write([[
      @if exist "%~dp0Tools\windows_x64\kmake.exe" (
        @call "%~dp0Tools\windows_x64\kmake.exe" %*
      ) else (
        echo kmake was not found, please run the get_dlc script.
      ) ]] )
    else
      f:write(
[[ #!/usr/bin/env bash

. `dirname "$0"`/Tools/platform.sh
MAKE="`dirname "$0"`/Tools/$KINC_PLATFORM/kmake$KINC_EXE_SUFFIX"

if [ -f "$MAKE" ]; then
  exec $MAKE "$@"
else 
  echo "kmake was not found, please run the get_dlc script."
  exit 1
fi]])
      f = io.open(dir_path .. "Tools/platform" .. kinc.script_ext,"wb")
      f:write('if [[ "$OSTYPE" == "linux-gnu"* ]]; then\n')
      f:write("  MACHINE_TYPE=`uname -m`\n")
      f:write('  if [[ "$MACHINE_TYPE" == "armv"* ]]; then\n')
      f:write('    KINC_PLATFORM=linux_arm\n')
      f:write('  elif [[ "$MACHINE_TYPE" == "aarch64"* ]]; then\n')
      f:write('    KINC_PLATFORM=linux_arm64\n')
      f:write('  elif [[ "$MACHINE_TYPE" == "x86_64"* ]]; then\n')
      f:write('    KINC_PLATFORM=linux_x64\n')
      f:write('  else\n')
      f:write([[ echo "Unknown Linux machine '$MACHINE_TYPE', please edit Tools/platform.sh"\n]])
      f:write('    exit 1\n')
      f:write('  fi\n')
      f:write('  elif [[ "$OSTYPE" == "darwin"* ]]; then\n')
      f:write('    KINC_PLATFORM=macos\n')
      f:write('  elif [[ "$OSTYPE" == "FreeBSD"* ]]; then\n')
      f:write('    KINC_PLATFORM=freebsd_x64\n')
      f:write('  elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then\n')
      f:write('    KINC_PLATFORM=windows_x64\n')
      f:write('    KINC_EXE_SUFFIX=.exe\n')
      f:write('  else\n')
      f:write([[ echo "Unknown platform '$OSTYPE', please edit Tools/platform.sh" \n]])
      f:write('  exit 1\n')
      f:write('fi\n')
   end
  else
    make_path = kinc.path
  end
  
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
    f:write(string.format("\t\t\tcommand = \"%s  \",\n",kinc.path .. PATHSEP .. "make" .. kinc.script_ext))
    f:write("\t\t\tfile_pattern = \"(.*):(%d+):(%d+): (.*)$\",\n")
    f:write("\t\t\ton_complete = function() core.log \"Build complete\" end,\n")
    f:write("\t\t}\n\tend,\n")
    
    f:write("\t[\"kinc:compile-project\"] = function()\n")
    f:write("\t\tcore.log \"Building...\"\n")
    f:write("\t\tconsole.run {\n")
    f:write(string.format("\t\t\tcommand = \"%s --compile \",\n",kinc.path .. PATHSEP .. "make" .. kinc.script_ext))
    f:write("\t\t\tfile_pattern = \"(.*):(%d+):(%d+): (.*)$\",\n")
    f:write("\t\t\ton_complete = function() core.log \"Build complete\" end,\n")
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
    core.command_view:enter("Project Name",
    { submit = function(name)
        local stat = system.get_file_info(core.project_dir .. PATHSEP .. "kfile.js")
        if not stat then
          if name ~= "" then
            kinc.projectName = name
          end
          createFiles()
        else
          core.log "Project already contains a kfile.js ergo it already is a Kinc Project"
        end
      end})
  end,
  
  --- A kmake project is a non-kinc based project
  ["kinc:create-kmake-project"] = function()
    core.log "Creating kmake based Project..."
    core.command_view:enter("Project Name",{
     submit = function(name)
      local stat = system.get_file_info(core.project_dir .. PATHSEP .. "kfile.js")
      if not stat then
        if name ~= "" then
          kinc.projectName = name
        end
        core.command_view:enter("Is Terminal Application ? (i.e. 0 or 1)",{ 
                                submit = function(choice)
                                    kinc.isKore = false
                                    if choice == "1" then 
                                      kinc.isTerm = true
                                    end
                                    createFiles()
                                  end,
                                suggest = noop,
                                cancel = noop,
                                validate = function() return true end,
                                text = "",
                                select_text = false,
                                show_suggestions = true,
                                typeahead = true,
                                wrap = true,})
    else
      core.log "Project already contains a kfile.js ergo it already is a Kinc or Kmake Project"
    end
  end,
  suggest = noop,
  cancel = noop,
  validate = function() return true end,
  text = "",
  select_text = false,
  show_suggestions = true,
  typeahead = true,
  wrap = true,
  })
  end, --- END "kinc:create-kmake-project"
  
  ["kinc:set-global-kinc-folder"] = function()
    local dir_path = core.project_dir .. PATHSEP
    local user_filename = system.absolute_path(USERDIR .. PATHSEP .. "init.lua")
    core.command_view:enter("Set Global Kinc Folder",{
    submit = function(text, item)
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
          return false
        end 
      end,
    suggest = suggest_directory,
    cancel = noop,
    validate = function() return true end,
    text = "",
    select_text = false,
    show_suggestions = true,
    typeahead = true,
    wrap = true,
    })
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
  ["ctrl+alt+k"] = "kinc:create-kmake-project", 
}

return kinc

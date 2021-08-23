local core = require "core"
local command = require "core.command"
local keymap = require "core.keymap"
local common = require "core.common"

local kinc = {
  path = "Kinc",
  nodePath = "node",
  isKore = true,
  isTerm = false,
  projectName = "New Project"
}

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
    f:write("\t\t\ton_complete = function() core.log \"Build complete\" end,\n")
    f:write("\t\t}\n\tend,\n")
    
    f:write("\t[\"kinc:compile-project\"] = function()\n")
    f:write("\t\tcore.log \"Building...\"\n")
    f:write("\t\tconsole.run {\n")
    f:write(string.format("\t\t\tcommand = \"%s %s --compile \",\n",kinc.nodePath,kinc.path .. PATHSEP .. "make"))
    f:write("\t\t\tfile_pattern = \"(.*):(%d+):(%d+): (.*)$\",\n")
    f:write("\t\t\ton_complete = function() core.log \"Build complete\" end,\n")
    f:write("\t\t}\n\tend,\n")
    
    f:write("})\n\n")
    
    f:write("keymap.add { [\"ctrl+b\"] = \"kinc:build-project\",[\"ctrl+shift+b\"] = \"kinc:compile-project\" }")
    
    f:close()
    
    core.restart()
  end
end

command.add(nil, {
  
  ["kinc:create-kinc-project"] = function()
    core.log "Creating Kinc Project..."
    core.command_view:enter("Project Name", function(name)
      if name ~= "" then
        kinc.projectName = name
      end
      createFiles()
    end)
  end,
  
  --- A kincmake project is a non-kinc based project
  ["kinc:create-kincmake-project"] = function()
    core.log "Creating kincmake based Project..."
    core.command_view:enter("Project Name", function(name)
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
    end)
  end,
  
})

keymap.add { 
  ["ctrl+k"] = "kinc:create-kinc-project",
  ["ctrl+alt+k"] = "kinc:create-kincmake-project", 
}

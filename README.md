# Kinc Projects
A [Kinc](https://github.com/Kode/Kinc) project manager for the [lite xl text editor](https://github.com/lite-xl/lite-xl)


## Install
Navigate to the `data/plugins` folder and run the following command:
```bash
git clone https://github.com/Kode-Community/kinc_projects.git
```
Alternatively the `init.lua` file can be renamed `kinc_projects.lua` and dropped in
the `data/plugins` folder.

## Basic Usage
A basic Kinc project can be created by using the `kinc:create-kinc-project` command
(`ctrl+k`). Alternatively, you can create a basic C program that uses kincmake as it's
 build system by using the `kinc:create-kincmake-project` command (`ctrl+alt+k`).
 
## Advanced concepts
Project generation defaults to Kinc being local to the project i.e. `YourProjectDir/Kinc`
To set the Kinc path globally use the command `Kinc:Set Global Kinc folder`. If your Kinc folder isn't at the root of your project directory you can set
your local Kinc path with the command `Kinc:Set Current Project Kinc folder`.
These commands respectivaly modify the User Module or the Current Project Module. Since the Project Module is loaded after the User Module,
if the project module sets a Kinc path it will take precedence over the global one. 
When a project gets created we add build(`ctrl+b`) and compile(`ctrl+shift+b`) commands in a `.lite_project.lua`
file that you can configure by using the `Core:Open Project Module` command.
These build commands depend on the [console](https://github.com/franko/console) plugin. 

## License
This project is free software; you can redistribute it and/or modify it under
the terms of the zlib license. See [LICENSE](LICENSE) for details.



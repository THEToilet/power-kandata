@echo off
rem Open this project in the Godot editor.
rem Put the full path to your Godot 4.6.3 executable in godot_path.txt (one line, not committed to git).
rem If that file does not exist, "godot" on PATH is used.
set "GODOT=godot"
if exist "%~dp0godot_path.txt" set /p GODOT=<"%~dp0godot_path.txt"
"%GODOT%" -e --path "%~dp0."

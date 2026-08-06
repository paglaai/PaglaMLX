-- Pagla Launcher (AppleScript)
-- Pre-Flight Check & App Launcher

-- derive paths relative to this script's location
set scriptDir to POSIX path of (path to me)
set scriptPath to scriptDir & "preflight_check.sh"
set appPath to scriptDir & ".build/debug/PaglaMLX"

try
	-- Run the pre-flight bash script
	do shell script "'" & scriptPath & "'"
	
	-- If it succeeds (exit 0), launch the Swift application in the background
	do shell script "'" & appPath & "' > /dev/null 2>&1 &"
	
on error
	-- If it fails (exit 1), show error
	display dialog "External storage not mounted!" & return & return & "Please mount the external drive with your MLX models before launching." buttons {"Cancel", "Retry"} default button "Retry" with title "PaglaMLX Launcher" with icon caution
	
	if button returned of result is "Retry" then
		run
	end if
end try

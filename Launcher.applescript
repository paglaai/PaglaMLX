-- Pagla Launcher (AppleScript)
-- Agentic Pre-Flight Check & App Launcher

set scriptPath to "/Users/aynaghor/KH3L4-GH0R/APPH0LE/CastingC0UCH/preflight_check.sh"
set appPath to "/Users/aynaghor/KH3L4-GH0R/APPH0LE/PaglaMLX/.build/debug/PaglaMLX"

try
	-- Run the pre-flight bash script
	do shell script "'" & scriptPath & "'"
	
	-- If it succeeds (exit 0), launch the Swift application in the background
	do shell script "'" & appPath & "' > /dev/null 2>&1 &"
	
on error
	-- If it fails (exit 1), it means the USB is unplugged or something is critically wrong
	display dialog "CastingC0UCH USB Warehouse is not mounted!" & return & return & "Please plug in the external drive to access your MLX models. The application cannot start." buttons {"Cancel", "I plugged it in, retry"} default button "I plugged it in, retry" with title "PaglaMLX Pre-Flight Error" with icon caution
	
	if button returned of result is "I plugged it in, retry" then
		-- Retry recursively
		run
	end if
end try

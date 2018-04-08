#include <Date.au3>
#include <GUIConstantsEx.au3>
#include <ColorConstants.au3>
#include <MsgBoxConstants.au3>
#include <Array.au3>
#include <ScreenCapture.au3>


Opt("SendKeyDownDelay", 150)
Opt("GUIOnEventMode", 1) ; Change to OnEvent mode

HotKeySet ("{INSERT}","TogglePause")
HotKeySet ("{END}","ends")
HotKeySet ("!b","storeBankerCoords")				; Alt + b
HotKeySet ("!a","storeAnvilCoords")					; Alt + a
HotKeySet ("!p","storePortableCoords")				; Alt + p
HotKeySet ("!c","storeCoalBagCoords")				; Alt + c
HotKeySet ("{F2}","setAllCheckpoints")


; Alter Settings
Global Const $loadoutNumber = "1"
Global Const $load_size = 11
Global Const $runtime = 2000
Global $smithtime = 26100
Global $lag = 0

; Window Derived Identifiers
Global Const $windowName = 'RuneScape'
Global Const $rsWindowHandle = WinActive($windowName)

; Stored Settings
Global $Paused = False
Global $ignoreForge = False
Global $stopAfterForge = False
Global $safeClick = False
Global $last_forge_time = Null
Global $cycle_start_time = Null
Global $bars_to_produce = 9999

; Stored Pixel Settings
Global $BANK_OPEN_PIXEL = 724751
Global $BANK_CLOSED_PIXEL = 2568754
Global $PORTABLE_CAN_CONFIRM_PIXEL = 12823946
Global $START_SMITH_WINDOW_PIXEL = 15444523
Global $EMPTY_FORGE_ITEM_SLOT_PIXEL = 728100

; Stored Pixel Coordinates
Global $BANK_OPEN[2] = [1261, 650]
Global $BANK_CLOSED[2] = [1261, 650]
Global $PORTABLE_CAN_CONFIRM[2] = [510, 708]
Global $START_SMITH_WINDOW[2] = [909, 350]
Global $EMPTY_FORGE_ITEM_SLOT[2] = [1230,593]

; Coordinates
Global $anvil_coord[2][3]
Global $banker_coord[2][3]
Global $portable_coord[2][3] = [[True, 1232-17, 586-10], [False, 1232+17, 586+10]]
Global $coalBag_coord[2][3] = [[True, 850-8, 215-8], [False, 850+8, 215+8]]


; Metrics
Global $trip_limit = $bars_to_produce / $load_size
Global $completed_trips = 0
Global $cycleTime = 0


; Sets Up GUI
Local $gui_width = 200
Local $gui_height = 275
Global $hMainGUI = GUICreate("Smelt v2.0", $gui_width, $gui_height)
WinSetOnTop ($hMainGUI, "", 1)

;; GUI Lables and Buttons ;;
; Coordinates
GUICtrlCreateLabel("Banker: ", 5, 10)
Local $id_bankerCoord = GUICtrlCreateLabel(stringifyCoord($banker_coord), 60, 10, $gui_width)
GUICtrlCreateLabel("Anvil: ", 5, 25)
Local $id_anvilCoord = GUICtrlCreateLabel(stringifyCoord($anvil_coord), 60, 25, $gui_width)
GUICtrlCreateLabel("Portable: ", 5, 40)
Local $id_portableCoord = GUICtrlCreateLabel(stringifyCoord($portable_coord), 60, 40, $gui_width)
GUICtrlCreateLabel("CoalBag: ", 5, 55)
Local $id_coalBagCoord = GUICtrlCreateLabel(stringifyCoord($coalBag_coord), 60, 55, $gui_width)

; Modifiable Delays
GUICtrlCreateLabel("Smith Time: ", 5, 75)
Local $label_smithTime = GUICtrlCreateLabel('', 70, 75, 50, Null)
Local $button_decSmithTime = GUICtrlCreateButton("\/", 110, 73, 20, 15)
Local $button_incSmithTime = GUICtrlCreateButton("/\", 130, 73, 20, 15)
GUICtrlSetData($label_smithTime, $smithtime)
GUICtrlCreateLabel("Lag Time: ", 5, 90)
Local $label_lagTime = GUICtrlCreateLabel('', 70, 90, 50, Null)
Local $button_decLagTime = GUICtrlCreateButton("\/", 110, 88, 20, 15)
Local $button_incLagTime = GUICtrlCreateButton("/\", 130, 88, 20, 15)
GUICtrlSetData($label_lagTime, $lag)

; Metrics
GUICtrlCreateLabel("Bars Done", 5, 130)
Local $label_barsDone = GUICtrlCreateLabel(Null, 70, 130, 30, 15)
GUICtrlCreateLabel("/", 100, 130, 10, 15)
Local $label_barsTotal = GUICtrlCreateLabel(Null, 110, 130, 40, 15)
Local $button_changeBarsTotal = GUICtrlCreateButton("+", 150, 130, 18, 15)
GUICtrlCreateLabel("Forge Time", 5, 145, 65, 15)
Local $label_forgeTime = GUICtrlCreateLabel(1234, 70, 145)
GUICtrlCreateLabel("Cycle Time", 5, 160, 65, 15)
Local $label_cycleTime = GUICtrlCreateLabel(1234, 70, 160)

; Button Settings
Local $button_ignoreForge = GUICtrlCreateButton("Ignore Forges", 0, $gui_height-80, $gui_width/2, 25)
GUICtrlSetBkColor($button_ignoreForge, $COLOR_RED)
;Local $button_setCheckpoints = GUICtrlCreateButton("Top Right", $gui_width/2, $gui_height-80, $gui_width/2, 25)
;GUICtrlSetBkColor($button_setCheckpoints, $COLOR_RED)
Local $button_stopAfterForge = GUICtrlCreateButton("Stop After Forge", 0, $gui_height-55, $gui_width/2, 25)
GUICtrlSetBkColor($button_stopAfterForge, $COLOR_RED)
Local $button_toggleSafeClick = GUICtrlCreateButton("Safe Click", $gui_width/2, $gui_height-55, $gui_width/2, 25)
GUICtrlSetBkColor($button_toggleSafeClick, $COLOR_RED)
Local $button_togglePause = GUICtrlCreateButton("SCRIPT IN ACTION", 0, $gui_height-30, $gui_width, 30)
GUICtrlSetBkColor($button_togglePause, $COLOR_RED)

; GUI Listeners
GUICtrlSetOnEvent($button_ignoreForge, "gui_ignoreForge")
GUICtrlSetOnEvent($button_stopAfterForge, "gui_stopAfterForge")
GUICtrlSetOnEvent($button_toggleSafeClick, "gui_toggleSafeClick")
GUICtrlSetOnEvent($button_incSmithTime, "gui_incSmithTime")
GUICtrlSetOnEvent($button_decSmithTime, "gui_decSmithTime")
GUICtrlSetOnEvent($button_incLagTime, "gui_incLagTime")
GUICtrlSetOnEvent($button_decLagTime, "gui_decLagTime")
GUICtrlSetOnEvent($button_changeBarsTotal, "gui_changeBarsTotal")
GUISetOnEvent($GUI_EVENT_CLOSE, "ends")
; Shows GUI1
GUISetState(@SW_SHOW, $hMainGUI)




;; Begins ;;
TogglePause()

;; Essential Global Functions ;;
Func TogglePause()
   $Paused = NOT $Paused
   If($Paused) Then
	  GUICtrlSetBkColor($button_togglePause, $COLOR_RED)
   EndIf

   While $Paused
	  Sleep(100)
   WEnd

   GUICtrlSetBkColor($button_togglePause, $COLOR_GREEN)
EndFunc

Func ends()
	Exit
 EndFunc


;; Helper Methods ;;
Func _coordFromRange($coordRangeObject)
   Local $chosenCoord[2]
   $chosenCoord[0] = Random(_ArrayMin($coordRangeObject, 1, 0, 1, 1), _ArrayMax($coordRangeObject, 1, 0, 1, 1), 1)
   $chosenCoord[1] = Random(_ArrayMin($coordRangeObject, 1, 0, 1, 2), _ArrayMax($coordRangeObject, 1, 0, 1, 2), 1)
   Return $chosenCoord
EndFunc

Func safeClick($button, $coord, $type = 'exact')
   Local $MOUSE_MOVE_SPEED = Random(2, 8, 1)
   If($button <> 'left' and $button <> 'right') Then
	  ConsoleWrite("FUNC safeClick: Improper value for $button. ["&$button&"] given. Left or right expected." & @LF)
	  ends()
   EndIf
   ; Modifies Coordinates By Type
   If($type == 'exact') Then
	  ; Do nothing
   ElseIf($type == 'range') Then
	  $coord = _coordFromRange($coord)
   Else
	  $coord = _coord($coord, $type)
   EndIf
   ; Ensures Window Is Active
   If($safeClick) Then
	  While NOT WinActive($windowName)
		 Sleep(300)
		 GUICtrlSetColor($button_toggleSafeClick, $COLOR_WHITE)
		 Sleep(300)
		 GUICtrlSetColor($button_toggleSafeClick, $COLOR_BLACK)
	  WEnd
   EndIf
   MouseClick($button, $coord[0], $coord[1], 1, $MOUSE_MOVE_SPEED)
   Local $temp = [$coord[0], $coord[1]]
   Return $temp
EndFunc

; Accessed using 1: firstOption, 2: secondOption...
Func _dropDownMenu($base, $drilldownSelection)
   Local $firstClick_coords[2]
   Local $secondClick_coords[2]
   Local $clickType

   ; Makes Initial Right Click
   $firstClick_coords = safeClick('right', $base, 'range')

   ; Delay Between Clicks
   Sleep(200 + $lag/2 + Random(0, 300+$lag/4, 1))

   $secondClick_coords[0] = $firstClick_coords[0] + Random(-40, 40, 1)
   $secondClick_coords[1] = $firstClick_coords[1] + 20 - 8 + ($drilldownSelection * 16) + Random(-1 * 4, 4, 1)

   ; Clicks Option
   safeClick('left', $secondClick_coords, 'exact')
EndFunc


 ;; Main GUI Functions ;;
Func gui_ignoreForge()
   $ignoreForge = NOT $ignoreForge
   If($ignoreForge) Then
	  GUICtrlSetBkColor($button_ignoreForge, $COLOR_GREEN)
   Else
	  GUICtrlSetBkColor($button_ignoreForge, $COLOR_RED)
   EndIf
   WinActivate($windowName)
EndFunc

Func gui_stopAfterForge()
   $stopAfterForge = NOT $stopAfterForge
   If($stopAfterForge) Then
	  GUICtrlSetBkColor($button_stopAfterForge, $COLOR_GREEN)
   Else
	  GUICtrlSetBkColor($button_stopAfterForge, $COLOR_RED)
   EndIf
   WinActivate($windowName)
EndFunc

Func gui_toggleSafeClick()
   $safeClick = NOT $safeClick
   If($safeClick) Then
	  GUICtrlSetBkColor($button_toggleSafeClick, $COLOR_GREEN)
   Else
	  GUICtrlSetBkColor($button_toggleSafeClick, $COLOR_RED)
   EndIf
   WinActivate($windowName)
EndFunc

Func gui_incSmithTime()
   $smithTime = $smithTime + 100
   GUICtrlSetData($label_smithTime, $smithtime)
   WinActivate($windowName)
EndFunc

Func gui_decSmithTime()
   $smithTime = $smithTime - 100
   GUICtrlSetData($label_smithTime, $smithtime)
   WinActivate($windowName)
EndFunc

Func gui_incLagTime()
   $lag = $lag + 100
   GUICtrlSetData($label_lagTime, $lag)
   WinActivate($windowName)
EndFunc

Func gui_decLagTime()
   If($lag >= 100) Then
	  $lag = $lag - 100
   EndIf
   GUICtrlSetData($label_lagTime, $lag)
   WinActivate($windowName)
EndFunc

Func gui_changeBarsTotal()
   $inputData = InputBox("Bars", "How many bars are you making?", '', '', 200, 150)
   ; Removes ALL Spaces - (3)for leading and trailing only
   If(Execute(StringStripWS($inputData, 8)) == "") Then
	  Return
   EndIf
   $bars_to_produce = Execute($inputData)
   $trip_limit = $bars_to_produce / $load_size
   $completed_trips = 0
   GUICtrlSetData($label_barsDone, 0)
   GUICtrlSetData($label_barsTotal, $bars_to_produce)
   WinActivate($windowName)
EndFunc


;; Store Coordinates ;;
Func stringifyCoord($coords)
   Local $stringified = ""
   ; Looks at First Coord
   If($coords[0][1] == '' Or $coords[0][2] == '') Then
	  $stringified = $stringified & 'NONE'
   Else
	  $stringified = $stringified & $coords[0][1] & "," & $coords[0][2]
   EndIf
   $stringified = $stringified & "   --   "
   ; Looks at Second Coord
   If($coords[1][1] == '' Or $coords[1][2] == '') Then
	  $stringified = $stringified & 'NONE'
   Else
	  $stringified = $stringified & $coords[1][1] & "," & $coords[1][2]
   EndIf
   Return $stringified
EndFunc

Func storeBankerCoords()
   setCoord($banker_coord, MouseGetPos())
   GUICtrlSetData($id_bankerCoord, stringifyCoord($banker_coord))
EndFunc

Func storeAnvilCoords()
   setCoord($anvil_coord, MouseGetPos())
   GUICtrlSetData($id_anvilCoord, stringifyCoord($anvil_coord))
EndFunc

Func storePortableCoords()
   setCoord($portable_coord, MouseGetPos())
   GUICtrlSetData($id_portableCoord, stringifyCoord($portable_coord))
EndFunc

Func storeCoalBagCoords()
   setCoord($coalBag_coord, MouseGetPos())
   GUICtrlSetData($id_coalBagCoord, stringifyCoord($coalBag_coord))
EndFunc

Func setCoord(ByRef $coordName, $coord, $coordNumber=-1)
   ; New Coordinate
   If($coordName[0][0]=='' or $coordName[1][0]=='') Then
	  $coordName[0][0] = True
	  $coordName[1][0] = False
   EndIf
   If($coordNumber == -1) Then												; Not set by calling function
	  If($coordName[0][0] == True) Then										; First coord wants to be set next or never set
		 $coordNumber = 0													; Set first coord
	  Else
		 $coordNumber = 1													; Set second coord
	  EndIf
   EndIf
   $coordName[$coordNumber][1] = $coord[0]									; Sets coordinate
   $coordName[$coordNumber][2] = $coord[1]									; Sets coordinate
   $coordName[0][0] = NOT $coordName[0][0]
   $coordName[1][0] = NOT $coordName[1][0]
EndFunc

;; Sets Pixels ;;
Func setAllCheckpoints()
   HotKeySet ("{F3}", "setReadyToAssignCheckpoint")
   HotKeySet ("{F4}", "skipCheckpoint")
   Local Const $INTER_STEP_SLEEP = 100
   Global $READY_TO_SET_CHECKPOINT = False
   Global $MOVE_ON = False

   ; Set Bank Closed ;
   setCheckpointTooltip("Bank Is Closed", "Ideally a pixel that changes from dark/light on bank open/close.")
   setWaitInfo($BANK_CLOSED, $BANK_CLOSED_PIXEL)

   ; Set Bank Open ;
   setCheckpointTooltip("Bank Is Open", "Ideally a pixel that changes from dark/light on bank open/close.")
   setWaitInfo($BANK_OPEN, $BANK_OPEN_PIXEL)

   ; Set Portable NOT In Inventory ;
   setCheckpointTooltip("Portable Is NOT In Inventory", "An inventory pixel where the portable would usually appear.")
   setWaitInfo($EMPTY_FORGE_ITEM_SLOT, $EMPTY_FORGE_ITEM_SLOT_PIXEL)

   ; Set Smith Window Open ;
   setCheckpointTooltip("Portable Setup Confirmation Window Is Shown", "Ideally a pixel not inside chat box.")
   setWaitInfo($PORTABLE_CAN_CONFIRM, $PORTABLE_CAN_CONFIRM_PIXEL)

   ; Set Portable Confirm Section ;
   setCheckpointTooltip("Smith Window Has Popped Up", "A pixel inside the window that lets you confirm smithing.")
   setWaitInfo($START_SMITH_WINDOW, $START_SMITH_WINDOW_PIXEL)

   ToolTip("Everything has been setup!")
   Sleep(1300)
   ToolTip("")
   Return
EndFunc

Func setCheckpointTooltip($name, $description = "")
   ToolTip("Press F3 to set: [" & $name & "]" & @LF & $description & @LF & "Press F4 to skip this checkpoint.", 0, 0, "Checkpoint Setup Wizard")
   ; Waits Before Setting and Moving On ;
   While $MOVE_ON == False
	  Sleep(100)
   WEnd
EndFunc

Func setReadyToAssignCheckpoint()
   $MOVE_ON = True
   $READY_TO_SET_CHECKPOINT = True
EndFunc
Func skipCheckpoint()
   $MOVE_ON = True
   $READY_TO_SET_CHECKPOINT = False
EndFunc

Func setWaitInfo(ByRef $coordsToSet, ByRef $pixelToSet)
   If($READY_TO_SET_CHECKPOINT == False) Then
	  $MOVE_ON = False
	  Return
   EndIf

   Local Const $CLEAR_PIXEL_DELAY = 300
   $coordsToSet = MouseGetPos()
   If($pixelToSet <> null) Then
	  MouseMove(0, 0, 0)
	  Sleep($CLEAR_PIXEL_DELAY + $lag/2)
	  $pixelToSet = PixelGetColor($coordsToSet[0], $coordsToSet[1])
	  MouseMove($coordsToSet[0], $coordsToSet[1], 0)
   EndIf
   $READY_TO_SET_CHECKPOINT = False
   $MOVE_ON = False
EndFunc




;; Waiting Functions ;;
Func wait_bankClosed($_wait)
   $wait =  $_wait
   $after = Random(0, $lag/2, 1)
   $pixel = $BANK_CLOSED_PIXEL
   $coord = $BANK_CLOSED
   ConsoleWrite("Waiting for bank to close...")
   Return waitOrPixel($wait, $pixel, $coord, $after)
EndFunc

Func wait_bankOpen($_wait)
   $wait =  $_wait
   $after = Random(0, $lag/2, 1)
   $pixel = $BANK_OPEN_PIXEL
   $coord = $BANK_OPEN
   ConsoleWrite("Waiting for bank to open...")
   Return waitOrPixel($wait, $pixel, $coord)
EndFunc

Func wait_portableConfirm($_wait)
   $wait = $_wait
   $after = Random(200, 400+$lag/2, 1) ;250
   $pixel = $PORTABLE_CAN_CONFIRM_PIXEL
   $coord = $PORTABLE_CAN_CONFIRM
   ConsoleWrite("Waiting for portable 1/2 options...")
   Return waitOrPixel($wait, $pixel, $coord, $after)
EndFunc

Func wait_startSmithWindow($_wait)
   $wait = $_wait
   $extra = Random(0, $lag/2, 1)
   $pixel = $START_SMITH_WINDOW_PIXEL
   $coord = $START_SMITH_WINDOW
   ConsoleWrite("Waiting for smith window...")
   Return waitOrPixel($wait, $pixel, $coord, $extra)
EndFunc

Func wait_usedForge($_wait)
   $wait = $_wait
   $after = Random(0, $lag/2, 1)
   $pixel = $EMPTY_FORGE_ITEM_SLOT_PIXEL
   $coord = $EMPTY_FORGE_ITEM_SLOT
   ConsoleWrite("Waiting for forge to leave inventory...")
   Return waitOrPixel($wait, $pixel, $coord, $after)
EndFunc

Func waitOrPixel($wait, $pixel, $coord, $extraWait = 0)
   Local $timeSlept = 0
   While $timeSlept <= $wait
	  Sleep(100)
	  $timeSlept = $timeSlept + 100
	  Local $found = PixelSearch($coord[0]-1, $coord[1]-1, $coord[0]+1, $coord[1]+1, $pixel, 2)
	  If NOT @error Then
		 ; Found Coordinate
		 ConsoleWrite("Success" & @LF)
		 If($extraWait > 0) Then
			Sleep($extraWait)
		 EndIf
		 Return True
	  EndIf
   WEnd
   ConsoleWrite("TIMEOUT" & @LF)
   Return False
EndFunc


;; Forge and Timing ;;
Func getRemainingForgeTime()
   If($last_forge_time == Null) Then
	  ; Juuuuust started the script
	  Return -9999
   Else
	  ; Time Remaining
	  Local $timeRemaining = 2 + 5*60 - _DateDiff('s', $last_forge_time, _NowCalc())
	  GUICtrlSetData($label_forgeTime, $timeRemaining)
	  Return $timeRemaining
   EndIf
EndFunc

Func doCheckAndErectForge()
   Local $timeLeft = getRemainingForgeTime()
   If($ignoreForge) Then
	  Return False
   ElseIf($timeLeft < 0) Then
	  Return doPlaceNewForge()
   ElseIf($timeLeft >= 0 and $timeLeft <= 3) Then
	  ; Wait for Forge to Expire
	  Sleep($timeLeft * 1000)
	  ; Accounts for Rounding Errors from Seconds
	  Sleep(10000 + Random(0, 200, 1))
	  Return doPlaceNewForge()
   ElseIf ($timeLeft > 3 and $timeLeft <= $cycleTime * 1.4) Then
	  Return doRenewForge()
   Else
	  Return False
   EndIf
EndFunc

Func doPlaceNewForge()
   If($stopAfterForge) Then
	  TogglePause()
	  Return False
   EndIf
   ConsoleWrite("Trying To: PLACE NEW FORGE" & @LF)
   WinWaitActive($windowName)
   Local $success = False
   Local $tries = 0
   Do
	  $tries = $tries + 1
	  ConsoleWrite("Attempt #" & $tries & @LF)
		 ; Click inventory slot
		 safeClick('left', $portable_coord, 'range')
		 If(wait_portableConfirm(2300 + $lag)) Then
			; Press 1 to confirm construction
			Send($loadoutNumber)
			$success = wait_usedForge(2000)
		 EndIf
   Until ($tries >= 3 or $success)
   If ($success) Then
	  ; Updates forge metrics
	  $last_forge_time = _NowCalc()
	  ; Delay to stop shaking
	  Sleep(1300 + $lag + Random(0, 200, 1))
	  Return True
   Else
	  ConsoleWrite("Error: could not erect forge" & @LF)
	  _ScreenCapture_Capture(@ScriptDir & "\" & @ScriptName&"-screenAtFailure.jpg")
	  TogglePause()
	  Return False
   EndIf
EndFunc

Func doRenewForge()
   If($stopAfterForge) Then
	  Return False
   EndIf
   WinWaitActive($windowName)
   ConsoleWrite("Trying To: EXTEND FORGE DURATION" & @LF)
   Local $success = False
   Local $tries = 0
   Do
	  $tries = $tries + 1
	  ConsoleWrite("Attempt #" & $tries & @LF)
		 _dropDownMenu($portable_coord, 2)
		 Sleep(Random(300, 350, 1))
		 safeClick('left', $anvil_coord, 'range')
		 If(wait_portableConfirm(2300 + $lag)) Then
			Send($loadoutNumber)
			$success = wait_usedForge(2000)
		 EndIf
   Until ($tries >= 3 or $success)
   If ($success) Then
	  Sleep(Random(300, 500, 1))
	  ; Updates forge metrics
	  $last_forge_time = _DateAdd('s', 5*60-1, $last_forge_time)
	  Return True
   Else
	  ConsoleWrite("Error: could not renew forge" & @LF)
	  _ScreenCapture_Capture(@ScriptDir & "\" & @ScriptName&"-screenAtFailure.jpg")
	  TogglePause()
	  Return False
   EndIf
EndFunc


;; Step Functions ;;
Func doOpenBank()
   ConsoleWrite("Trying To: OPEN BANK" & @LF)
   Local $success = False
   Local $tries = 0
   Do
	  $tries = $tries + 1
	  ConsoleWrite("Attempt #" & $tries& @LF)
	  ; Click Banker
	  safeClick('left', $banker_coord, 'range')

	  ; Run to Banker
	  $success = wait_bankOpen($runtime + $lag)
   Until ($tries >= 3 or $success)
   If ($success) Then
	  Return True
   Else
	  ConsoleWrite("Error: could not open the bank" & @LF)
	  _ScreenCapture_Capture(@ScriptDir & "\" & @ScriptName&"-screenAtFailure.jpg")
	  TogglePause()
	  Return False
   EndIf
EndFunc

Func doWithdrawAndCloseBank()
   ConsoleWrite("Trying To: WITHDRAW AND CLOSE BANK" & @LF)
   Local $success = False
   Local $tries = 0
   Do
	  $tries = $tries + 1
	  ConsoleWrite("Attempt #" & $tries& @LF)
	  ; Fill Coal Bag
	  _dropDownMenu($coalBag_coord, 2)

	  ; Wait for Bag To Fill
	  Sleep(100 + $lag + Random(0, 200, 1))

	  ; Withdraw Ores @ Preset #1
	  Send($loadoutNumber)

	  ; Withdrawal Delay ;
	  $success = wait_bankClosed(2600 + $lag)
   Until ($tries >= 3 or $success)
   If ($success) Then
	  Return True
   Else
	  ConsoleWrite("Error: could not withdraw and close the bank" & @LF)
	  _ScreenCapture_Capture(@ScriptDir & "\" & @ScriptName&"-screenAtFailure.jpg")
	  TogglePause()
	  Return False
   EndIf
EndFunc

Func doAnvilWindow()
   ConsoleWrite("Trying To: OPEN AND CONFIRM ANVIL WINDOW" & @LF)
   Local $success = False
   Local $tries = 0
   Do
	  $tries = $tries + 1
	  ConsoleWrite("Attempt #" & $tries& @LF)
	  ; Click Anvil
	  safeClick('left', $anvil_coord, 'range')

	  ; Run to Anvil
	  $success = wait_startSmithWindow($runtime + $lag)

	  ; Click Smith Icon
	  Send("{SPACE}")
   Until ($tries >= 3 or $success)
   If ($success) Then
	  Return True
   Else
	  ConsoleWrite("Error: could not open smith window" & @LF)
	  _ScreenCapture_Capture(@ScriptDir & "\" & @ScriptName&"-screenAtFailure.jpg")
	  TogglePause()
	  Return False
   EndIf
EndFunc

Func doSmithing()
   Local $updates = 10
   Local $updated = 0
   While ($updated < $updates)
	  $forgeTimeLeft = getRemainingForgeTime()
	  Sleep($smithTime/$updates)
	  $updated = $updated + 1
   WEnd
   Sleep(Random(0, 100+$lag, 1))
EndFunc


While 1
   ; Record Start Cycle Timer
   $cycle_start_time = _NowCalc()

   ; Open Bank
   doOpenBank()

   ; Withdraw and Close Bank
   doWithdrawAndCloseBank()

   ; Check Portable and Place/Renew if Needed
   doCheckAndErectForge()

   ; Opens Anvil Window
   doAnvilWindow()

   ; Wait for Smithing
   doSmithing()

   ; Increment Metrics
   $completed_trips = $completed_trips + 1
   $cycleTime = _DateDiff('s', $cycle_start_time, _NowCalc())

   ; Update Metrics
   GUICtrlSetData($label_barsDone, $completed_trips*$load_size)
   GUICtrlSetData($label_cycleTime, $cycleTime)
   Opt("SendKeyDownDelay", Random(100, 300, 1))

   ; Should It Pause?
   If($completed_trips >= $trip_limit) Then
	  TogglePause()
   EndIf
   ConsoleWrite(@LF)
WEnd

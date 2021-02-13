/*
	Written by Permamiss
	
	
Documentation Notes

	Better and more general documentation for LiveSplit autosplitters can be found at https://github.com/LiveSplit/LiveSplit/blob/master/Documentation/Auto-Splitters.md

	Game.instance.state (gameState) Values:
		0 = Inactive (Main Menu)
		1 = Paused (can only pause when in a level)
		2 = Loading Level (generally when loading the next level)
		3 = Playing Level (in a level)	
	
	"vars" is a persistent object that is able to contain persistent variables
	"old" contains the values of all the defined variables in the last update
	"current" contains the current values of all the defined variables
	"settings" is an object used to add or get settings
*/

state("Human") {}

startup		// called when the autosplitter script itself starts
{
		// Autosplitter Settings
	settings.Add("splitOnLoad", true, "Split whenever you beat a level");
		settings.Add("splitOnLoadingStart", true, "When to split (hover over me for more details)", "splitOnLoad");
			settings.SetToolTip("splitOnLoadingStart", "Enabled: Split when started loading new level\nDisabled: Split when finished loading new level\n\nMUST BE ENABLED FOR A SUBMITTED RUN TO BE CONSIDERED VALID");
	settings.Add("resetOnReturnToMenu", true, "Reset the timer when you return to the menu");
	settings.Add("cp%", false, "Checkpoint%");
		settings.SetToolTip("cp%", "Toggle for the Checkpoint% autosplitter\nAll nested options are considered disabled if this is disabled");
		settings.Add("splitOnCheckpoint", true, "Split whenever a new checkpoint is reached", "cp%");
			settings.SetToolTip("splitOnCheckpoint", "MUST BE ENABLED FOR A SUBMITTED CHECKPOINT% RUN TO BE CONSIDERED VALID");
		settings.Add("resetOnCheckpointMiss", true, "Reset the timer if a checkpoint is skipped", "cp%");
			settings.SetToolTip("resetOnCheckpointMiss", "Recommended so you do not waste time on an invalid run\n\nMUST BE ENABLED FOR A SUBMITTED CHECKPOINT% RUN TO BE CONSIDERED VALID");
			settings.Add("popupOnCheckpointMiss", true, "Notify you when a checkpoint is missed", "resetOnCheckpointMiss");
				settings.SetToolTip("popupOnCheckpointMiss", "Creates a priority pop-up message with info on the exact reason the run was reset");
	settings.Add("noJump%", false, "No-Jump%");
		settings.SetToolTip("noJump%", "Toggle for the No-Jump% autosplitter\nAll nested options are considered disabled if this is disabled");
		settings.Add("resetOnJump", true, "Reset the timer if you jump", "noJump%");
			settings.SetToolTip("resetOnJump", "Recommended so you do not waste time on an invalid run");
			settings.Add("popupOnJump", false, "Notify you when you jump in a run", "resetOnJump");
				settings.SetToolTip("popupOnJump", "Creates a priority pop-up message with info on the exact reason the run was reset");

	vars.log = (Action<string>)
	((text) =>
		{
			print("[HFF Autosplitter] " + text);
		}
	);
	vars.popup = (Action<string, string>)
	((text, title) =>
		{
			MessageBox.Show(text, "LiveSplit | H:FF Autosplitter" + (String.IsNullOrEmpty(title) ? "" : " | ") + title, MessageBoxButtons.OK, MessageBoxIcon.Error, MessageBoxDefaultButton.Button1, MessageBoxOptions.DefaultDesktopOnly);
		}
	);

		// "lastCpPerLevel" stores the last checkpoint number we hit in each level; used by cp% autosplitter to check if a level completion is valid
	vars.lastCpPerLevel = new int[13] // change to 14 if Thermal is taken out of "Extra Dreams" and added to the main campaign, and uncomment the beginning of line 49
	{
		3,		// Mansion:			0, 1, 2, 3
		4,		// Train:			0, 1, 2, 3, 4
		3,		// Carry:			0, 1, 2, 3
		3,		// Mountain:		0, 1, 2, 3
		7,		// Demolition:		0, 1, 2, 3, 4, 5, 6, 7
		12,		// Castle:			0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12
		10,		// Water:			0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
		10,		// Power:			0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
		13,		// Aztec:			0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
		24,		// Dark:			0, 1, 2, 3, 4, 5, 6, (skip 7-10 as they are conditional), 11, 12, 13, 14, 15, 16, 17, [18 OR 19 OR 20], [21 OR 22 OR 23], 24
		11,		// Steam:			0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11
		13,		// Ice:				0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13
		3/*,*/	// Intro_Reprise:	0, 1, 2, 3
	  //9		// Thermal:			0, 1, 2, 3, 4, 5, 6, 7, 8, 9 (not included due to needing to exit to main menu to access Thermal)
	};
	vars.loadedFromMainMenu = true;
	vars.ruleBreakReset = false;
	vars.resetMessageContents = "";
	vars.resetMessageTitle = "";
	vars.ptrGameInstance = IntPtr.Zero;
	vars.ptrClimbCheat = IntPtr.Zero;
	vars.ptrThrowCheat = IntPtr.Zero;
	vars.ptrHumanInstance = IntPtr.Zero;
	vars.ptrHumanControls = IntPtr.Zero;
	vars.offsetGameState = 0x0;
	vars.offsetLevel = 0x0;
	vars.offsetCheckpoint = 0x0;
}

init		// called when the script finds the game process
{
	vars.log("Detected that Human: Fall Flat has launched");

	IntPtr gameInitializeAddress = IntPtr.Zero;
	IntPtr cheatStartAddress = IntPtr.Zero;
	IntPtr humanEnableAddress = IntPtr.Zero;
	old.gameState = 0;
	current.gameState = 0;
	old.level = -1;
	current.level = -1;
	old.checkpoint = 0;
	current.checkpoint = 0;
	old.climbCheat = false;
	current.climbCheat = false;
	old.throwCheat = false;
	current.throwCheat = false;
	old.jumpPressed = false;
	current.jumpPressed = false;
	old.grounded = false;
	current.grounded = false;
	old.unconsciousTime = 0.0f;
	current.unconsciousTime = 0.0f;
	old.jumping = false;
	current.jumping = false;
	
	vars.log("Searching for game::Initialize signature and CheatCodes::Start signature...");
	foreach (var page in game.MemoryPages())
	{
		var scanner = new SignatureScanner(game, page.BaseAddress, (int)page.RegionSize);
		if (gameInitializeAddress == IntPtr.Zero)
		{
			gameInitializeAddress = scanner.Scan
			(
				new SigScanTarget(0,
				"55 8B EC 57 83 EC 24 8B 7D 08 B8 ?? ?? ?? ?? 89 38 C7 04 24 00 00 00 00 8D 6D 00 E8 A8 00 00 00 BA ?? ?? ?? ?? 8B C0 E8 ?? ?? ?? ?? BA ?? ?? ?? ?? 89 3C 24 8D 6D 00 E8 ?? ?? ?? ?? C7 04 24 ?? ?? ?? ?? E8 ?? ?? ?? ?? 89 45 F8 89 04 24 90")
			);
		}
		if (cheatStartAddress == IntPtr.Zero)
		{
			cheatStartAddress = scanner.Scan
			(
				new SigScanTarget(0,
				"55 8B EC 57 83 EC ?? 8B 7D 08 85 FF 0F 84 ?? ?? 00 00 ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? ?? 89 78 10 C7 40 14 ?? ?? ?? ?? C7 40 20 ?? ?? ?? ?? 8B 0D ?? ?? ?? ?? 89 48 0C 8B 0D ?? ?? ?? ?? 89 48 08 C6 40 30 00 C7 44 24 08 ?? ?? ?? ?? 89 44 24 04 C7 04 24 ?? ?? ?? ?? 90 E8 40 04 00 00 85 FF 0F 84 0E 04 00 00 C7 04 24")
			);
		}
		if (gameInitializeAddress != IntPtr.Zero && (IntPtr)cheatStartAddress != IntPtr.Zero)
			break;
	}
	if (settings["noJump%"])
	{
		foreach (var page in game.MemoryPages())
		{
			var scanner = new SignatureScanner(game, page.BaseAddress, (int)page.RegionSize);
			if (humanEnableAddress == IntPtr.Zero)
			{
				humanEnableAddress = scanner.Scan
				(
					new SigScanTarget(0,
					"55 8B EC 57 83 EC 24 8B 7D 08 8B 05 ?? ?? ?? ?? 89 7C 24 04 89 04 24 39 00 8B C0 E8 ?? ?? ?? ?? B8 ?? ?? ?? ?? 89 38 BA ?? ?? ?? ?? 89 3C 24 E8 ?? ?? ?? ?? 89 47 1C BA ?? ?? ?? ?? 89 3C 24 E8 ?? ?? ?? ?? 89 47 18 BA ?? ?? ?? ?? 89 3C 24 E8 ?? ?? ?? ?? 89 47 20 BA ?? ?? ?? ?? 89 3C 24 E8 4C FE FF FF 89 47 14 8D 65 FC 8D 65 FC 5F C9 C3")
				);
			}
			if (humanEnableAddress != IntPtr.Zero)
				break;
		}
	}
	
	if (gameInitializeAddress == IntPtr.Zero || cheatStartAddress == IntPtr.Zero || (settings["noJump%"] && humanEnableAddress == IntPtr.Zero))
	{
		// Waiting for the game to have booted up. This is a pretty ugly work
		// around, but we don't really know when the game is booted or where the
		// struct will be, so to reduce the amount of searching we are doing, we
		// sleep a bit between every attempt.
		Thread.Sleep(1000);
		throw new Exception("Could not find the desired pointer(s)");
	}

	// note to self: to find the "instance" address when Jit-ing the method that should contain the instance assignment,
	// look for "mov eax,05308E20" or similar. the Bytes for this example would be "B8 208E3005";
	// if this was "Game::Initialize+a", then the instance would be at "Game::Initialize+b", as "B8" is the "mov" and "208E3005" starts at +b.

	vars.log("Game::Initialize address found at: 0x" + gameInitializeAddress.ToString("X8"));
	vars.log("Extracting Game.instance pointer from Game::Initialize offset by 0xB...");
	IntPtr mPtrGameInstance = memory.ReadPointer(gameInitializeAddress + 0xB);
	vars.ptrGameInstance = memory.ReadPointer(mPtrGameInstance); // UNLIMITED POWER...shoutouts to Tedder from the LiveSplit team for helping me get to this point!!!
	vars.log("Game.instance address found at: 0x" + vars.ptrGameInstance.ToString("X8"));

	vars.log("CheatCodes::Start address found at: 0x" + cheatStartAddress.ToString("X8"));
	vars.log("Extracting CheatCodes.climbCheat and CheatCodes.throwCheat from CheatCodes::Start offset by 0x3C1 and 0x3E5, respectively...");
	vars.ptrClimbCheat = memory.ReadPointer((IntPtr)cheatStartAddress + 0x3C1);
	vars.ptrThrowCheat = memory.ReadPointer((IntPtr)cheatStartAddress + 0x3E5);
	vars.log("CheatCodes.climbCheat address found at: 0x" + vars.ptrClimbCheat.ToString("X8"));
	vars.log("CheatCodes.throwCheat address found at: 0x" + vars.ptrThrowCheat.ToString("X8"));

	if (settings["noJump%"])
	{
		vars.log("Human::OnEnable address found at: 0x" + humanEnableAddress.ToString("X8"));
		vars.log("Extracting Human.instance pointer from Human::OnEnable offset by 0x21...");
		IntPtr mPtrHumanInstance = memory.ReadPointer(humanEnableAddress + 0x21);
		vars.ptrHumanInstance = memory.ReadPointer(mPtrHumanInstance);
		vars.log("Human.instance address found at: 0x" + vars.ptrHumanInstance.ToString("X8"));

		vars.log("Extracting Human.controls from Human.instance offset by 0x14...");
		vars.ptrHumanControls = memory.ReadPointer((IntPtr)vars.ptrHumanInstance + 0x14);
		vars.log("Human.controls address found at: 0x" + vars.ptrHumanControls.ToString("X8"));
	}

	vars.offsetGameState = 0x5C;
	vars.offsetLevel = 0x44;
	vars.offsetCheckpoint = 0x48;

	current.gameState = memory.ReadValue<byte>((IntPtr)vars.ptrGameInstance + (int)vars.offsetGameState);
	current.level = memory.ReadValue<int>((IntPtr)vars.ptrGameInstance + (int)vars.offsetLevel);
	current.checkpoint = memory.ReadValue<int>((IntPtr)vars.ptrGameInstance + (int)vars.offsetCheckpoint);
	current.climbCheat = memory.ReadValue<bool>((IntPtr)vars.ptrClimbCheat);
	current.throwCheat = memory.ReadValue<bool>((IntPtr)vars.ptrThrowCheat);
	if (settings["noJump%"])
	{
		vars.offsetJumpPressed = 0x3C;
		vars.offsetGrounded = 0x5C;
		vars.offsetUnconsciousTime = 0x70;

		current.jumpPressed = memory.ReadValue<bool>((IntPtr)vars.ptrHumanControls + (int)vars.offsetJumpPressed);
		current.grounded = memory.ReadValue<bool>((IntPtr)vars.ptrHumanInstance + (int)vars.offsetGrounded);
		current.unconsciousTime = memory.ReadValue<float>((IntPtr)vars.ptrHumanInstance + (int)vars.offsetUnconsciousTime);
	}

	refreshRate = 60;
}

start		// returning true starts the timer if not started
{
		// if we were loading, are currently playing a level, and we have loaded from the main menu, then start the timer
	if (old.gameState == 2 && current.gameState == 3 && vars.loadedFromMainMenu)
	{
			// if climbCheat or throwCheat is enabled, do not start, and pop up an error message regarding it
		if (current.climbCheat || current.throwCheat)
		{
			string message = ((current.climbCheat && current.throwCheat) ? "climbCheat and throwCheat" : current.climbCheat ? "climbCheat" : "throwCheat") + " detected! Please disable cheats in console before you begin a speedrun.";
			string message2 = "Did not begin timing the speedrun.";

			vars.log("Did not start timer; " + message);
			vars.popup(message + "\n\n" + message2, "Cannot Start: Cheats Detected");
			return false;
		}
		return true;
	}
}

update		// updates a certain number of times a second. update rate is determined by refreshRate in init
{
	current.gameState = memory.ReadValue<byte>((IntPtr)vars.ptrGameInstance + (int)vars.offsetGameState);
	current.level = memory.ReadValue<int>((IntPtr)vars.ptrGameInstance + (int)vars.offsetLevel);
	current.checkpoint = memory.ReadValue<int>((IntPtr)vars.ptrGameInstance + (int)vars.offsetCheckpoint);
	current.climbCheat = memory.ReadValue<bool>((IntPtr)vars.ptrClimbCheat);
	current.throwCheat = memory.ReadValue<bool>((IntPtr)vars.ptrThrowCheat);
	if (settings["noJump%"])
	{
		if (vars.ptrHumanInstance == IntPtr.Zero || vars.ptrHumanControls == IntPtr.Zero)
			throw new Exception("No-Jump% autosplitter enabled while game was open OR bad pattern for HumanControls; restarting...");
		current.jumpPressed = memory.ReadValue<bool>((IntPtr)vars.ptrHumanControls + (int)vars.offsetJumpPressed);
		current.grounded = memory.ReadValue<bool>((IntPtr)vars.ptrHumanInstance + (int)vars.offsetGrounded);
		current.unconsciousTime = memory.ReadValue<float>((IntPtr)vars.ptrHumanInstance + (int)vars.offsetUnconsciousTime);
		current.jumping = current.jumpPressed && old.grounded && current.unconsciousTime == 0.0f;

		if (current.jumping && !old.jumping)
		{
			vars.log("Player jumped!");
		}
	}
		// Code for debugging, making sure that I have the right addresses and such
	//vars.log("gameState value = " + current.gameState.ToString());
	//vars.log("currentLevel value = " + current.level.ToString());
	//vars.log("currentCheckpoint value = " + current.checkpoint.ToString());
	//vars.log("currentClimbCheat value = " + current.climbCheat.ToString());
	//vars.log("currentThrowCheat value = " + current.throwCheat.ToString());
	vars.log("currentJumpPressed value = " + current.jumpPressed.ToString());
	vars.log("currentGrounded value = " + current.grounded.ToString());
	vars.log("currentUnconsciousTime value = " + current.unconsciousTime.ToString());
	
		// if player was in Main Menu and is now loading, then set var to true
	if (old.gameState == 0 && current.gameState == 2)
		vars.loadedFromMainMenu = true;
		// otherwise if player was playing last tick and is still playing now, then set var to false
	else if (old.gameState == 3 && current.gameState == 3)
		vars.loadedFromMainMenu = false;
		// if the previous level was not -1 (Main Menu) and we have progressed a level
	if (old.level >= 0 && current.level > old.level)
		vars.log("Completed level " + old.level.ToString() + "; now on level " + current.level.ToString());
		// if climbCheat or throwCheat has been enabled, make pop-up error message for user letting them know
		// that they have just enabled cheats enabled and thus their current run has been invalidated

	if (!String.IsNullOrEmpty(vars.resetMessageContents))
	{
		vars.log("Timer reset; " + vars.resetMessageContents);
		// if the player broke the rules in some way which invalidates their run, create a pop-up message to let them know what rule they broke
		if (vars.ruleBreakReset)
		{
			vars.ruleBreakReset = false;

			vars.popup(vars.resetMessageContents + "\n\nCurrent speedrun invalidated; timer has been forcibly reset.", "Run Reset: " + vars.resetMessageTitle);
			vars.resetMessageTitle = "";
		}
		vars.resetMessageContents = "";
	}
}

split		// returning true will split (advances to the next split)
{
		// if the "splitOnLoad" settings is enabled, and
	if (settings["splitOnLoad"])
	{
			// the player did not just load in from main menu, then
		if (!vars.loadedFromMainMenu)
		{
				// if the setting to split when loading starts is enabled, then
			if (settings["splitOnLoadingStart"])
			{
					// if the player was playing and is now loading, then split
				if (old.gameState == 3 & current.gameState == 2)
					return true;
			}
				// otherwise if the setting to split when loading finishes is enabled, and the player was loading and is now playing, then split
			else if (old.gameState == 2 && current.gameState == 3)
				return true;
		}
	}
		// if the "cp%" and "splitOnCheckpoint" settings are enabled and we have advanced a checkpoint, then split
	if (settings["cp%"] && settings["splitOnCheckpoint"] && current.checkpoint > old.checkpoint)
		return true;
		// if the player was playing and directly goes to Main Menu without loading (thus far only relevant with the "Extra Dreams" levels), then split
	if (old.gameState == 3 && current.gameState == 0)
		return true;
}

isLoading	// returning true pauses the timer
{
		// if currently loading a level, pause the timer
	if (current.gameState == 2)
		return true;
	return false;
}

reset		// returning true resets the timer
{
		// if the "resetOnReturnToMenu" setting is enabled, and we were paused in-game and exited into the menu, then reset the timer
	if (settings["resetOnReturnToMenu"] && current.gameState == 0 && old.gameState == 1)
	{
		vars.log("Resetting timer; player returned to Main Menu.");
		return true;
	}
		// if "cp%" setting is enabled and "reset if you miss a checkpoint" is enabled, then
	if (settings["cp%"] && settings["resetOnCheckpointMiss"])
	{
			// if player skipped a checkpoint, then
		if (current.checkpoint > old.checkpoint + 1)
		{
			if (
					// if the level is Dark, and one of the following lines is true, then *do not* reset (aka, do return false):
				current.level == 9 &&
				(
						// the previous checkpoint was 6 and is now 11 (due to Dark's choose-a-path checkpoint system)
					(old.checkpoint == 6 && current.checkpoint == 11) ||
						// the previous checkpoint was 17 and the new checkpoint is [19 or 20] (17 can lead into 18, 19, or 20 depending on which item you bring up first) (Item 1)
					(old.checkpoint == 17 && (current.checkpoint == 19 || current.checkpoint == 20)) ||
						// the previous checkpoint was [18 or 19 or 20] and the new checkpoint is [21 or 22 or 23] (necessary because: 18 jumps to [21 or 22], 19 jumps to [21 or 23], 20 jumps to [22 or 23]) (Item 2)
					((old.checkpoint == 18 || old.checkpoint == 19 || old.checkpoint == 20) && (current.checkpoint == 21 || current.checkpoint == 22 || current.checkpoint == 23)) ||
						// the previous checkpoint was [21 or 22] and the new checkpoint is 24 (necessary because bringing up the last item causes the checkpoint to jump to 24, which is a problem when previous checkpoint was 21 or 22) (Item 3/All Items (Red Wire, Battery 1, Battery 2))
					((old.checkpoint == 21 || old.checkpoint == 22) && current.checkpoint == 24)
				)
			)
				return false;
			
			int skippedCps = current.checkpoint - old.checkpoint - 1;
			vars.resetMessageContents = "Skipped " + (skippedCps == 1 ? "a" : skippedCps.ToString()) + " checkpoint" + (skippedCps == 1 ? " " : "s ") + "(current cp: " + current.checkpoint.ToString() + ", expected cp: " + (old.checkpoint + 1).ToString() + ").";
			if (settings["popupOnCheckpointMiss"])
			{
				vars.resetMessageTitle = "Skipped Checkpoint(s)";
				vars.ruleBreakReset = true;
			}
			return true;
		}
			// if "cp%" setting is enabled and we are loading a new level after playing, and it's not the last checkpoint in the level
		else if (current.level >= 0) //have to check if level >= 0 because when in main menu level is -1, and -1 is not a valid index in the lastCpPerLevel array
		{
				// if playing previous tick, loading new level this tick, not in main menu previous tick, and not on final checkpoint in the level that was just completed,
				// then reset the timer
			if ((old.gameState == 3 && current.gameState == 2 && !vars.loadedFromMainMenu) && current.checkpoint != vars.lastCpPerLevel[old.level])
			{
				int skippedCps = vars.lastCpPerLevel[old.level] - current.checkpoint;
				vars.resetMessageContents = "Prematurely completed the level " + (skippedCps == 1 ? "a" : skippedCps.ToString()) + " checkpoint" + (skippedCps == 1 ? " " : "s ") + "early (current cp: " + current.checkpoint.ToString() + ", level's last cp: " + vars.lastCpPerLevel[old.level].ToString() + ").";
				if (settings["popupOnCheckpointMiss"])
				{
					vars.resetMessageTitle = "Beat Level Early";
					vars.ruleBreakReset = true;
				}
				return true;
			}
		}
	}

	if (settings["noJump%"] && settings["resetOnJump"] && current.jumping && !old.jumping)
	{
		vars.resetMessageContents = "Pressed the jump button in No-Jump%.";
		if (settings["popupOnJump"])
		{
			vars.resetMessageTitle = "Player Jumped";
			vars.ruleBreakReset = true;
		}
		return true;
	}
		// if climbCheat or throwCheat somehow get enabled mid-run, reset run and let them know why it has been reset
		// there's no way this could "accidentally" happen; this is so cheats can't sneakily be enabled with Cheat Engine via hotkey
	if (current.climbCheat || current.throwCheat)
	{
		vars.resetMessageContents = ((current.climbCheat && current.throwCheat) ? "climbCheat and throwCheat" : current.climbCheat ? "climbCheat" : "throwCheat") + " detected! Please disable cheats in console before you begin another speedrun.";
		vars.resetMessageTitle = "Cheats Detected";
		vars.ruleBreakReset = true;

		return true;
	}
	
}
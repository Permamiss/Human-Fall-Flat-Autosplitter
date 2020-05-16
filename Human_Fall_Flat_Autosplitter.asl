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
	vars.offsetGameState = 0x0;
	vars.offsetLevel = 0x0;
	vars.offsetCheckpoint = 0x0;
}

init		// called when the script finds the game process
{
	vars.log("Detected that Human: Fall Flat has launched");

	IntPtr gameInitializeAddress = IntPtr.Zero;
	IntPtr cheatStartAddress = IntPtr.Zero;
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
	
	vars.log("Searching for game::Initialize signature and CheatCodes::Start signature...");
	foreach (var page in game.MemoryPages())
	{
		var scanner = new SignatureScanner(game, page.BaseAddress, (int)page.RegionSize);
		if (gameInitializeAddress == IntPtr.Zero)
		{
			gameInitializeAddress = scanner.Scan
			(
				new SigScanTarget(0,
				"55 8B EC 57 83 EC 04 8B 7D 08 B8 ?? ?? ?? ?? 89 38 83 EC 0C 6A 00 E8 ?? ?? ?? 00 83 C4 10 BA ?? ?? ?? ?? E8 ?? ?? ?? ?? BA ?? ?? ?? ?? 83 EC 0C 57 E8 ?? ?? ?? ?? 83 C4 10 83 EC 0C 68 ?? ?? ?? ?? E8 ?? ?? ?? ?? 83 C4 10 83 EC 0C 89 45 F8 50 E8 ?? ?? ?? 00 83 C4 10 8B 45 F8 89 47 ?? BA ?? ?? ?? ?? 83 EC 0C 57 E8 ?? ?? ?? 00 83 C4 10 89 47 ?? C7 47 ?? 00 00 00 00 8B 47 10 8B 40 0C 48 89 47 ?? 8D 65 FC 5F C9 C3")
			);
		}
		if ((IntPtr)cheatStartAddress == IntPtr.Zero)
		{
			cheatStartAddress = scanner.Scan
			(
				new SigScanTarget(0,
				"55 8B EC 57 83 EC 04 8B 7D 08 85 FF 0F 84 2E 03 00 00 83 EC 0C 68 ?? ?? ?? ?? E8 ?? ?? ?? FF 83 C4 10 89 78 10 C7 40 14")
			);
		}
		if (gameInitializeAddress != IntPtr.Zero && (IntPtr)cheatStartAddress != IntPtr.Zero)
			break;
	}
	
	if (gameInitializeAddress == IntPtr.Zero || (IntPtr)cheatStartAddress == IntPtr.Zero)
	{
		// Waiting for the game to have booted up. This is a pretty ugly work
		// around, but we don't really know when the game is booted or where the
		// struct will be, so to reduce the amount of searching we are doing, we
		// sleep a bit between every attempt.
		Thread.Sleep(1000);
		throw new Exception("Could not find the desired pointer");
	}

	vars.log("game::Initialize address found at: 0x" + gameInitializeAddress.ToString("X8"));
	vars.log("CheatCodes::Start address found at: 0x" + cheatStartAddress.ToString("X8"));
	vars.log("Extracting game.Instance pointer from game::Initialize offset by 0xB...");
	vars.log("Extracting CheatCodes.climbCheat and CheatCodes.throwCheat from CheatCodes::Start offset by 0x2CC and 0x2ED, respectively...");
	IntPtr mPtrGameInstance = memory.ReadPointer(gameInitializeAddress + 0xB);
	vars.ptrGameInstance = memory.ReadPointer(mPtrGameInstance); // UNLIMITED POWER...shoutouts to Tedder from the LiveSplit team for helping me get to this point!!!
	vars.log("game.Instance address found at: 0x" + vars.ptrGameInstance.ToString("X8"));

	vars.ptrClimbCheat = memory.ReadPointer((IntPtr)cheatStartAddress + 0x2CC);
	vars.ptrThrowCheat = memory.ReadPointer((IntPtr)cheatStartAddress + 0x2ED);
	vars.log("CheatCodes.climbCheat address found at: 0x" + vars.ptrClimbCheat.ToString("X8"));
	vars.log("CheatCodes.throwCheat address found at: 0x" + vars.ptrThrowCheat.ToString("X8"));

	/* The following offsets/fields are for the Game class in v1073981 of HFF, which we can access via the vars.ptrGameInstance pointer
		offset: fieldName (class/type)
		 C : startupXP (StartupExperienceController)
		10 : levels (str[])
		14 : editorPickLevels (str[])
		40 : levelCount (int)
		44 : currentLevelNumber (int)
		48 : currentCheckpointNumber (int)
		18 : currentSolvedCheckpoints (List<int>)
		4C : currentLevelType (WorkshopItemSource)
		1C : editorLanguage (str)
		50 : editorStartLevel (int)
		54 : editorStartCheckpoint (int)
		20 : defaultLight (UnityEngine.Light)
		58 : state (GameState)
		5C : passedLevel (bool)
		24 : playerPrefab (Multiplayer.NetPlayer)
		28 : cameraPrefab (UnityEngine.Camera)
		2C : ragdollPrefab (Ragdoll)
		30 : skyboxMaterial (UnityEngine.Material)
		34 : gameProgress (GameProgress)
		5D : singleRun (bool)
		5E : HasSceneLoaded (bool)
		38 : bundle (UnityEngine.AssetBundle)
		3C : workshopLevel (HumanAPI.WorkshopLevelMetadata)
		5F : workshopLevelIsCustom (bool)
		60 : skyColor (UnityEngine.Color)
	*/
		// may use the below to differentiate offsets in the future if they change the code in Game *again*
	//vars.log("ModuleMemorySize: " + modules.First().ModuleMemorySize.ToString());
	//if (modules.First().ModuleMemorySize == 659456)
	//{
	//	vars.offsetGameState = 0x50;
	//	vars.offsetLevel = 0x40;
	//	vars.offsetCheckpoint = 0x44;
	//}
	//else
	//{
	vars.offsetGameState = 0x58;
	vars.offsetLevel = 0x44;
	vars.offsetCheckpoint = 0x48;
	//}
	current.gameState = memory.ReadValue<byte>((IntPtr)vars.ptrGameInstance + (int)vars.offsetGameState);
	current.level = memory.ReadValue<int>((IntPtr)vars.ptrGameInstance + (int)vars.offsetLevel);
	current.checkpoint = memory.ReadValue<int>((IntPtr)vars.ptrGameInstance + (int)vars.offsetCheckpoint);
	current.climbCheat = memory.ReadValue<bool>((IntPtr)vars.ptrClimbCheat);
	current.throwCheat = memory.ReadValue<bool>((IntPtr)vars.ptrThrowCheat);

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
		// Code for debugging, making sure that I have the right addresses and such
	//vars.log("gameState value = " + current.gameState.ToString());
	//vars.log("currentLevel value = " + current.level.ToString());
	//vars.log("currentCheckpoint value = " + current.checkpoint.ToString());
	//vars.log("currentClimbCheat value = " + current.climbCheat.ToString());
	//vars.log("currentThrowCheat value = " + current.throwCheat.ToString());
	
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
			
			if (settings["popupOnCheckpointMiss"])
			{
				int skippedCps = current.checkpoint - old.checkpoint - 1;
				vars.resetMessageContents = "Skipped " + (skippedCps == 1 ? "a" : skippedCps.ToString()) + " checkpoint" + (skippedCps == 1 ? " " : "s ") + "(current cp: " + current.checkpoint.ToString() + ", expected cp: " + (old.checkpoint + 1).ToString() + ").";
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
				if (settings["popupOnCheckpointMiss"])
				{
					int skippedCps = vars.lastCpPerLevel[old.level] - current.checkpoint;
					vars.resetMessageContents = "Prematurely completed the level " + (skippedCps == 1 ? "a" : skippedCps.ToString()) + " checkpoint" + (skippedCps == 1 ? " " : "s ") + "early (current cp: " + current.checkpoint.ToString() + ", level's last cp: " + vars.lastCpPerLevel[old.level].ToString() + ").";
					vars.resetMessageTitle = "Beat Level Early";
					vars.ruleBreakReset = true;
				}
				return true;
			}
		}
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
/**
 * @autor rcam
 * @date 15.07.2014.
 * @company Gameduell GmbH
 */
package de.gameduell.cli.commands;

import de.gameduell.cli.helpers.PlatformHelper;
import de.gameduell.cli.helpers.AskHelper;
import de.gameduell.cli.helpers.DownloadHelper;
import de.gameduell.cli.helpers.ExtractionHelper;
import de.gameduell.cli.helpers.PathHelper;
import de.gameduell.cli.helpers.LogHelper;
import de.gameduell.cli.helpers.StringHelper;
import de.gameduell.cli.commands.impl.IGDCommand;
import de.gameduell.cli.helpers.ProcessHelper;
import de.gameduell.cli.helpers.HXCPPConfigXMLHelper;

import haxe.Http;
import haxe.io.Eof;
import haxe.io.Path;
import sys.io.File;
import sys.FileSystem;
import haxe.Json;
import neko.Lib;

class SetupFlashCommand implements IGDCommand
{	
	private static var airMacPath = "http://airdownload.adobe.com/air/mac/download/latest/AdobeAIRSDK.tbz2";
	private static var airWindowsPath = "http://airdownload.adobe.com/air/win/download/latest/AdobeAIRSDK.zip";
	private static var flashDebuggerMacPath = "http://fpdownload.macromedia.com/pub/flashplayer/updaters/14/flashplayer_14_sa.dmg";
	private static var flashDebuggerWindowsPath = "http://download.macromedia.com/pub/flashplayer/updaters/14/flashplayer_14_sa.exe";
	private static var flashPlayerSystemPluginPath = "http://get.adobe.com/flashplayer/otherversions/";
	
	/// RESULTING VARIABLES
	private var airSDKPath : String = null;
	private var hxcppConfigPath : String = null;
    
    public function new()
    {

    }

    public function execute(cmd : String) : String
    {
    	try
    	{
	    	LogHelper.println("");
	    	LogHelper.println("\x1b[2m------");
	    	LogHelper.println("Flash Setup");
	    	LogHelper.println("------\x1b[0m");
	    	LogHelper.println("");

	    	downloadAirSDK();

	    	LogHelper.println("");

	    	LogHelper.println("Installing the air haxelib...");
			ProcessHelper.runCommand ("", "haxelib", [ "install", "air3" ], true, true);

	    	LogHelper.println("");

	    	downloadFlashPlayer();
	    	
	    	LogHelper.println("");

	    	downloadFlashDebugger();

	    	LogHelper.println("");

	    	setupHXCPP();

	    	LogHelper.println("\x1b[2m------");
	    	LogHelper.println("end");
	    	LogHelper.println("------\x1b[0m");

    	} catch(error : Dynamic)
    	{
    		LogHelper.error("An error occurred, do you need admin permissions to run the script? Check if you have permissions to write on the paths you specify. Error:" + error);
    	}
	    
	    return "success";
    }

    private function downloadAirSDK()
    {
    	/// variable setup
    	var downloadPath = "";
		var defaultInstallPath = "";

		if(PlatformHelper.hostPlatform == Platform.WINDOWS) 
		{	
			downloadPath = airWindowsPath;
			defaultInstallPath = "C:\\Development\\Android SDK";	
		} 
		else if(PlatformHelper.hostPlatform == Platform.MAC) 
		{	
			downloadPath = airMacPath;
			defaultInstallPath = "/opt/air-sdk";
		}

		var downloadAnswer = AskHelper.askYesOrNo("Download and install the Adobe AIR SDK?");

		/// ask for the instalation path
		airSDKPath = AskHelper.askString("Air SDK Location", defaultInstallPath);

		/// clean up a bit
		airSDKPath = PathHelper.unescape(airSDKPath);
		airSDKPath = StringHelper.strip(airSDKPath);

		if(airSDKPath == "")
			airSDKPath = defaultInstallPath;

		if(downloadAnswer == Yes) 
		{	
			/// the actual download
			DownloadHelper.downloadFile(downloadPath);

			/// create the directory
			PathHelper.mkdir(airSDKPath);
			
			/// the extraction
			ExtractionHelper.extractFile(Path.withoutDirectory(downloadPath), airSDKPath, "");
		}
    }

    private function downloadFlashDebugger()
    {
    	/// variable setup
    	var downloadPath = "";
		var defaultInstallPath = "";

		if(PlatformHelper.hostPlatform == Platform.WINDOWS) 
		{	
			downloadPath = flashDebuggerWindowsPath;
		} 
		else if(PlatformHelper.hostPlatform == Platform.MAC) 
		{	
			downloadPath = flashDebuggerMacPath;
		}

		var downloadAnswer = AskHelper.askYesOrNo("Download and install the Flash Debugger?");

		if(downloadAnswer == Yes) 
		{	
			/// the actual download
			DownloadHelper.downloadFile(downloadPath);

			LogHelper.info("Running installer " + Path.withoutDirectory(downloadPath));
			// running the installer
			ProcessHelper.runInstaller(Path.withoutDirectory(downloadPath));
		}

		LogHelper.println("You additionally need to associate .swf files with the debugger.");
    }

    private function downloadFlashPlayer()
    {
		var answer = AskHelper.askYesOrNo("Go to the flash website and download the Flash Player System plugin?");

		if(answer == Yes)
		{
			ProcessHelper.openURL(flashPlayerSystemPluginPath);
		}
    }
 
	private function setupHXCPP()
	{
    	hxcppConfigPath = HXCPPConfigXMLHelper.getProbableHXCPPConfigLocation();

    	if(hxcppConfigPath == null)
    	{
			LogHelper.error("Could not find the home folder, no HOME variable is set. Can't find hxcpp_config.xml");
    	}

		var hxcppHelper = new HXCPPConfigXMLHelper(hxcppConfigPath);

		var existingDefines : Map<String, String> = hxcppHelper.getDefines();

    	var newDefines : Map<String, String> = getDefinesToWriteToHXCPP();

		LogHelper.info("\x1b[1mWriting new definitions to hxcpp config file:\x1b[0m");

		for(def in newDefines.keys())
		{
			LogHelper.info("\x1b[1m" + def + "\x1b[0m:" + newDefines.get(def));
		}

		for(def in existingDefines.keys())
		{
			if(!newDefines.exists(def))
			{
				newDefines.set(def, existingDefines.get(def));
			}
		}

		hxcppHelper.writeDefines(newDefines);
	}

	private function getDefinesToWriteToHXCPP() : Map<String, String>
	{
		var defines = new Map<String, String>();

		if(FileSystem.exists(airSDKPath))
		{
			defines.set("AIR_SDK", FileSystem.fullPath(airSDKPath));
		}
		else
		{
			LogHelper.error("Path specified for air SDK doesn't exist!");
		}		

		defines.set("AIR_SETUP", "YES");

		return defines;
	}
}

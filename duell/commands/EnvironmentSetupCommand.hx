/*
 * Copyright (c) 2003-2015, GameDuell GmbH
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 * this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 * this list of conditions and the following disclaimer in the documentation
 * and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

package duell.commands;

import duell.helpers.CommandHelper;
import duell.helpers.PathHelper;
import duell.helpers.AskHelper;
import duell.helpers.DuellConfigHelper;
import duell.objects.DuellLib;
import duell.helpers.DuellLibHelper;
import duell.objects.DuellConfigJSON;
import haxe.CallStack;
import duell.helpers.LogHelper;
import duell.commands.IGDCommand;

import duell.versioning.GitVers;

import duell.objects.Arguments;
import haxe.io.Path;

import sys.io.File;
import sys.FileSystem;

import duell.helpers.PythonImportHelper;

using StringTools;

class EnvironmentSetupCommand implements IGDCommand
{

    var setupLib : DuellLib = null;
    var platformName : String;

    var gitvers: GitVers;

    public function new()
    {

    }

    public function execute() : String
    {
        LogHelper.info("");
        LogHelper.info("\x1b[2m------");
        LogHelper.info("Setup");
        LogHelper.info("------\x1b[0m");
        LogHelper.info("");

        determinePlatformToSetupFromArguments();

        LogHelper.println("");

        buildNewEnvironmentWithSetupLib();

        LogHelper.println("");
        LogHelper.info("\x1b[2m------");
        LogHelper.info("end");
        LogHelper.info("------\x1b[0m");
        return "success";
    }

    private function determinePlatformToSetupFromArguments()
    {
        platformName = Arguments.getSelectedPlugin();

        var platformNameCorrectnessCheck = ~/^[a-z0-9]+$/;

        if (!platformNameCorrectnessCheck.match(platformName))
            throw 'Unknown platform $platformName, should be composed of only letters or numbers, no spaces of other characters. Example: \"duell setup mac\" or \"duell setup android\"';

        var pluginLibName = "duellsetup" + platformName;
        setupLib = DuellLib.getDuellLib(pluginLibName);

        if (!DuellLibHelper.isInstalled(pluginLibName))
        {
            var answer = AskHelper.askYesOrNo('A library for setup of $platformName environment is not currently installed. Would you like to try to install it?');

            if(answer)
            {
                DuellLibHelper.install(pluginLibName);
            }
            else
            {
                LogHelper.println('Rerun with the library "duellsetup$platformName" installed');
                Sys.exit(0);
            }
        }

        gitvers = new GitVers(setupLib.getPath());
        if (Arguments.get("-v") != null)
        {
            var solvedVersion = gitvers.solveVersion(Arguments.get("-v"));
            gitvers.changeToVersion(solvedVersion);
        }
        else
        {
            throw "You must always specify a version. E.g. duell setup android -v 1.0.0";
        }
    }

    private function buildNewEnvironmentWithSetupLib()
    {
        var outputFolder = haxe.io.Path.join([duell.helpers.DuellConfigHelper.getDuellConfigFolderLocation(), ".tmp"]);
        var outputRun = haxe.io.Path.join(['$outputFolder', 'run.py']);

        var buildArguments = new Array<String>();

        buildArguments.push("-main");
        buildArguments.push("duell.setup.main.SetupMain");

        buildArguments.push("-python");
        buildArguments.push(outputRun);

        buildArguments.push("-cp");
        buildArguments.push(DuellLibHelper.getPath("duell"));

        buildArguments.push("-cp");
        buildArguments.push(DuellLibHelper.getPath(setupLib.name));

        buildArguments.push("-D");
        buildArguments.push("plugin");

        buildArguments.push("-resource");
        buildArguments.push(Path.join([DuellLibHelper.getPath("duell"), Arguments.CONFIG_XML_FILE]) + "@generalArguments");

        PathHelper.mkdir(outputFolder);

        CommandHelper.runHaxe("", buildArguments, {errorMessage: "building the plugin"});

        /// bootstrap python libs
        var pyLibPath = haxe.io.Path.join([DuellLibHelper.getPath(setupLib.name), "pylib"]);
        if (FileSystem.exists(pyLibPath))
        {
            var file = File.getBytes(outputRun);

            var fileOutput = File.write(outputRun, true);
            fileOutput.writeString("import os\n");
            fileOutput.writeString("import sys\n");
            fileOutput.writeString('sys.path.insert(0, "$pyLibPath")\n');

            fileOutput.writeBytes(file, 0, file.length);
            fileOutput.close();
        }

        var runArguments = [outputRun];
        runArguments = runArguments.concat(Arguments.getRawArguments());

        PythonImportHelper.runPythonFile(outputRun);

        LogHelper.println("Saving Setup Done Marker... ");
        var duellConfig = DuellConfigJSON.getConfig(DuellConfigHelper.getDuellConfigFileLocation());

        duellConfig.setupsCompleted = duellConfig.setupsCompleted.filter(function (s) return !s.split(":")[0].startsWith(platformName));

        duellConfig.setupsCompleted.push(platformName + ":" + gitvers.currentVersion);
        duellConfig.writeToConfig();
    }

}

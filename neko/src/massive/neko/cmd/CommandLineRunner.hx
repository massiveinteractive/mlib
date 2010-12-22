/****
* Copyright 2010 Massive Interactive. All rights reserved.
* 
* Redistribution and use in source and binary forms, with or without modification, are
* permitted provided that the following conditions are met:
* 
*    1. Redistributions of source code must retain the above copyright notice, this list of
*       conditions and the following disclaimer.
* 
*    2. Redistributions in binary form must reproduce the above copyright notice, this list
*       of conditions and the following disclaimer in the documentation and/or other materials
*       provided with the distribution.
* 
* THIS SOFTWARE IS PROVIDED BY MASSIVE INTERACTIVE ``AS IS'' AND ANY EXPRESS OR IMPLIED
* WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
* FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL MASSIVE INTERACTIVE OR
* CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
* CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
* SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON
* ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
* NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
* ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
* 
* The views and conclusions contained in the software and documentation are those of the
* authors and should not be interpreted as representing official policies, either expressed
* or implied, of Massive Interactive.
* 
****/

package massive.neko.cmd;

import massive.neko.cmd.ICommand;
import massive.neko.cmd.Command;

import neko.FileSystem;
import massive.haxe.log.Log;

import massive.neko.io.File;
import massive.neko.cmd.Console;
import neko.vm.Thread;
import neko.Lib;
import neko.Sys;
import neko.io.Process;

/**
*  Base class for application
*  */
class CommandLineRunner
{

	public var console(default, set_console):Console;

	public var commands:Array<CommandDef>;
		
	public function new():Void
	{
		commands = new Array();
		console = createConsole();
	}
	
	private function createConsole():Console
	{
		return new Console(true);
	}
	
	private function set_console(value:Console):Console
	{
		console = value;
	
		var log = console.getOption("-debug");
		if(log != null)
		{
			if(log == "true") log = "debug";
			Log.setLogLevelFromString(log);
			
			Log.debug("systemArgs: " + console.systemArgs);
			
		}
		else
		{
			Log.logLevel = LogLevel.console;	
		}
		
		return console;
	}


	public function mapCommand(command:Class<ICommand>, name:String, ?alt:Array<String>=null, ?description:String="", ?help:String=null, ?visible:Bool=true)
	{
		commands.push({command:command, name:name, alt:alt, description:description, help:help, visible:visible});	
	}
	
	public function run():Void
	{
	
		var commandArg:String = console.getNextArg();
		Log.debug("commandArg = " + commandArg);
		var commandClass:Class<ICommand> = getCommandFromString(commandArg);
		
		printHeader();

		if(commandClass != null)
		{
			var hash:Hash<Dynamic> = new Hash();
			runCommand(commandClass, hash);
			exit(0);
		}
		else if(commandArg == null)
		{
			printCommands();
			exit(0);
		}
		else if(commandArg == "help")
		{
			
			var sub:String = console.getNextArg();
			
			var cmd:CommandDef = getCommandDefFromString(sub);
			
			if(cmd != null)
			{
				printCommandDetail(cmd);
			
				exit(0);
			}
			else if(sub != null)
			{
				if(sub == "help")
				{
					print("help: help");
					print("  It looks like you need HELP with that HELP command.");
					print("  If recursive commands persist, please seek urgent medical assistance.");  
				}
				else
				{
					printCommands();
					error("Unknown subcommand: " + sub);	
			
				}
			}
			else
			{
				printCommands();
				exit(0);
			}
		}
		else
		{
			printCommands();
			error("Unknown command: " + commandArg);	
		}

	}
	
	public function printHeader():Void
	{
		print("Massive Command Line Runner - Copyright " + Date.now().getFullYear() + " Massive Interactive");
		
	}
	
	public function printUsage():Void
	{
		//print("Usage: cmd [subcommand] [options]");
	}
	
	public function printHelp():Void
	{
		//print("Usage: cmd [subcommand] [options]");
	}
	
	public function printCommands():Void
	{
		printUsage();
		printHelp();
		
		print("Type 'help <command>' for help on a specific subcommand.");
		print("");
		print("Available commands:");
		for(cmd in commands)
		{
			if(cmd.visible == false && Log.logLevel == LogLevel.console) continue;
			
			var alt:String = "";
			
			if(cmd.alt != null && cmd.alt.length > 0)
			{
				alt = "(" + cmd.alt.join(",") + ") ";
			}
			print("   " + cmd.name + " " + alt + ": " + cmd.description);
		}

		print("");
	}	
	
	
	private function printCommandDetail(cmd:CommandDef):Void
	{
		var msg:String = "help: " + cmd.name;
		
		if(cmd.alt != null) msg += "(" + cmd.alt.join(",")+ ") ";
		if(cmd.description != null) msg += ": " + cmd.description;
		
		print(msg);
		
		if(cmd.help != null) print(cmd.help);
	}
	
	
	private function print(message:Dynamic):Void
	{
		neko.Lib.println(Std.string(message));
	}
	
	private function error(message:Dynamic, ?code:Int=1, ?posInfos:haxe.PosInfos):Void
	{
		print("Error: " + message);
		Log.error(code + "\n" + posInfos);
		print("");
		exit(code);
	}
	
	private function exit(?code:Int=0):Void
	{
		
		neko.Sys.exit(code);
	}
	
	/**
	* Note - will ignore recursive dependencies to avoid recursion loops!
	*/
	private function runCommand(commandClass:Class<ICommand>, ?hash:Hash<Dynamic>=null):Void
	{
		if(hash == null) hash = new Hash();
	
		
		var className:String = Type.getClassName(commandClass);	
		if(hash.exists(className)) return;
		
		hash.set(className, commandClass);
		
		var cmd:ICommand = createCommandInstance(commandClass);
		
		cmd.initialise();
		
		for(subCmd in cmd.beforeCommands)
		{
			runCommand(subCmd, hash);
		}
		Log.debug(className);
		
		cmd.execute();

		for(subCmd in cmd.afterCommands)
		{
			runCommand(subCmd, hash);
		}
	}
	
	private function createCommandInstance(commandClass:Class<ICommand>):ICommand
	{
		var cmd:ICommand = Type.createInstance(commandClass, []);
		cmd.console = console;
		return cmd;
	}
	
	public function getCommandFromString(?value:String):Class<ICommand>
	{
		var cmd:CommandDef = getCommandDefFromString(value);
		if(cmd == null) return null;
		return cmd.command;
	}
	
	public function getCommandDefFromString(?value:String):CommandDef
	{
		for(cmd in commands)
		{
			if(cmd.name == value)
			{
				return cmd;
			}
			else if(cmd.alt != null)
			{
				for(i in 0...cmd.alt.length)
				{
					if(cmd.alt[i] == value)
					{
						return cmd;
					}
				}
			}
		}
		return null;
	}
}


typedef CommandDef = 
{		
	var command:Class<ICommand>;
	var name:String;
	var alt:Array<String>;
	var description:String;
	var help:String;
	var visible:Bool;
	
}

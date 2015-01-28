/**
 * @autor rcam
 * @date 04.08.2014.
 * @company Gameduell GmbH
 */
package duell.build.objects;

import duell.helpers.DuellConfigHelper;
import duell.defines.DuellDefines;

import duell.helpers.PathHelper;
import duell.helpers.LogHelper;
import duell.helpers.XMLHelper;

import duell.objects.DuellLib;
import duell.objects.Haxelib;

import duell.build.objects.Configuration;
import duell.build.plugin.platform.PlatformConfiguration;
import duell.build.plugin.platform.PlatformXMLParser;

import haxe.io.Path;

import sys.io.File;
import sys.FileSystem;

import haxe.xml.Fast;
import haxe.Template;

using StringTools;

class DuellProjectXML
{
	/// PARSING STATE
	private var currentXML : Fast = null;
	private var currentDuellLib : DuellLib = null; /// currently being parsed lib, null if parsing the project
	private var currentXMLPath : Array<String> = []; /// used to resolve paths. Is used by all XML parsers (library and platform)
	/// --------------

	public var parsingConditions : Array<String>; /// used in validating elements for "if" or "unless"


	private function new() : Void
	{
	}

	private static var cache : DuellProjectXML;
	public static function getConfig() : DuellProjectXML
	{
		if(cache == null)
		{
			cache = new DuellProjectXML();
			return cache;
		}

		return cache;
	}

	public function parse()
	{
		parsingConditions = [];
		parsingConditions = parsingConditions.concat(Configuration.getConfigParsingDefines());
		parsingConditions = parsingConditions.concat(PlatformConfiguration.getConfigParsingDefines());

		if (FileSystem.exists(DuellConfigHelper.getDuellUserFileLocation()))
		{
			parseFile(DuellConfigHelper.getDuellUserFileLocation());
		}

		if (!FileSystem.exists(DuellDefines.PROJECT_CONFIG_FILENAME))
		{
			LogHelper.error('Project config file not found. There should be a ${DuellDefines.PROJECT_CONFIG_FILENAME} here');
		}

		parseFile(Sys.getCwd() + "/" + DuellDefines.PROJECT_CONFIG_FILENAME);

		parseDuellLibs();
	}

	private function parseFile(file : String)
	{		
		if (!PathHelper.isPathRooted(file))
			LogHelper.error("internal error, parseFile should only receive rooted paths.");

		currentXMLPath.push(Path.directory(file));

		Configuration.getData().SOURCES.push(currentXMLPath[currentXMLPath.length - 1]);

		var stringContent = File.getContent(file);

		stringContent = processXML(stringContent);

		currentXML = new Fast(Xml.parse(stringContent).firstElement());

		for (element in currentXML.elements) 
		{
			if (!XMLHelper.isValidElement(element, parsingConditions))
				continue;
			switch (element.name)
			{
				case 'app':
					parseAppElement(element);

				case 'output':
					parseOutputElement(element);

				case 'source':
					parseSourceElement(element);

				case 'main':
					parseMainElement(element);

				case 'haxe-compile-arg':
					parseHaxeCompileArgElement(element);

				case 'platform-config':
					parsePlatformConfigSection(element);		

				case 'library-config':
					parseLibraryConfigSection(element);

				case 'haxelib':
					parseHaxelibElement(element);

				case 'duelllib':
					parseDuellLibElement(element);

				case 'ndll':
					parseNDLLElement(element);

				case 'include':
					parseIncludeElement(element);
			}
		}

		currentXMLPath.pop();
	}

	private var libsAlreadyParsed = new Array<{name : String, version : String}>();
	private function parseDuellLibs()
	{
		/// BFS
		while (libsAlreadyParsed.length != Configuration.getData().DEPENDENCIES.DUELLLIBS.length) 
		{
			var duellLibsToParse = Configuration.getData().DEPENDENCIES.DUELLLIBS.copy();

			for (duellLibDef in duellLibsToParse)
			{
				if (libsAlreadyParsed.indexOf(duellLibDef) != -1)
					continue;

				libsAlreadyParsed.push(duellLibDef);

				var duellLib = DuellLib.getDuellLib(duellLibDef.name, duellLibDef.version);

				var xmlPath = duellLib.getPath() + '/' + DuellDefines.LIB_CONFIG_FILENAME;

				if (!FileSystem.exists(xmlPath))
				{
					LogHelper.println('${duellLib.name} does not have a ${DuellDefines.LIB_CONFIG_FILENAME}');
				}
				else
				{
					currentDuellLib = duellLib;

					parseFile(xmlPath);
				}
			}
		}
	}

	/// ---------------
	/// SECTION PARSERS
	/// ---------------

	private function parseHaxelibElement(lib : Fast)
	{
		var name = null;
		var version = null;
		if(lib.has.name)
		{
			name = lib.att.name;
		}

		if(lib.has.version)
		{
			version = lib.att.version;
		}
		else
		{
			version = "";
		}

		if (name != null && name != '')
		{
			var found = false;
			for (haxelibDef in Configuration.getData().DEPENDENCIES.HAXELIBS)
			{
				if (haxelibDef.name == name) /// only check the name, because validation was already done in the build command
				{
					found = true;
					break;
				}
			}

			if (!found)
			{
				Configuration.getData().DEPENDENCIES.HAXELIBS.push({name : name, version : version});
			}
		} 
	}

	private function parseDuellLibElement(lib : Fast)
	{	
		var name = null;
		var version = null;
		if(lib.has.name)
		{
			name = lib.att.name;
		}

		if(lib.has.version)
		{
			version = lib.att.version;
		}
		else
		{
			version = "";
		}

		if (name != null && name != '')
		{
			var found = false;
			for (duellLibDef in Configuration.getData().DEPENDENCIES.DUELLLIBS)
			{
				if (duellLibDef.name == name) /// only check the name, because validation was already done in the build command
				{
					found = true;
					break;
				}
			}

			if (!found)
			{
				Configuration.getData().DEPENDENCIES.DUELLLIBS.push({name : name, version : version});
			}
		} 
	}

	private function parseAppElement(element : Fast)
	{
		if (element.has.title)
		{
			Configuration.getData().APP.TITLE = element.att.title;
		}

		if (element.has.file)
		{
			Configuration.getData().APP.FILE = element.att.file;

			var checkFile = ~/^([0-9]|[A-Z]|[a-z]|_)+$/;
			if (!checkFile.match(Configuration.getData().APP.FILE))
				throw "app title can only have letters, numbers, and underscores, no spaces or other characters";
		}

		if (element.has.resolve("package")) ///package is a keyword
		{
			Configuration.getData().APP.PACKAGE = element.att.resolve("package");
		}

		if (element.has.company)
		{
			Configuration.getData().APP.COMPANY = element.att.company;
		}

		if (element.has.version)
		{
			Configuration.getData().APP.VERSION = element.att.version;
		}

		if (element.has.buildNumber)
		{
			Configuration.getData().APP.BUILD_NUMBER = element.att.buildNumber;
		}
	}

	private function parseOutputElement(element : Fast)
	{
		if (element.has.path)
		{
			Configuration.getData().OUTPUT = resolvePath(element.att.path);
		}
	}

	private function parseSourceElement(element : Fast)
	{
		if (element.has.path)
		{
			Configuration.getData().SOURCES.push(resolvePath(element.att.path));
		}
	}

	private function parseMainElement(element : Fast)
	{
		if (element.has.name)
		{
			Configuration.getData().MAIN = element.att.name;
		}
	}

	private function parseHaxeCompileArgElement(element : Fast)
	{
		if (element.has.value)
		{
			Configuration.getData().HAXE_COMPILE_ARGS.push(element.att.value);
		}
	}

	private function parsePlatformConfigSection(platformSectionXML : Fast)
	{
		PlatformXMLParser.parse(platformSectionXML);
	}

	private function parseLibraryConfigSection(xml : Fast)
	{
		for (element in xml.elements) 
		{
			if (!XMLHelper.isValidElement(element, parsingConditions))
				continue;

			var name = element.name;

			var parserClass = Type.resolveClass('duell.build.plugin.library.$name.LibraryXMLParser');

			if (parserClass != null)
			{
				var parseFunction : Dynamic = Reflect.field(parserClass, "parse");
				Reflect.callMethod(parserClass, parseFunction, [element]);
			}
		}
	}

	private function parseNDLLElement(element : Fast)
	{
		var name : String = "";
		var buildFilePath : String = "project/Build.xml";
		var binPath = "bin";
		var registerStatics = true;
		if (element.has.name)
		{
			name  = element.att.name;

			if (element.has.resolve("build-file-path"))
			{
				buildFilePath = element.att.resolve("build-file-path");
			}

			if (element.has.resolve("bin-path"))
			{
				binPath = element.att.resolve("bin-path");
			}	

			if (element.has.resolve("register-statics"))
			{
				registerStatics = (element.att.resolve("register-statics") == "true")? true : false;
			}

			Configuration.getData().NDLLS.push({REGISTER_STATICS : registerStatics, BIN_PATH : resolvePath(binPath), NAME : name, BUILD_FILE_PATH : resolvePath(buildFilePath)});
		}
	}

	private function parseIncludeElement(element : Fast)
	{
		if (element.has.path)
		{
			var path = resolvePath(element.att.path);

			parseFile(path);
		}
	}

	/// ---------------
	/// HELPERS
	/// ---------------

	public function resolvePath(path : String) : String
	{
		path = PathHelper.unescape(path);
		
		if (PathHelper.isPathRooted(path))
			return path;

		path = Path.join([currentXMLPath[currentXMLPath.length - 1], path]);
		return path;
	}

	private function processXML(xml : String) : String
	{
		var template = new haxe.Template(xml);

		xml = template.execute({}, {
			duelllib: function(_, s) return DuellLib.getDuellLib(s).getPath(),
			haxelib: function(_, s) return Haxelib.getHaxelib(s).getPath(),
			projectpath: function(_, s) return Sys.getCwd()
		});

		return xml;
	}
}

package debug;

import haxe.macro.Context;
import haxe.macro.Expr;
import sys.io.File;
import sys.io.Process;
import sys.FileSystem;
import haxe.xml.Access;
import StringTools;
import Sys;

class HaxelibInfo {
	public static macro function getHaxelibInfo():ExprOf<String> {
		#if !display
		try {
			// 定位项目根目录的 Project.xml。
			// 注意：iOS/Android 等原生目标由 lime 生成 Xcode/Gradle 工程后，
			// haxe 是在 export/<cfg>/<target>/... 子目录里被调用的，
			// 此时 Sys.getCwd() 并不是项目根目录，必须向上逐级查找。
			var projectPath = findProjectXml();
			if (projectPath == null) {
				// 找不到不应该中断构建，降级为「信息不可用」即可
				Context.warning("Project.xml not found (cwd: " + Sys.getCwd() + "), haxelib info disabled", Context.currentPos());
				return macro $v{"(haxelib info unavailable)"};
			}
			var xmlContent = File.getContent(projectPath);
			var xml = Xml.parse(xmlContent);
			var access = new Access(xml.firstElement());
			
			// 收集所有 haxelib 名称
			var libNames = [];
			for (el in access.nodes.haxelib) {
				var name = el.att.name;
				libNames.push(name);
			}
			
			// 执行 haxelib list 命令获取全局库版本
			// 注意：必须先把 stdout/stderr 读空再取 exitCode，
			// 否则在 Windows 上输出量超过管道缓冲区时会死锁。
			var process = new Process("haxelib", ["list"]);
			var output = process.stdout.readAll().toString();
			var error = process.stderr.readAll().toString();
			var exitCode = process.exitCode();
			process.close();
			if (exitCode != 0) {
				Context.warning("haxelib list failed: " + error, Context.currentPos());
			}
			
			// 记录原始输出用于调试（只记录前500个字符）
			var debugOutput = output.length > 500 ? output.substring(0, 500) + "..." : output;
			log("haxelib list output (first 500 chars):\n" + debugOutput);
			
			// 解析输出：每行格式 "libname: version"
			var libInfoMap = new Map<String, String>();
			var allLines = output.split("\n");
			
			log("Parsing haxelib list output (" + allLines.length + " lines)");
			
			for (i in 0...allLines.length) {
				var rawLine = allLines[i];
				var trimmed = StringTools.trim(rawLine);
				if (trimmed.length == 0) continue;
				
				// 检查是否是缩进的行（版本列表）- 以空格或制表符开头
				if (rawLine.length > 0 && (rawLine.charCodeAt(0) == 32 || rawLine.charCodeAt(0) == 9)) {
					// 缩进行：这是前一个库的另一个版本，跳过
					continue;
				}
				
				// 新库行，格式 "libname: version"
				var colonIndex = rawLine.indexOf(":");
				if (colonIndex == -1) continue;
				
				var lib = StringTools.trim(rawLine.substring(0, colonIndex));
				var versionPart = "";
				
				// 提取版本信息：冒号后的部分
				var afterColon = rawLine.substring(colonIndex + 1);
				var firstLine = afterColon;
				
				// 如果有换行符，取第一行
				var newlineIndex = firstLine.indexOf("\n");
				if (newlineIndex != -1) {
					firstLine = firstLine.substring(0, newlineIndex);
				}
				
				firstLine = StringTools.trim(firstLine);
				// 移除可能的回车符
				firstLine = StringTools.replace(firstLine, "\r", "");
				
				if (firstLine.length > 0) {
					// 查找第一个方括号对
					var openBracket = firstLine.indexOf("[");
					var closeBracket = firstLine.indexOf("]");
					if (openBracket != -1 && closeBracket != -1 && closeBracket > openBracket) {
						// 提取括号内的内容
						var inside = firstLine.substring(openBracket + 1, closeBracket);
						// 处理特殊标记
						if (inside == "git") {
							versionPart = "git";
						} else if (StringTools.startsWith(inside, "dev:")) {
							versionPart = "dev";
						} else if (inside == "current" || inside == "当前") {
							// 版本号在括号外（方括号之前的部分）
							var beforeBracket = firstLine.substring(0, openBracket);
							versionPart = StringTools.trim(beforeBracket);
						} else {
							// 括号内就是版本号
							versionPart = inside;
						}
					} else {
						// 没有方括号，使用整个字符串作为版本号
						versionPart = firstLine;
					}
				}
				
				// 如果版本号为空，设置默认文本
				if (versionPart.length == 0) {
					versionPart = "(no version)";
				}
				
				log("  Parsed: " + lib + " -> '" + versionPart + "'");
				libInfoMap.set(lib, versionPart);
			}
			
			// 调试信息：记录我们解析到了什么
			log("Found " + libNames.length + " haxelibs in Project.xml");
			for (lib in libNames) {
				if (libInfoMap.exists(lib)) {
					log("  " + lib + " -> " + libInfoMap.get(lib));
				} else {
					log("  " + lib + " -> NOT FOUND in haxelib list");
				}
			}
			
			// 构建信息字符串
			var infoLines = [];
			for (lib in libNames) {
				if (libInfoMap.exists(lib)) {
					infoLines.push(lib + " " + libInfoMap.get(lib));
				} else {
					infoLines.push(lib + " (unknown)");
				}
			}
			
			var result = infoLines.join("\n");
			log("Final haxelib info string:\n" + result);
			return macro $v{result};
		} catch (e:Dynamic) {
			Context.warning("Failed to get haxelib info: " + Std.string(e), Context.currentPos());
			return macro $v{"(haxelib info unavailable)"};
		}
		#else
		return macro $v{""};
		#end
	}

	#if macro
	/**
	 * 从当前工作目录、以及宏调用点所在源文件目录出发，向上逐级查找 Project.xml。
	 * @return 找到的绝对/相对路径，找不到返回 null
	 */
	static function findProjectXml():Null<String> {
		var startDirs:Array<String> = [];

		var cwd = Sys.getCwd();
		if (cwd != null && cwd.length > 0)
			startDirs.push(cwd);

		// 宏调用点所在的 .hx 文件（如 source/debug/FPSCounter.hx）同样可以反推项目根目录
		var posFile = Context.getPosInfos(Context.currentPos()).file;
		if (posFile != null && posFile.length > 0) {
			try {
				startDirs.push(FileSystem.absolutePath(haxe.io.Path.directory(posFile)));
			} catch (_:Dynamic) {}
		}

		for (start in startDirs) {
			var dir = haxe.io.Path.removeTrailingSlashes(StringTools.replace(start, "\\", "/"));
			var depth = 0;
			while (dir != null && dir.length > 0 && depth < 12) {
				var candidate = dir + "/Project.xml";
				if (FileSystem.exists(candidate))
					return candidate;

				var parent = haxe.io.Path.directory(dir);
				if (parent == null || parent == dir)
					break;
				dir = parent;
				depth++;
			}
		}
		return null;
	}

	/**
	 * 编译期日志开关。
	 *
	 * 只影响「编译终端打印的 INFO 诊断信息」，不影响宏的返回值，
	 * 因此 FPS 计数器里的 Libs 列表在任何构建配置下都照常显示。
	 *
	 * 注意：这里必须用运行时的 Context.defined()，不能用 #if debug ——
	 * 宏体内的 #if 判断的是「编译宏本身」时的 define，而不是目标构建的 define。
	 */
	static function log(msg:String):Void {
		if (Context.defined("debug") || Context.defined("HAXELIB_INFO_VERBOSE"))
			Context.info(msg, Context.currentPos());
	}
	#end
}
package debug;

import flixel.FlxG;
import openfl.Lib;
import haxe.Timer;
import openfl.text.TextField;
import openfl.text.TextFormat;
import lime.system.System as LimeSystem;
import states.MainMenuState;
import debug.GameVersion;
import debug.HaxelibInfo;
import openfl.display.Sprite;
import flixel.FlxState;
import openfl.utils.Assets;
import backend.ClientPrefs;
import backend.Paths;
import StringTools;
#if cpp
#if windows
@:cppFileCode('#include <windows.h>')
#elseif (ios || mac)
@:cppFileCode('#include <mach-o/arch.h>')
#else
@:headerInclude('sys/utsname.h')
#end
#end
class FPSCounter extends Sprite
{
	public var currentFPS(default, null):Int = 0;

	public var memoryMegas(get, never):Float;
	public var memoryPeakMegas(default, null):Float = 0;

	@:noCompletion private var times:Array<Float>;
	@:noCompletion private var lastFramerateUpdateTime:Float;
	@:noCompletion private var updateTime:Int;
	@:noCompletion private var framesCount:Int;
	@:noCompletion private var prevTime:Int;
	@:noCompletion private var currentTime:Float;
	@:noCompletion private var cacheCount:Int;

	public var objectCount(default, null):Int = 0;

	@:noCompletion private var lastObjectCountUpdate:Float = 0;
	@:noCompletion private var lastDelayUpdateTime:Float = 0;
	@:noCompletion private var currentDelay:Float = 0;

	public var os:String = '';

	// 文本字段
	private var allInfoText:TextField;
	
	// 背景
	private var bgSprite:Sprite;

	// 布局参数
	private var lineHeight:Float = 18;

	// 性能优化变量
	private var lastFpsUpdateTime:Float = 0;

	public var fontName:String = Paths.font("vcr.ttf");

	public function new(x:Float = 10, y:Float = 10, color:flixel.util.FlxColor = 0xFF000000)
	{
		super();

		// 创建背景
		bgSprite = new Sprite();
		addChild(bgSprite);

		// 创建单个文本字段，显示所有信息
		allInfoText = createTextField(ClientPrefs.data.fpsFontSize, ClientPrefs.data.fpsColor);
		addChild(allInfoText);

		#if !officialBuild
		if (LimeSystem.platformName == LimeSystem.platformVersion || LimeSystem.platformVersion == null)
			os = 'OS: ${LimeSystem.platformName}' #if cpp + ' ${getArch() != 'Unknown' ? getArch() : ''}' #end;
		else
			os = 'OS: ${LimeSystem.platformName}' #if cpp + ' ${getArch() != 'Unknown' ? getArch() : ''}' #end + ' - ${LimeSystem.platformVersion}';
		#end

		positionFPS(x, y);

		// 初始化 FPS 计算变量
		times = [];
		lastFramerateUpdateTime = Timer.stamp();
		prevTime = Lib.getTimer();
		updateTime = prevTime + 500;
		framesCount = 0;
		currentTime = 0;
		cacheCount = 0;

		// 初始化更新时间
		lastFpsUpdateTime = Timer.stamp();
	}

	private function createTextField(size:Int, color:flixel.util.FlxColor, bold:Bool = false):TextField
	{
		var tf = new TextField();
		tf.selectable = false;
		tf.mouseEnabled = false;
		tf.defaultTextFormat = new TextFormat(fontName, size, (color.red << 16) | (color.green << 8) | color.blue, bold);
		tf.autoSize = LEFT;
		return tf;
	}

	public dynamic function updateText():Void
	{
		var currentTime = Timer.stamp();
		var memory:Float = 0;
		
		try
		{
			memory = memoryMegas;
			// 确保内存值是有效的数字
			if (memory < 0 || !Std.is(memory, Float))
			{
				memory = 0;
			}
		}
		catch (e:Dynamic)
		{
			memory = 0;
		}

		// 更新内存峰值
		if (memory > memoryPeakMegas)
		{
			memoryPeakMegas = memory;
		}

		// 构建所有信息的文本 - 使用数组避免多余空行
		var textLines:Array<String> = [];

		// FPS信息 - 根据设置显示
		if (ClientPrefs.data.fpsShowFPS) textLines.push('FPS: $currentFPS');
		if (ClientPrefs.data.fpsShowDelay) textLines.push('Delay: ${currentDelay}ms');
		if (ClientPrefs.data.fpsShowRAM) textLines.push('RAM: ${formatMemory(memory)}');
		if (ClientPrefs.data.fpsShowMemPeak) textLines.push('MEM Peak: ${formatMemory(memoryPeakMegas)}');
		if (ClientPrefs.data.fpsShowObjects) textLines.push('Objects: $objectCount');
		
		// 版本信息
		if (ClientPrefs.data.exgameversion)
		{
			textLines.push('');
			textLines.push('Psych ${MainMenuState.psychEngineVersion}');
			textLines.push('Kathy ${MainMenuState.kathyEngineVersion}');
			textLines.push('Commit: ${GameVersion.getGitCommitCount()} (${GameVersion.getGitCommitHash()})');
			textLines.push('Build: ${GameVersion.getBuildTime()}');
		}
		
		// 显示haxelib信息 - 独立于版本信息
		if (ClientPrefs.data.showHaxelibs)
		{
			textLines.push('');
			textLines.push('Libs:');
			textLines.push(HaxelibInfo.getHaxelibInfo());
		}

		// 显示操作系统信息
		if (ClientPrefs.data.showRunningOS)
		{
			textLines.push('');
			textLines.push(os);
		}

		// 系统信息 - 只有当显示版本信息或者显示haxelib或者显示操作系统信息时才添加
		if (ClientPrefs.data.exgameversion || ClientPrefs.data.showHaxelibs || ClientPrefs.data.showRunningOS)
		{
			var hasSystemInfo = false;
			var lastWasBlank:Bool = textLines.length > 0 && textLines[textLines.length - 1] == '';

			// 平台信息
			if (ClientPrefs.data.fpsShowPlatform)
			{
				if (!hasSystemInfo && !lastWasBlank)
				{
					textLines.push('');
					lastWasBlank = true;
					hasSystemInfo = true;
				}
				else
				{
					hasSystemInfo = true;
				}
				#if cpp
				var arch = getArch() != 'Unknown' ? ' (${getArch()})' : '';
				#else
				var arch = '';
				#end
				textLines.push('Platform: ${LimeSystem.platformName}$arch');
				lastWasBlank = false;
			}

			// 平台版本
			if (ClientPrefs.data.fpsShowOSVersion)
			{
				if (LimeSystem.platformVersion != null && LimeSystem.platformVersion != LimeSystem.platformName)
				{
					if (!hasSystemInfo && !lastWasBlank)
					{
						textLines.push('');
						lastWasBlank = true;
						hasSystemInfo = true;
					}
					else
					{
						hasSystemInfo = true;
					}
					textLines.push('OS Ver.: ${LimeSystem.platformVersion}');
					lastWasBlank = false;
				}
			}

			// 显示器信息
			try
			{
				var display = LimeSystem.getDisplay(0);
				if (display != null)
				{
					if (ClientPrefs.data.fpsShowResolution)
					{
						if (!hasSystemInfo && !lastWasBlank)
						{
							textLines.push('');
							lastWasBlank = true;
							hasSystemInfo = true;
						}
						else
						{
							hasSystemInfo = true;
						}
						textLines.push('Resolution: ${display.currentMode.width}x${display.currentMode.height}');
						lastWasBlank = false;
					}

					if (ClientPrefs.data.fpsShowRefreshRate)
					{
						if (!hasSystemInfo && !lastWasBlank)
						{
							textLines.push('');
							lastWasBlank = true;
							hasSystemInfo = true;
						}
						else
						{
							hasSystemInfo = true;
						}
						textLines.push('Refresh: ${display.currentMode.refreshRate}Hz');
						lastWasBlank = false;
					}
				}
			}
			catch (e:Dynamic)
			{
			}
		}

		// 移除末尾的空行
		while (textLines.length > 0 && textLines[textLines.length - 1] == '')
		{
			textLines.pop();
		}

		var allText = textLines.join('\n');

		// 转换颜色为十六进制字符串
		var colorHex = StringTools.hex((ClientPrefs.data.fpsColor.red << 16) | (ClientPrefs.data.fpsColor.green << 8) | ClientPrefs.data.fpsColor.blue, 6);
		allInfoText.htmlText = '<font color="#$colorHex">$allText</font>';
		
		// 更新字体大小
		var textColorInt = (ClientPrefs.data.fpsColor.red << 16) | (ClientPrefs.data.fpsColor.green << 8) | ClientPrefs.data.fpsColor.blue;
		allInfoText.defaultTextFormat = new TextFormat(fontName, ClientPrefs.data.fpsFontSize, textColorInt, false);
		
		// 更新透明度
		this.alpha = ClientPrefs.data.fpsOpacity;
		
		// 更新背景
		updateBackground();
	}
	
	private function updateBackground():Void
	{
		bgSprite.graphics.clear();
		
		if (ClientPrefs.data.fpsBgEnabled)
		{
			var padding = ClientPrefs.data.fpsBgPadding;
			var w = allInfoText.width + padding * 2;
			var h = allInfoText.height + padding * 2;
			
			var bgColorInt = (ClientPrefs.data.fpsBgColor.red << 16) | (ClientPrefs.data.fpsBgColor.green << 8) | ClientPrefs.data.fpsBgColor.blue;
			bgSprite.graphics.beginFill(bgColorInt, ClientPrefs.data.fpsBgOpacity);
			bgSprite.graphics.drawRect(-padding, -padding, w, h);
			bgSprite.graphics.endFill();
		}
	}
	
	// 重新应用所有设置
	public function applySettings():Void
	{
		updateText();
		positionFPS(x, y);
	}

	private override function __enterFrame(deltaTime:Float):Void
	{
		if (!visible)
			return;

		// 限制 Delay 更新频率为每 0.2 秒
		if (Timer.stamp() - lastDelayUpdateTime > 0.2)
		{
			// 更新延迟时间（以毫秒为单位）
			currentDelay = Math.round(deltaTime * 1000) / 1000;
			lastDelayUpdateTime = Timer.stamp();
		}

		// 持续追踪时间（用于 FPS 计算）
		currentTime += deltaTime;
		times.push(currentTime);

		while (times[0] < currentTime - 1000)
		{
			times.shift();
		}

		var currentCount = times.length;
		// 只在显示更新时更新 FPS 值，避免数值跳动
		if (Timer.stamp() - lastFpsUpdateTime > 0.5)
		{
			currentFPS = Math.round((currentCount + cacheCount) / 2);
			cacheCount = currentCount;
			lastFpsUpdateTime = Timer.stamp();
			updateText();
		}

		if (Timer.stamp() - lastObjectCountUpdate > 2.0)
		{
			objectCount = countObjects(FlxG.state);
			lastObjectCountUpdate = Timer.stamp();
		}

		if (ClientPrefs.data.fpsRework)
		{
			if (FlxG.stage.window.frameRate != ClientPrefs.data.framerate && FlxG.stage.window.frameRate != FlxG.game.focusLostFramerate)
				FlxG.stage.window.frameRate = ClientPrefs.data.framerate;

			var nowTime = openfl.Lib.getTimer();
			framesCount++;

			if (nowTime >= updateTime)
			{
				var elapsed = nowTime - prevTime;
				framesCount = 0;
				prevTime = nowTime;
				updateTime = nowTime + 500;
			}

			if ((FlxG.updateFramerate >= currentFPS + 5 || FlxG.updateFramerate <= currentFPS - 5)
				&& haxe.Timer.stamp() - lastFramerateUpdateTime >= 1.5
				&& currentFPS >= 30)
			{
				FlxG.updateFramerate = FlxG.drawFramerate = currentFPS;
				lastFramerateUpdateTime = haxe.Timer.stamp();
			}
		}
	}

	private function countObjects(state:FlxState, depth:Int = 0):Int
	{
		if (depth > 10)
			return 0;

		var count:Int = 0;

		if (state == null)
			return 0;

		count += countGroupMembers(state.members, depth + 1);

		if (state.subState != null)
		{
			count += countGroupMembers(state.subState.members, depth + 1);
		}

		return count;
	}

	private function countGroupMembers(members:Array<flixel.FlxBasic>, depth:Int = 0):Int
	{
		if (depth > 10)
			return 0;

		var count:Int = 0;

		if (members == null)
			return 0;

		for (member in members)
		{
			if (member != null && member.exists)
			{
				count++;

				if (Std.isOfType(member, flixel.group.FlxGroup.FlxTypedGroup))
				{
					var group:flixel.group.FlxGroup.FlxTypedGroup<flixel.FlxBasic> = cast member;
					count += countGroupMembers(group.members, depth + 1);
				}
			}
		}

		return count;
	}

	function get_memoryMegas():Float
	{
		#if cpp
		try
		{
			var memValue:Dynamic = cpp.vm.Gc.memInfo64(cpp.vm.Gc.MEM_INFO_USAGE);
			if (Std.is(memValue, Float) || Std.is(memValue, Int))
			{
				var mem:Float = cast memValue;
				if (Math.isFinite(mem) && mem >= 0)
					return mem;
			}
		}
		catch (e:Dynamic) {}

		try
		{
			var memValue:Dynamic = cpp.vm.Gc.memInfo(cpp.vm.Gc.MEM_INFO_USAGE);
			if (Std.is(memValue, Float) || Std.is(memValue, Int))
			{
				var mem:Float = cast memValue;
				if (Math.isFinite(mem) && mem >= 0)
					return mem;
			}
		}
		catch (e:Dynamic) {}
		#end

		return 0;
	}

	public inline function positionFPS(X:Float, Y:Float, ?scale:Float = 1)
	{
		scaleX = scaleY = #if android (scale > 1 ? scale : 1) #else (scale < 1 ? scale : 1) #end;

		var spacing = ClientPrefs.data.fpsSpacing;
		var isRight = ClientPrefs.data.fpsPosition.indexOf("RIGHT") != -1;
		var isBottom = ClientPrefs.data.fpsPosition.indexOf("BOTTOM") != -1;

		// 使用 OpenFL stage 坐标系而非 FlxG.game
		var stage = Lib.current.stage;
		if (stage != null)
		{
			if (isRight)
			{
				x = stage.stageWidth - 200 - spacing;
			}
			else
			{
				x = spacing;
			}

			if (isBottom)
			{
				var textHeight = allInfoText.height;
				y = stage.stageHeight - textHeight - spacing;
			}
			else
			{
				y = spacing;
			}
		}
	}

	#if cpp
	#if windows
	private function getArch():String
	{
		@:functionCode('
        SYSTEM_INFO osInfo;
        GetSystemInfo(&osInfo);
        switch(osInfo.wProcessorArchitecture)
        {
            case 9: return ::String("x86_64");
            case 5: return ::String("ARM");
            case 12: return ::String("ARM64");
            case 6: return ::String("IA-64");
            case 0: return ::String("x86");
            default: return ::String("Unknown");
        }
    ')
		return "Unknown";
	}
	#elseif (ios || mac)
	private function getArch():String
	{
		@:functionCode('
        const NXArchInfo *archInfo = NXGetLocalArchInfo();
        return ::String(archInfo == NULL ? "Unknown" : archInfo->name);
    ')
		return "Unknown";
	}
	#else
	private function getArch():String
	{
		@:functionCode('
        struct utsname osInfo{};
        uname(&osInfo);
        return ::String(osInfo.machine);
    ')
		return "Unknown";
	}
	#end
	#else
	private function getArch():String
	{
		var platform = LimeSystem.platformName;
		if (platform != null && (platform.indexOf("x86_64") >= 0 || platform.indexOf("arm64") >= 0 || platform.indexOf("ARM64") >= 0))
			return platform;
		return "Unknown";
	}
	#end

	/**
	 * 格式化内存显示，根据设置决定是否强制显示MB
	 */
	private function formatMemory(memoryInBytes:Float):String
	{
		if (memoryInBytes < 0 || memoryInBytes != memoryInBytes)
		{
			memoryInBytes = 0;
		}

		if (ClientPrefs.data.fpsForceMB)
		{
			var memoryInMB = memoryInBytes / (1024 * 1024);
			return Std.string(Math.round(memoryInMB)) + "MB";
		}

		try
		{
			return flixel.util.FlxStringUtil.formatBytes(memoryInBytes);
		}
		catch (e:Dynamic)
		{
			var memoryInMB = memoryInBytes / (1024 * 1024);
			return Std.string(Math.round(memoryInMB)) + "MB";
		}
	}
}
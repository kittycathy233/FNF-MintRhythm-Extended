package states;

import backend.ClientPrefs;
import backend.Difficulty;
import backend.Highscore;
import backend.LanguageBasic;
import backend.Mods;
import backend.Paths;
import backend.Song;
import backend.WeekData;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import states.FreeplayState;
import states.LoadingState;
import states.PlayState;
import states.StoryMenuState;
import states.TitleState;
import backend.MusicBeatState;
import sys.FileSystem;
import tjson.TJSON;

/**
 * 命令行直启状态：根据启动参数直接进入指定模组(Mod)的指定周(Week)的指定曲目(Song)。
 * 若未找到则显示提示，按 ENTER / ESC 返回 FreeplayState。
 *
 * 启动参数示例：
 *   KathyEngine.exe --mod "My Mod" --week "week1" --song "bopeebo" --diff "Hard"
 *   KathyEngine.exe --play "My Mod|week1|bopeebo|Hard"
 *   KathyEngine.exe "My Mod" "week1" "bopeebo"      (位置参数: mod week song [diff])
 */
class CommandLineLaunchState extends MusicBeatState
{
	/** 由 Main 解析命令行后填入 */
	public static var launchData:CommandLineLaunch = null;

	var failed:Bool = false;
	var errorMessage:String = '';
	var errorText:FlxText = null;
	var errorBg:FlxSprite = null;

	override function create():Void
	{
		// 与 TitleState 保持一致的基础初始化（正常流程下这些在 TitleState / LogoState 完成）。
		// 命令行直启跳过了标题/Logo，所以这里手动补齐，避免 PlayState 内全局脚本因未初始化而空引用。
		if (!TitleState.initialized)
		{
			ClientPrefs.loadPrefs();
			Highscore.load();
			LanguageBasic.reloadPhrases();

			MobileData.init(); // 初始化移动端存档(FlxSave)，否则脚本访问 getMobileControlsAsString 会空引用

			#if MODS_ALLOWED
			Mods.pushGlobalMods(); // 载入全局模组，供脚本路径解析
			#end
			Mods.loadTopMod();

			// 从存档恢复周完成状态
			if (FlxG.save.data.weekCompleted != null)
				StoryMenuState.weekCompleted = FlxG.save.data.weekCompleted;

			FlxG.mouse.useSystemCursor = ClientPrefs.data.systemCursor;

			TitleState.initialized = true;
		}

		FlxG.mouse.visible = false;

		if (launchData == null || launchData.song == null || launchData.song.trim().length == 0)
		{
			// 没有有效参数，直接进 Freeplay
			MusicBeatState.switchState(new FreeplayState());
			return;
		}

		attemptLaunch();

		if (failed)
			buildErrorUI();

		super.create();
	}

	function attemptLaunch():Void
	{
		var modFolder:String = resolveModFolder(launchData.mod);
		if (modFolder == null)
		{
			fail('未找到模组(Mod)：' + launchData.mod + '\n\n按 ENTER 或 ESC 返回 Freeplay');
			return;
		}

		Mods.currentModDirectory = modFolder;

		var leWeek:WeekData = findWeek(modFolder, launchData.week);
		if (leWeek == null)
		{
			fail('在模组 "' + modFolder + '" 中未找到周(Week)：' + launchData.week + '\n\n按 ENTER 或 ESC 返回 Freeplay');
			return;
		}

		// 在周内查找曲目
		var songName:String = null;
		var songFolder:String = modFolder;
		var q:String = Paths.formatToSongPath(launchData.song);
		for (song in leWeek.songs)
		{
			if (Paths.formatToSongPath(song[0]) == q)
			{
				songName = song[0];
				if (song.length > 3 && Std.isOfType(song[3], String) && (song[3] : String).trim().length > 0)
					songFolder = song[3];
				break;
			}
		}
		if (songName == null)
		{
			fail('在周 "' + launchData.week + '" 中未找到曲目(Song)：' + launchData.song + '\n\n按 ENTER 或 ESC 返回 Freeplay');
			return;
		}

		var diffIndex:Int = resolveDifficulty(leWeek, launchData.difficulty);

		Mods.currentModDirectory = songFolder;
		PlayState.isStoryMode = false;
		PlayState.isCommandLineMode = true; // 标记命令行直启，禁用调试/退出主界面/选项，并改变结算行为
		PlayState.storyWeek = findWeekIndex(modFolder, launchData.week); // 全局周索引；未命中则 0
		PlayState.storyDifficulty = diffIndex;

		var songLowercase:String = Paths.formatToSongPath(songName);
		var poop:String = Highscore.formatSong(songLowercase, diffIndex);

		var songData = Song.loadFromJson(poop, songLowercase);
		if (songData == null)
		{
			fail('无法加载谱面文件：' + poop + '\n(模组目录: ' + songFolder + ')\n\n按 ENTER 或 ESC 返回 Freeplay');
			return;
		}

		// 沿用 FreeplayState 的逻辑：设定节拍并启动伴奏（paused），
		// 否则 PlayState.create() 里的全局脚本访问 FlxG.sound.music.length 会空引用。
		Conductor.bpm = PlayState.SONG.bpm;
		Conductor.mapBPMChanges(PlayState.SONG);
		Conductor.songPosition = 0;
		FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song, PlayState.SONG.specialInst), 0.8);
		if (FlxG.sound.music != null)
			FlxG.sound.music.pause();

		trace('CommandLine Launch -> Mod: $modFolder | Week: ${leWeek.weekName} | Song: $songName | Diff: ' + Difficulty.list[diffIndex]);

		FlxTransitionableState.skipNextTransIn = true;
		LoadingState.prepareToSong();
		LoadingState.loadAndSwitchState(new PlayState());
	}

	/**
	 * 在 WeekData.weeksList 中查找匹配周的全局索引（与 FreeplayState 中 songs[].week 一致）。
	 * 优先按 fileName / weekName 匹配；找不到返回 0（不影响进歌，仅脚本 week 变量为 null）。
	 */
	function findWeekIndex(modFolder:String, weekQuery:String):Int
	{
		var q:String = Paths.formatToSongPath(weekQuery);
		for (i in 0...WeekData.weeksList.length)
		{
			var wd:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			if (wd == null)
				continue;
			if (wd.folder != modFolder)
				continue;
			if (Paths.formatToSongPath(wd.fileName) == q || (wd.weekName != null && Paths.formatToSongPath(wd.weekName) == q))
				return i;
		}
		return 0;
	}

	/** 根据模组名(文件夹名)查找模组文件夹，忽略大小写与空格 */
	function resolveModFolder(query:String):String
	{
		if (query == null || query.trim().length == 0)
			return null;
		var q:String = Paths.formatToSongPath(query).toLowerCase();
		for (folder in Mods.getModDirectories())
		{
			if (Paths.formatToSongPath(folder).toLowerCase() == q)
				return folder;
		}
		return null;
	}

	/** 在模组 weeks/ 目录下查找匹配的周文件（按文件名或 weekName 字段匹配） */
	function findWeek(modFolder:String, weekQuery:String):WeekData
	{
		if (weekQuery == null || weekQuery.trim().length == 0)
			return null;
		var weeksDir:String = Paths.mods(modFolder + '/weeks/');
		var q:String = Paths.formatToSongPath(weekQuery);
		if (FileSystem.exists(weeksDir))
		{
			for (file in FileSystem.readDirectory(weeksDir))
			{
				if (!file.endsWith('.json'))
					continue;
				var path:String = weeksDir + file;
				var base:String = file.substr(0, file.length - 5);
				try
				{
					var raw:String = File.getContent(path);
					var wf:Dynamic = TJSON.parse(raw);
					if (Paths.formatToSongPath(base) == q)
						return buildWeek(wf, base, modFolder);
					if (wf.weekName != null && Paths.formatToSongPath(wf.weekName) == q)
						return buildWeek(wf, base, modFolder);
				}
				catch (e:Dynamic)
				{
				}
			}
		}
		return null;
	}

	function buildWeek(wf:Dynamic, fileName:String, modFolder:String):WeekData
	{
		var wd:WeekData = new WeekData(wf, fileName);
		wd.folder = modFolder;
		return wd;
	}

	/** 解析难度，返回在 Difficulty.list 中的索引；找不到时使用默认难度 */
	function resolveDifficulty(week:WeekData, requested:String):Int
	{
		var diffs:Array<String> = (week.difficulties != null && week.difficulties.trim().length > 0)
			? week.difficulties.split(',').map(function(s) return s.trim())
			: Difficulty.defaultList.copy();

		var cleaned:Array<String> = [];
		for (d in diffs)
			if (d.length > 0)
				cleaned.push(d);
		if (cleaned.length == 0)
			cleaned = Difficulty.defaultList.copy();
		Difficulty.list = cleaned;

		if (requested == null || requested.trim().length == 0)
		{
			var idx:Int = indexOfDiff(cleaned, 'Normal');
			return idx >= 0 ? idx : (cleaned.length > 1 ? 1 : 0);
		}
		var req:String = Paths.formatToSongPath(requested.trim());
		var i:Int = indexOfDiffFormatted(cleaned, req);
		if (i >= 0)
			return i;
		// 未找到指定难度，回退到默认难度
		var def:Int = indexOfDiff(cleaned, 'Normal');
		return def >= 0 ? def : 0;
	}

	function indexOfDiff(arr:Array<String>, name:String):Int
	{
		var n:String = Paths.formatToSongPath(name);
		for (i in 0...arr.length)
			if (Paths.formatToSongPath(arr[i]) == n)
				return i;
		return -1;
	}

	function indexOfDiffFormatted(arr:Array<String>, formatted:String):Int
	{
		for (i in 0...arr.length)
			if (Paths.formatToSongPath(arr[i]) == formatted)
				return i;
		return -1;
	}

	function fail(msg:String):Void
	{
		failed = true;
		errorMessage = msg;
	}

	function buildErrorUI():Void
	{
		errorBg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		errorBg.alpha = 0.7;
		add(errorBg);

		errorText = new FlxText(50, 0, FlxG.width - 100, errorMessage, 24);
		errorText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE_FAST, FlxColor.BLACK);
		errorText.screenCenter();
		add(errorText);
	}

	override function update(elapsed:Float):Void
	{
		if (failed)
		{
			if (controls.ACCEPT || controls.BACK || FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.ESCAPE)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new FreeplayState());
				return;
			}
		}
		super.update(elapsed);
	}
}

typedef CommandLineLaunch =
{
	var mod:String;
	var week:String;
	var song:String;
	@:optional var difficulty:String;
}

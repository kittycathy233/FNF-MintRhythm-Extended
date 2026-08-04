package states;

import backend.WeekData;
import backend.Highscore;
import backend.Song;
import backend.SongMetadata;
import backend.Conductor;
import objects.HealthIcon;
import objects.MusicPlayer;
import options.GameplayChangersSubstate;
import substates.ResetScoreSubState;
import flixel.math.FlxMath;
import flixel.util.FlxDestroyUtil;
import flixel.tweens.FlxTween;
import flixel.graphics.FlxGraphic;
import openfl.utils.Assets;
import haxe.Json;
import backend.ui.PsychUIInputText;
#if FEATURE_FILESYSTEM
import sys.FileSystem;
import sys.io.File;
import backend.Mods;
#end

class FreeplayState extends MusicBeatState
{
	public static var isFreeplayPlayingMusic:Bool = false;

	// 谱面数据缓存：避免试听和进入游戏时重复加载同一谱面
	private static var _songDataCache:Map<String, SwagSong> = new Map();
	private static var _songPathCache:Map<String, String> = new Map();

	// 后台预解析：在玩家还在浏览列表时就把选中曲目的谱面 JSON 解析好，
	// 这样按下确认键时不需要在主线程做 File.getContent + Json.parse，避免掉帧卡顿。
	#if (sys && FEATURE_FILESYSTEM)
	private static var _prefetchMutex:sys.thread.Mutex = new sys.thread.Mutex();
	private static var _prefetchDone:Map<String, SwagSong> = new Map(); // 仅在持锁时访问
	private static var _prefetchBusy:Map<String, Bool> = new Map(); // 仅主线程访问
	#end

	// 把后台线程解析好的谱面并入主缓存（只在主线程调用）
	private static function drainPrefetched():Void
	{
		#if (sys && FEATURE_FILESYSTEM)
		_prefetchMutex.acquire();
		for (key => data in _prefetchDone)
		{
			_prefetchBusy.remove(key);
			if (data != null && !_songDataCache.exists(key))
				_songDataCache.set(key, data);
		}
		_prefetchDone.clear();
		_prefetchMutex.release();
		#end
	}

	// 获取缓存的谱面数据，若不存在则加载并缓存
	private static function getCachedSongData(folder:String, poop:String, songLowercase:String):SwagSong
	{
		drainPrefetched();

		var cacheKey:String = folder + '_' + poop;
		var songData:SwagSong = _songDataCache.get(cacheKey);
		if (songData == null)
		{
			songData = Song.loadFromJson(poop, songLowercase);
			if (songData != null)
			{
				_songDataCache.set(cacheKey, songData);
				_songPathCache.set(cacheKey, Song.chartPath);
			}
			return songData;
		}

		// 命中缓存时同样要重新应用全局状态，否则 PlayState.SONG 还停留在上一次加载的谱面
		return Song.applyChart(songData, songLowercase, _songPathCache.get(cacheKey));
	}

	// 当前想要预解析的曲目 key，以及停留多久后才真正开始预解析（避免快速滚动列表时狂开线程）
	var prefetchKey:String = null;
	var prefetchDelay:Float = 0;
	private static inline var PREFETCH_DELAY:Float = 1.0;

	function updateChartPrefetch(elapsed:Float):Void
	{
		#if (sys && FEATURE_FILESYSTEM)
		drainPrefetched();

		if (player.playingMusic || songs.length == 0 || curDifficulty < 0 || curSelected < 0 || curSelected >= songs.length)
			return;

		var meta:SongMetadata = songs[curSelected];
		var songLowercase:String = Paths.formatToSongPath(meta.songName);
		var poop:String = Highscore.formatSong(songLowercase, curDifficulty);
		var cacheKey:String = meta.folder + '_' + poop;

		if (cacheKey != prefetchKey)
		{
			prefetchKey = cacheKey;
			prefetchDelay = PREFETCH_DELAY;
			return;
		}

		if (prefetchDelay <= 0)
			return;

		prefetchDelay -= elapsed;
		if (prefetchDelay > 0)
			return;
		prefetchDelay = 0;

		if (_songDataCache.exists(cacheKey) || _prefetchBusy.exists(cacheKey))
			return;

		// 路径解析必须留在主线程（依赖 Mods.currentModDirectory 等全局状态）
		var path:String = Song.getChartPath(poop, songLowercase);
		if (path == null || !FileSystem.exists(path))
			return; // 打包进 assets 的谱面走原来的同步分支

		// 先在主线程触发 ExtraKeysHandler 的懒初始化，保证后台线程里只做只读访问
		if (backend.ExtraKeysHandler.instance == null)
			return;

		_prefetchBusy.set(cacheKey, true);
		_songPathCache.set(cacheKey, path);

		sys.thread.Thread.create(() ->
		{
			var parsed:SwagSong = null;
			try
			{
				parsed = Song.parseJSON(File.getContent(path), poop);
			}
			catch (e:Dynamic)
			{
				parsed = null;
			}

			_prefetchMutex.acquire();
			_prefetchDone.set(cacheKey, parsed);
			_prefetchMutex.release();
		});
		#end
	}

	var songs:Array<SongMetadata> = [];
	var songsFull:Array<SongMetadata> = []; // 全部曲目（筛选前的完整列表）
	var searchTxt:PsychUIInputText;
	var searchLabel:FlxText;
	var searchContainer:FlxSpriteGroup; // 搜索框容器（默认常驻显示）
	private static final SEARCH_BOX_W:Int = 400;
	private static final SEARCH_Y_SHOWN:Float = 0;
	private static final SEARCH_Y_HIDDEN:Float = -60;

	var selector:FlxText;

	private static var curSelected:Int = 0;

	var lerpSelected:Float = 0;
	var curDifficulty:Int = -1;

	private static var lastDifficultyName:String = Difficulty.getDefault();

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var diffText:FlxText;
	var modText:FlxText; // 当前选中模组名称（显示在最高分数下方、选中难度上方）
	var lerpScore:Int = 0;
	var lerpRating:Float = 0;
	var intendedScore:Int = 0;
	var intendedRating:Float = 0;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var grpIcons:FlxTypedGroup<HealthIcon>;
	private var curPlaying:Bool = false;

	private var iconArray:Array<HealthIcon> = null;
	private var iconLoadStatus:Array<Bool> = []; // 记录每个图标是否已加载

	var bg:FlxSprite;
	var intendedColor:Int;
	private var bgScaleLerp:Float = 0; // Lerp插值进度 (0-1)
	private var bgBeatDuration:Float = 0; // 节拍动画总时长
	private var bgBeatElapsed:Float = 0; // 节拍动画已过去时间

	var missingTextBG:FlxSprite;
	var missingText:FlxText;

	var bottomString:String;
	var bottomText:FlxText;
	var bottomBG:FlxSprite;

	var player:MusicPlayer;

	// BPM变化提示相关
	private var bpmText:FlxText;
	private var bpmTextBG:FlxSprite;
	private var lastBPM:Float = -1;
	private var bpmDisplayTime:Float = 0;

	// 回放缓存相关
	private var lastReplayCheckTime:Float = 0;
	private var cachedReplayText:String = "";
	private var cachedReplayIndex:Map<String, Array<String>> = new Map(); // 缓存回放文件索引：歌曲名 -> 难度列表
	private var lastReplayFolderMTime:Float = 0; // 回放文件夹的最后修改时间，用于检测变化

	override function create()
	{
		// Paths.clearStoredMemory();
		// Paths.clearUnusedMemory();

		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		final accept:String = (controls.mobileC) ? "A" : "ACCEPT";
		final reject:String = (controls.mobileC) ? "B" : "BACK";

		if (WeekData.weeksList.length < 1)
		{
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			MusicBeatState.switchState(new states.ErrorState("NO WEEKS ADDED FOR FREEPLAY\n\nPress " + accept + " to go to the Week Editor Menu.\nPress "
				+ reject + " to return to Main Menu.",
				function() MusicBeatState.switchState(new states.editors.WeekEditorState()),
				function() MusicBeatState.switchState(new states.MainMenuState())));
			return;
		}

		for (i in 0...WeekData.weeksList.length)
		{
			if (weekIsLocked(WeekData.weeksList[i]))
				continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			var leSongs:Array<String> = [];
			var leChars:Array<String> = [];

			for (j in 0...leWeek.songs.length)
			{
				leSongs.push(leWeek.songs[j][0]);
				leChars.push(leWeek.songs[j][1]);
			}

			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];
				if (colors == null || colors.length < 3)
				{
					colors = [146, 113, 253];
				}
				if (song.length > 3 && song[3] != null && Std.isOfType(song[3], String))
				{
					Mods.currentModDirectory = song[3];
				}
				else
				{
					WeekData.setDirectoryFromWeek(leWeek);
				}
				addSong(song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
			}
		}
		Mods.loadTopMod();

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		add(bg);
		bg.screenCenter();
		bg.scale.set(1.0, 1.0); // 确保初始scale为1

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);

		grpIcons = new FlxTypedGroup<HealthIcon>();
		add(grpIcons);

		// 初始化图标数组和加载状态数组
		iconArray = new Array<HealthIcon>();
		iconLoadStatus = new Array<Bool>();

		songs = songsFull;
		reloadSongList();
		WeekData.setDirectoryFromWeek();

		if (curSelected >= songs.length)
			curSelected = 0;
		bg.color = songs[curSelected].color;
		intendedColor = bg.color;
		lerpSelected = curSelected;

		curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(lastDifficultyName)));

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font(Language.get('game_font2')), 32, FlxColor.WHITE, RIGHT);

		diffText = new FlxText(scoreText.x, scoreText.y + scoreText.height, 0, "", 24);
		diffText.font = scoreText.font;

		modText = new FlxText(scoreText.x, 0, 0, '', 16);
		modText.font = Paths.font("unifont-16.0.02.otf"); // 使用 unifont 以兼容多语言模组名与装饰符号
		var modDir:String = backend.Mods.currentModDirectory;
		var modName:String = (modDir != null && modDir.length > 0) ? modDir : 'Friday Night Funkin\'';
		modText.text = '◆ ' + modName + ' ◆';

		var height:Float = scoreText.y + scoreText.height + 2 + modText.height + 2 + diffText.height + 4;
		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, Std.int(height), 0xFF000000);
		scoreBG.alpha = 0.6;

		missingTextBG = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;

		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;

		bottomBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(FlxG.width, 26, 0xFF000000);
		bottomBG.alpha = 0.6;

		final space:String = (controls.mobileC) ? "X" : "SPACE";
		final control:String = (controls.mobileC) ? "C" : "CTRL";
		final reset:String = (controls.mobileC) ? "Y" : "RESET";

		var leText:String = LanguageBasic.getPhrase("freeplay_tip",
			"Press {1} to listen to the Song / Press {2} to open the Gameplay Changers Menu / Press {3} to Reset your Score and Accuracy.",
			[space, control, reset]);
		bottomString = leText;
		var size:Int = 16;
		bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, leText, size);
		bottomText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
		bottomText.scrollFactor.set();

		player = new MusicPlayer(this);

		// 创建BPM变化提示背景（先创建，渲染在底层）
		bpmTextBG = new FlxSprite(0, 0); // 初始位置为0,0
		bpmTextBG.alpha = 0;
		bpmTextBG.scrollFactor.set(); // 固定位置

		// 创建BPM变化提示文本（后创建，渲染在顶层）
		bpmText = new FlxText(0, 20, 0, "", 32);
		bpmText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);
		bpmText.alpha = 0;
		bpmText.scrollFactor.set(); // 固定位置

		// 现在添加所有UI元素到正确的层级（在歌曲和图标之上）
		add(scoreBG);
		add(diffText);
		add(scoreText);
		add(modText);
		add(missingTextBG);
		add(missingText);
		add(bottomBG);
		add(bottomText);
		add(player);
		add(bpmTextBG);
		add(bpmText);

		// 搜索 / 筛选（顶部居中，默认常驻显示）
		searchContainer = new FlxSpriteGroup();
		searchContainer.y = SEARCH_Y_SHOWN;

		// "SONGFILTER" 字样：放在文本框左侧、全大写、使用 unifont
		searchLabel = new FlxText(0, 0, 0, 'SONGFILTER', 16);
		searchLabel.setFormat(Paths.font("unifont-16.0.02.otf"), 24, FlxColor.WHITE);
		// 重新赋值文本以按新字体重算宽度（setFormat 不会自动更新 width）
		searchLabel.text = 'SONGFILTER: ';

		// 根据标签实测宽度自动偏移输入框，兼容不同文本长度
		var labelGap:Int = 8;
		var boxX:Float = searchLabel.width + labelGap;

		searchTxt = new PsychUIInputText(boxX, 0, SEARCH_BOX_W, '', 24, Paths.font("unifont-16.0.02.otf"), true);
		searchTxt.name = 'freeplay_search';
		searchTxt.maxLength = 32;
		// 标签在垂直方向上与输入框居中对齐
		searchLabel.y = (searchTxt.height - searchLabel.height) / 2;
		searchTxt.onChange = function(oldTxt:String, newTxt:String)
		{
			// 去除可能由 TAB 误输入的制表符，避免筛选异常
			if (newTxt.indexOf("\t") >= 0)
			{
				searchTxt.text = newTxt.split("\t").join("");
				return;
			}
			applyFilter(newTxt);
		};

		// 整个容器靠右上角，右边缘无外边距（标签 + 间距 + 输入框）
		searchContainer.x = FlxG.width - (boxX + SEARCH_BOX_W);

		searchContainer.add(searchLabel);
		searchContainer.add(searchTxt);
		add(searchContainer);

		changeSelection();
		updateTexts();

		// 预加载回放文件索引（异步，不阻塞主线程）
		preloadReplayIndex();

		addTouchPad('LEFT_FULL', 'A_B_C_X_Y_Z');

		// 桌面端：进入 Freeplay 时显示鼠标（方便点击搜索框等），手柄模式下隐藏
		#if desktop
		FlxG.mouse.visible = !controls.controllerMode;
		#end

		super.create();
	}

	override function closeSubState()
	{
		changeSelection(0, false);
		persistentUpdate = true;
		lastLerpSelected = -9999; // 重置，确保下次更新时重新计算可见范围
		super.closeSubState();
		removeTouchPad();
		addTouchPad('LEFT_FULL', 'A_B_C_X_Y_Z');
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
	{
		songsFull.push(new SongMetadata(songName, weekNum, songCharacter, color));
	}

	function weekIsLocked(name:String):Bool
	{
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked
			&& leWeek.weekBefore.length > 0
			&& (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	/**
	 * 重建歌曲显示列表（grpSongs / grpIcons / 图标状态数组）。
	 * 在初始创建以及筛选条件变化时调用。
	 */
	private function reloadSongList():Void
	{
		grpSongs.clear();
		grpIcons.clear();
		iconArray = new Array<HealthIcon>();
		iconLoadStatus = new Array<Bool>();

		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(90, 320, songs[i].songName, true);
			songText.targetY = i;
			grpSongs.add(songText);

			songText.scaleX = Math.min(1, 980 / songText.width);
			songText.snapToPosition();

			// 初始化图标占位符，但暂不创建（延迟加载）
			iconArray.push(null);
			iconLoadStatus.push(false);

			// too laggy with a lot of songs, so i had to recode the logic for it
			songText.visible = songText.active = songText.isMenuItem = false;
		}
		_lastVisibles = [];
	}

	/**
	 * 根据搜索框内容筛选曲目。
	 * @param filterStr 搜索关键字（大小写不敏感，支持空格）
	 */
	private function applyFilter(filterStr:String):Void
	{
		// 按空格分词，每个非空词都需出现在曲名中（多词 AND 搜索）。
		// 这样单独输入空格（或首尾空格）不会让列表变空，也自然支持带空格的曲名。
		var f:String = filterStr.toLowerCase().trim();
		var tokens:Array<String> = f.split(" ");

		if (tokens.length == 1 && tokens[0].length == 0)
		{
			songs = songsFull;
		}
		else
		{
			songs = songsFull.filter(function(s:SongMetadata):Bool
			{
				var name:String = s.songName.toLowerCase();
				for (token in tokens)
				{
					if (token.length > 0 && name.indexOf(token) == -1)
						return false;
				}
				return true;
			});
		}

		reloadSongList();

		if (curSelected >= songs.length)
			curSelected = 0;
		lerpSelected = curSelected;

		if (songs.length > 0)
		{
			changeSelection();
		}
		else
		{
			intendedScore = 0;
			intendedRating = 0;
			scoreText.text = '';
			diffText.text = '';
		}
	}

	var instPlaying:Int = -1;

	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;

	var holdTime:Float = 0;

	var stopMusicPlay:Bool = false;
	var lastTypingTick:Int = -99999; // 上次处于搜索输入状态的帧时间

	override function update(elapsed:Float)
	{
		if (WeekData.weeksList.length < 1)
			return;

		// 是否正在搜索框中输入（避免空格/方向键等被 freeplay 逻辑拦截）
		var typingSearch:Bool = (searchTxt != null && PsychUIInputText.focusOn == searchTxt);
		if (typingSearch)
			lastTypingTick = FlxG.game.ticks;

		// 桌面端：未在播放预览音乐时恢复鼠标显示（播放时由 SPACE 分支隐藏）
		#if desktop
		if (!player.playingMusic && !controls.controllerMode && !FlxG.mouse.visible)
			FlxG.mouse.visible = true;
		#end

		// 未在播放预览时恢复搜索框与模组名文本显示（播放预览时由 SPACE 分支隐藏）
		if (!player.playingMusic && !searchContainer.visible)
			searchContainer.visible = true;
		if (!player.playingMusic && !modText.visible)
			modText.visible = true;

		// 后台预解析当前选中曲目的谱面，让按下确认键时直接命中缓存
		updateChartPrefetch(elapsed);

		if (FlxG.sound.music.volume < 0.7)
			FlxG.sound.music.volume += 0.5 * elapsed;

		// 更新Conductor.songPosition以触发beatHit
		if (player.playingMusic && FlxG.sound.music != null)
		{
			Conductor.songPosition = FlxG.sound.music.time + ClientPrefs.data.noteOffset;

			// 检测BPM变化并显示提示 - 使用getBPMFromSeconds获取当前时间点的实际BPM
			// 限制BPM检测频率，避免每帧都检测
			if (Conductor.songPosition % 250 < 16) // 每250ms检测一次
			{
				var currentBPM = Conductor.getBPMFromSeconds(Conductor.songPosition).bpm;
				if (currentBPM != lastBPM)
				{
					bpmText.text = 'BPM: ${Math.round(currentBPM)}';
					bpmText.x = FlxG.width - bpmText.width - 10;
					bpmText.y = (FlxG.height - bpmText.height) / 2; // 垂直居中

					// 重新创建背景图形以确保正确的大小和位置
					bpmTextBG.loadGraphic(FlxGraphic.fromRectangle(Std.int(bpmText.width + 20), Std.int(bpmText.height + 10), 0xFF000000));
					bpmTextBG.x = bpmText.x - 10;
					bpmTextBG.y = bpmText.y - 5;

					bpmDisplayTime = 0;
				}
				lastBPM = currentBPM;
			}
		}

		// 更新BPM提示显示/隐藏
		if (bpmDisplayTime >= 0)
		{
			bpmDisplayTime += elapsed;
			if (bpmDisplayTime < 1.0) // 显示1秒
			{
				bpmText.alpha = 1;
				bpmTextBG.alpha = 0.6;
			}
			else if (bpmDisplayTime < 1.5) // 0.5秒淡出
			{
				var fade = (bpmDisplayTime - 1.0) / 0.5;
				bpmText.alpha = 1 - fade;
				bpmTextBG.alpha = 0.6 * (1 - fade);
			}
			else
			{
				bpmText.alpha = 0;
				bpmTextBG.alpha = 0;
			}
		}

		// 背景缩放Lerp动画（从1.05过渡回1）
		if (bg != null && bg.scale.x > 1.0)
		{
			bgBeatElapsed += elapsed;

			// 计算插值进度 (0-1)
			bgScaleLerp = Math.min(bgBeatElapsed / bgBeatDuration, 1.0);

			// 使用立方缓出函数使过渡更自然
			var easedProgress = 1 - Math.pow(1 - bgScaleLerp, 3);
			var scale = FlxMath.lerp(1.05, 1.0, easedProgress);
			bg.scale.set(scale, scale);
		}

		// 图标缩放Lerp动画（从1.1过渡回1）
		if (iconArray != null && iconArray[curSelected] != null && iconArray[curSelected].scale.x > 1.0)
		{
			iconBeatElapsed += elapsed;

			// 计算插值进度 (0-1)
			iconScaleLerp = Math.min(iconBeatElapsed / iconBeatDuration, 1.0);

			// 使用立方缓出函数使过渡更自然
			var easedProgress = 1 - Math.pow(1 - iconScaleLerp, 3);
			var scale = FlxMath.lerp(1.1, 1.0, easedProgress);
			iconArray[curSelected].scale.set(scale, scale);
		}

		lerpScore = Math.floor(FlxMath.lerp(intendedScore, lerpScore, Math.exp(-elapsed * 24)));
		lerpRating = FlxMath.lerp(intendedRating, lerpRating, Math.exp(-elapsed * 12));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(CoolUtil.floorDecimal(lerpRating * 100, 2)).split('.');
		if (ratingSplit.length < 2) // No decimals, add an empty space
			ratingSplit.push('');

		while (ratingSplit[1].length < 2) // Less than 2 decimals in it, add decimals then
			ratingSplit[1] += '0';

		var shiftMult:Int = 1;
		if ((FlxG.keys.pressed.SHIFT || touchPad.buttonZ.pressed) && !player.playingMusic)
			shiftMult = 3;

		if (!player.playingMusic && !typingSearch && songs.length > 0)
		{
			// scoreText.text = LanguageBasic.getPhrase('personal_best', 'PERSONAL BEST: {1} ({2}%)', [lerpScore, ratingSplit.join('.')]);
			scoreText.text = '${Language.get('score_best_desc')} ${lerpScore} (${ratingSplit.join('.')}%)';
			positionHighscore();

			if (songs.length > 1)
			{
				if (FlxG.keys.justPressed.HOME)
				{
					curSelected = 0;
					changeSelection();
					holdTime = 0;
				}
				else if (FlxG.keys.justPressed.END)
				{
					curSelected = songs.length - 1;
					changeSelection();
					holdTime = 0;
				}
				if (controls.UI_UP_P)
				{
					changeSelection(-shiftMult);
					holdTime = 0;
				}
				if (controls.UI_DOWN_P)
				{
					changeSelection(shiftMult);
					holdTime = 0;
				}

				if (controls.UI_DOWN || controls.UI_UP)
				{
					var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
					holdTime += elapsed;
					var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);

					if (holdTime > 0.5 && checkNewHold - checkLastHold > 0)
						changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
				}

				if (FlxG.mouse.wheel != 0)
				{
					FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
					changeSelection(-shiftMult * FlxG.mouse.wheel, false);
				}
			}

			if (controls.UI_LEFT_P && !typingSearch)
			{
				changeDiff(-1);
				_updateSongLastDifficulty();
			}
			else if (controls.UI_RIGHT_P && !typingSearch)
			{
				changeDiff(1);
				_updateSongLastDifficulty();
			}
		}

		if (controls.BACK)
		{
			var wasTyping:Bool = typingSearch || (FlxG.game.ticks - lastTypingTick) < 250;
			if (wasTyping)
			{
				// 搜索框聚焦时：仅 ESC 取消焦点；BACKSPACE 交给输入框删除字符，二者均不返回主菜单
				if (FlxG.keys.justPressed.ESCAPE && PsychUIInputText.focusOn != null)
					PsychUIInputText.focusOn = null;
			}
			else if (player.playingMusic)
			{
				FlxG.sound.music.stop();
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;
				instPlaying = -1;

				player.playingMusic = false;
				player.switchPlayMusic();

				// 重置Conductor状态
				Conductor.songPosition = 0;
				lastBeatHit = -1;

				// 隐藏BPM提示
				bpmText.alpha = 0;
				bpmTextBG.alpha = 0;
				bpmDisplayTime = -1;
				lastBPM = -1;

				FlxG.sound.playMusic(Paths.music('freakyMenu'), 0);
				FlxTween.tween(FlxG.sound.music, {volume: 1}, 1);
			}
			else
			{
				persistentUpdate = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new MainMenuState());
			}
		}

		if ((FlxG.keys.justPressed.CONTROL || touchPad.buttonC.justPressed) && !player.playingMusic)
		{
			persistentUpdate = false;
			openSubState(new GameplayChangersSubstate());
			removeTouchPad();
		}
		else if ((FlxG.keys.justPressed.SPACE || touchPad.buttonX.justPressed) && !typingSearch && songs.length > 0)
		{
			if (instPlaying != curSelected && !player.playingMusic)
			{
				destroyFreeplayVocals();
				FlxG.sound.music.volume = 0;

				Mods.currentModDirectory = songs[curSelected].folder;
				var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
				var songData:SwagSong = getCachedSongData(songs[curSelected].folder, poop, songs[curSelected].songName.toLowerCase());

				if (songData == null) {
							// 显示错误信息
							missingText.text = 'ERROR: Could not load chart file: $poop';
							missingText.screenCenter(Y);
							missingText.visible = true;
							missingTextBG.visible = true;
							FlxG.sound.play(Paths.sound('cancelMenu'));
							return;
						}

						// 设置Conductor的BPM信息以支持beat检测
						Conductor.bpm = PlayState.SONG.bpm;
						Conductor.mapBPMChanges(PlayState.SONG);

				// 显示初始BPM
				bpmText.text = 'BPM: ${Math.round(Conductor.bpm)}';
				bpmText.x = FlxG.width - bpmText.width - 10;
				bpmText.y = (FlxG.height - bpmText.height) / 2; // 垂直居中

				// 创建背景图形
				bpmTextBG.loadGraphic(FlxGraphic.fromRectangle(Std.int(bpmText.width + 20), Std.int(bpmText.height + 10), 0xFF000000));
				bpmTextBG.x = bpmText.x - 10;
				bpmTextBG.y = bpmText.y - 5;

				bpmDisplayTime = 0;
				lastBeatHit = -1; // 重置beat检测

				if (PlayState.SONG.needsVoices)
				{
					vocals = new FlxSound();
					try
					{
						var playerVocals:String = getVocalFromCharacter(PlayState.SONG.player1);
						// 使用character名称作为vocal postfix，而不是固定的'Player'
						var playerVocalPostfix = (playerVocals != null && playerVocals.length > 0) ? playerVocals : PlayState.SONG.player1;
						var loadedVocals = Paths.voices(PlayState.SONG.song, playerVocalPostfix, PlayState.SONG.specialVocal);
						
						// 如果指定的vocal不存在，尝试使用默认值
						if (loadedVocals == null) {
							loadedVocals = Paths.voices(PlayState.SONG.song, 'Player', PlayState.SONG.specialVocal);
						}
						
						// 如果仍然不存在，使用无postfix的版本
						if (loadedVocals == null)
							loadedVocals = Paths.voices(PlayState.SONG.song, null, PlayState.SONG.specialVocal);

						if (loadedVocals != null && loadedVocals.length > 0)
						{
							vocals.loadEmbedded(loadedVocals);
							FlxG.sound.list.add(vocals);
							vocals.persist = vocals.looped = true;
							vocals.volume = 0.8;
							vocals.play();
							vocals.pause();
						}
						else
							vocals = FlxDestroyUtil.destroy(vocals);
					}
					catch (e:Dynamic)
					{
						vocals = FlxDestroyUtil.destroy(vocals);
					}

					opponentVocals = new FlxSound();
						try
						{
							// trace('please work...');
							var oppVocals:String = getVocalFromCharacter(PlayState.SONG.player2);
							// 使用character名称作为vocal postfix，而不是固定的'Opponent'
							var oppVocalPostfix = (oppVocals != null && oppVocals.length > 0) ? oppVocals : PlayState.SONG.player2;
							var loadedVocals = Paths.voices(PlayState.SONG.song, oppVocalPostfix, PlayState.SONG.specialVocal);
							
							// 如果指定的vocal不存在，尝试使用默认值
							if (loadedVocals == null) {
								loadedVocals = Paths.voices(PlayState.SONG.song, 'Opponent', PlayState.SONG.specialVocal);
							}

							if (loadedVocals != null && loadedVocals.length > 0)
							{
								opponentVocals.loadEmbedded(loadedVocals);
								FlxG.sound.list.add(opponentVocals);
								opponentVocals.persist = opponentVocals.looped = true;
								opponentVocals.volume = 0.8;
								opponentVocals.play();
								opponentVocals.pause();
								// trace('yaaay!!');
							}
							else
								opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
						}
						catch (e:Dynamic)
						{
							// trace('FUUUCK');
							opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
						}
				}

				FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song, PlayState.SONG.specialInst), 0.8);
				FlxG.sound.music.pause();
				instPlaying = curSelected;

			player.playingMusic = true;
			player.curTime = 0;
			player.switchPlayMusic();
			player.pauseOrResume(true);

			// 桌面端：空格播放预览时隐藏鼠标
			#if desktop
			FlxG.mouse.visible = false;
			#end

			// 播放预览时一并隐藏搜索框（标签 + 输入框）与模组名文本
			searchContainer.visible = false;
			modText.visible = false;

				// 重置BPM检测，并显示初始BPM
				lastBPM = -1;
				bpmDisplayTime = -1;

				// 设置音乐循环回调，循环时重置beat检测
				FlxG.sound.music.onComplete = function()
				{
					lastBeatHit = -1;
				};
			}
			else if (instPlaying == curSelected && player.playingMusic)
			{
				player.pauseOrResume(!player.playing);
			}
		}
		else if (controls.ACCEPT && !player.playingMusic && !typingSearch && songs.length > 0)
		{
			persistentUpdate = false;
			
			// 显式设置当前mod目录，确保谱面文件路径正确
			Mods.currentModDirectory = songs[curSelected].folder;
			
			var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
			var poop:String = Highscore.formatSong(songLowercase, curDifficulty);

			try
			{
				var songData:SwagSong = getCachedSongData(songs[curSelected].folder, poop, songLowercase);

				if (songData == null) {
								// 显示错误信息
								missingText.text = 'ERROR: Could not load chart file: $poop';
								missingText.screenCenter(Y);
								missingText.visible = true;
								missingTextBG.visible = true;
								FlxG.sound.play(Paths.sound('cancelMenu'));

								updateTexts(elapsed);
								super.update(elapsed);
								return;
							}
							
							PlayState.isStoryMode = false;
							PlayState.storyDifficulty = curDifficulty;

							trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
						}
						catch (e:haxe.Exception)
						{
							// Error handling

							var errorStr:String = e.message;
							if (errorStr.contains('There is no TEXT asset with an ID of'))
								errorStr = 'Missing file: ' + errorStr.substring(errorStr.indexOf(songLowercase), errorStr.length - 1); // Missing chart
							else
								errorStr += '\n\n' + e.stack;

							missingText.text = 'ERROR WHILE LOADING CHART:\n$errorStr';
							missingText.screenCenter(Y);
							missingText.visible = true;
							missingTextBG.visible = true;
							FlxG.sound.play(Paths.sound('cancelMenu'));

							updateTexts(elapsed);
							super.update(elapsed);
							return;
						}
			@:privateAccess
			if (PlayState._lastLoadedModDirectory != Mods.currentModDirectory)
			{
				Paths.freeGraphicsFromMemory();
			}
			// 桌面端：开始游玩时隐藏鼠标
			#if desktop
			FlxG.mouse.visible = false;
			#end
			LoadingState.prepareToSong();
			LoadingState.loadAndSwitchState(new PlayState());
			if (!ClientPrefs.data.loadingScreen) FlxG.sound.music.stop();
			stopMusicPlay = true;

			destroyFreeplayVocals();
			#if (MODS_ALLOWED && DISCORD_ALLOWED)
			DiscordClient.loadModRPC();
			#end
		}
		else if ((controls.RESET || touchPad.buttonY.justPressed) && !player.playingMusic && !typingSearch && songs.length > 0)
		{
			persistentUpdate = false;
			openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
			removeTouchPad();
			FlxG.sound.play(Paths.sound('scrollMenu'));
		}

		// Replay loading entry point: F7 loads latest saved replay (if exists)
		#if FEATURE_FILESYSTEM
		// 只在按下F7时扫描回放文件，而不是每帧都扫描
		if (FlxG.keys.justPressed.F7 && !player.playingMusic && songs.length > 0)
		{
			var moddirLoad:String = (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0) ? Mods.currentModDirectory : 'global';
			var replayFolderLoad:String = Paths.mods(moddirLoad + '/replay');
			if (FileSystem.exists(replayFolderLoad))
			{
				var filesLoad:Array<String> = FileSystem.readDirectory(replayFolderLoad);
				if (filesLoad != null && filesLoad.length > 0)
				{
					// Get currently selected song name (formatted)
					var currentSongName:String = Paths.formatToSongPath(songs[curSelected].songName);

					// Get currently selected difficulty name
					var currentDifficultyName:String = Difficulty.getString(curDifficulty, false);

					// Find latest replay file matching current song and difficulty
					var latest:String = null;
					var latestM:Float = -1;
					var savedSongName:String = null;
					for (f in filesLoad)
					{
						if (!f.endsWith('.replay.json'))
							continue;

						var p = replayFolderLoad + '/' + f;
						try
						{
							var content:String = File.getContent(p);
							var obj:Dynamic = Json.parse(content);
							var meta:Dynamic = Reflect.field(obj, 'meta');
							if (meta != null && Reflect.hasField(meta, 'song'))
							{
								var replaySongName:String = Reflect.field(meta, 'song');
								var chartPath:Dynamic = (meta != null && Reflect.hasField(meta, 'chartPath')) ? Reflect.field(meta, 'chartPath') : null;
								var replayDifficulty:String = getDifficultyFromChartPath(chartPath, meta);

								// Check if replay matches current song and difficulty
								if (Paths.formatToSongPath(replaySongName) == currentSongName && replayDifficulty == currentDifficultyName)
								{
									var s = FileSystem.stat(p);
									var m:Float = 0;
									if (s != null && Reflect.hasField(s, 'mtime'))
									{
										var mt = Reflect.field(s, 'mtime');
										if (Std.isOfType(mt, Date))
											m = mt.getTime();
										else
											m = Std.parseFloat(Std.string(mt));
									}
									if (m > latestM)
									{
										latestM = m;
										latest = p;
										savedSongName = replaySongName;
									}
								}
							}
						}
						catch (e:Dynamic)
						{
							trace('Failed to read replay file ${f}: ' + e);
						}
					}

					if (latest != null)
					{
						// Load and play the replay
						try
						{
							var content:String = File.getContent(latest);
							var obj:Dynamic = Json.parse(content);
							var replayArr = Reflect.field(obj, 'replay');
							var meta:Dynamic = Reflect.field(obj, 'meta');
							var chartPath:Dynamic = (meta != null && Reflect.hasField(meta, 'chartPath')) ? Reflect.field(meta, 'chartPath') : null;
							var savedM:Dynamic = (meta != null && Reflect.hasField(meta, 'chartMTime')) ? Reflect.field(meta, 'chartMTime') : null;
							var warn:Bool = false;
							if (chartPath != null && FileSystem.exists(chartPath))
							{
								var s2 = FileSystem.stat(chartPath);
								var curM = (s2 != null && Reflect.hasField(s2, 'mtime')) ? Reflect.field(s2, 'mtime') : null;
								if (savedM != null && curM != null && Std.string(savedM) != Std.string(curM))
									warn = true;
							}
							else
								warn = true;
							if (warn)
							{
								missingText.text = 'Warning: chart file changed since save. Playback may desync.';
								missingText.screenCenter(Y);
								missingText.visible = true;
								missingTextBG.visible = true;
							}
							// Set pending replay data and load song
						PlayState.pendingReplayData = replayArr;
						PlayState.shouldStartReplay = true;
						// 提取并保存判定设置
						if (meta != null && Reflect.hasField(meta, 'judgmentSettings'))
						{
							PlayState.replayJudgmentSettings = Reflect.field(meta, 'judgmentSettings');
						}
						else
						{
							PlayState.replayJudgmentSettings = null;
						}
						// 提取并保存游戏设置
						if (meta != null && Reflect.hasField(meta, 'gameplaySettings'))
						{
							PlayState.replayGameplaySettings = Reflect.field(meta, 'gameplaySettings');
						}
						else
						{
							PlayState.replayGameplaySettings = null;
						}

						// 显式设置当前mod目录，确保谱面文件路径正确
						Mods.currentModDirectory = songs[curSelected].folder;

						var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
						var poop:String = Highscore.formatSong(songLowercase, curDifficulty);
						var songData:SwagSong = getCachedSongData(songs[curSelected].folder, poop, songLowercase);

						if (songData == null) {
							// 显示错误信息
							missingText.text = 'ERROR: Could not load chart file for replay: $poop';
							missingText.screenCenter(Y);
							missingText.visible = true;
							missingTextBG.visible = true;
							FlxG.sound.play(Paths.sound('cancelMenu'));
							return;
						}

						PlayState.isStoryMode = false;
						PlayState.storyDifficulty = curDifficulty;
						// 桌面端：开始游玩（回放）时隐藏鼠标
						#if desktop
						FlxG.mouse.visible = false;
						#end
						LoadingState.prepareToSong();
						LoadingState.loadAndSwitchState(new PlayState());
						}
						catch (e:Dynamic)
						{
							trace('Failed to load replay: ' + e);
						}
					}
					else
					{
						// Show prompt: current song and difficulty have no replay
						missingText.text = 'No replay found for "${songs[curSelected].songName}" (${currentDifficultyName}).';
						missingText.screenCenter(Y);
						missingText.visible = true;
						missingTextBG.visible = true;
					}
				}
			}
		}
		#end

		updateModText();
		updateTexts(elapsed);
		super.update(elapsed);
	}

	function getVocalFromCharacter(char:String)
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', TEXT);
			#if MODS_ALLOWED
			var character:Dynamic = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end
			return character.vocals_file;
		}
		catch (e:Dynamic)
		{
		}
		return null;
	}

	public static function destroyFreeplayVocals()
	{
		if (vocals != null)
			vocals.stop();
		vocals = FlxDestroyUtil.destroy(vocals);

		if (opponentVocals != null)
			opponentVocals.stop();
		opponentVocals = FlxDestroyUtil.destroy(opponentVocals);
	}

	function changeDiff(change:Int = 0)
	{
		if (player.playingMusic)
			return;
		if (songs.length == 0)
			return;

		curDifficulty = FlxMath.wrap(curDifficulty + change, 0, Difficulty.list.length - 1);
		#if !switch
		intendedScore = Highscore.getScore(songs[curSelected].songName, curDifficulty);
		intendedRating = Highscore.getRating(songs[curSelected].songName, curDifficulty);
		#end

		lastDifficultyName = Difficulty.getString(curDifficulty, false);
		var displayDiff:String = Difficulty.getString(curDifficulty);
		if (Difficulty.list.length > 1)
			diffText.text = '< ' + displayDiff.toUpperCase() + ' >';
		else
			diffText.text = displayDiff.toUpperCase();

		positionHighscore();
		missingText.visible = false;
		missingTextBG.visible = false;
		
		// 更新底部回放文本（因为难度可能变化，回放的可用性也会变化）
		updateReplayBottomText(true); // 强制更新，确保切换难度时立即刷新
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		if (player.playingMusic)
			return;
		if (songs.length == 0)
			return;

		curSelected = FlxMath.wrap(curSelected + change, 0, songs.length - 1);
		_updateSongLastDifficulty();
		if (playSound)
			FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		var newColor:Int = songs[curSelected].color;
		if (newColor != intendedColor)
		{
			intendedColor = newColor;
			FlxTween.cancelTweensOf(bg);
			FlxTween.color(bg, 1, bg.color, intendedColor);
		}

		// 只在切换歌曲时更新可见对象，而不是每帧更新
		updateVisibleItems();

		Mods.currentModDirectory = songs[curSelected].folder;
		PlayState.storyWeek = songs[curSelected].week;
		Difficulty.loadFromWeek();

		var savedDiff:String = songs[curSelected].lastDifficulty;
		var lastDiff:Int = Difficulty.list.indexOf(lastDifficultyName);
		if (savedDiff != null && !Difficulty.list.contains(savedDiff) && Difficulty.list.contains(savedDiff))
			curDifficulty = Math.round(Math.max(0, Difficulty.list.indexOf(savedDiff)));
		else if (lastDiff > -1)
			curDifficulty = lastDiff;
		else if (Difficulty.list.contains(Difficulty.getDefault()))
			curDifficulty = Math.round(Math.max(0, Difficulty.defaultList.indexOf(Difficulty.getDefault())));
		else
			curDifficulty = 0;

		changeDiff();
		_updateSongLastDifficulty();
		updateReplayBottomText(true); // 强制更新，确保切换时立即刷新回放文本
		lastLerpSelected = -9999; // 重置，确保切换歌曲时立即更新可见范围
	}

	inline private function _updateSongLastDifficulty()
		songs[curSelected].lastDifficulty = Difficulty.getString(curDifficulty, false);

	/**
	 * Get difficulty name from chart file path or meta data
	 * @param chartPath Chart file path, e.g. ".../song-hard.json"
	 * @param meta Replay meta data containing difficulty information
	 * @return Difficulty name (e.g. Easy/Normal/Hard) or default difficulty
	 */
	private function getDifficultyFromChartPath(chartPath:String, ?meta:Dynamic):Null<String>
	{
		if (meta != null && Reflect.hasField(meta, 'difficulty'))
			return Reflect.field(meta, 'difficulty');
		if (chartPath == null)
			return Difficulty.getDefault();
		// Find the last path separator
		var lastSep = chartPath.lastIndexOf('/');
		if (lastSep == -1)
			lastSep = chartPath.lastIndexOf('\\');
		var fileName:String = (lastSep >= 0) ? chartPath.substr(lastSep + 1) : chartPath;
		// Remove .json extension
		if (fileName.endsWith('.json'))
			fileName = fileName.substr(0, fileName.length - 5);
		// Find the last dash separator like "song-hard.json"
		var lastDash = fileName.lastIndexOf('-');
		if (lastDash == -1)
		{
			// No dash found, file might be "song.json" without difficulty
			return Difficulty.getDefault();
		}
		var potentialDiff:String = fileName.substr(lastDash + 1);
		// Check if the extracted part matches any difficulty name
		for (diff in Difficulty.list)
		{
			if (Paths.formatToSongPath(diff) == Paths.formatToSongPath(potentialDiff))
				return diff;
		}
		// No matching difficulty found, return default
		return Difficulty.getDefault();
	}

	#if FEATURE_FILESYSTEM
	/**
	 * 预加载回放文件索引到内存缓存中
	 * 只扫描一次文件列表，避免重复的文件I/O操作
	 */
	private function preloadReplayIndex():Void
	{
		// 清空之前的缓存
		cachedReplayIndex = new Map();
		
		var moddirCheck:String = (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0) ? Mods.currentModDirectory : 'global';
		var replayFolderCheck:String = Paths.mods(moddirCheck + '/replay');
		
		if (!FileSystem.exists(replayFolderCheck))
		{
			// 回放文件夹不存在，直接返回
			return;
		}
		
		var files:Array<String> = FileSystem.readDirectory(replayFolderCheck);
		if (files == null || files.length == 0)
		{
			// 没有回放文件
			return;
		}
		
		// 遍历所有回放文件，建立索引
		for (f in files)
		{
			if (!f.endsWith('.replay.json'))
				continue;
			
			var p = replayFolderCheck + '/' + f;
			try
			{
				var content:String = File.getContent(p);
				var obj:Dynamic = Json.parse(content);
				var meta:Dynamic = Reflect.field(obj, 'meta');
				
				if (meta != null && Reflect.hasField(meta, 'song'))
				{
					var replaySongName:String = Reflect.field(meta, 'song');
					var formattedSongName:String = Paths.formatToSongPath(replaySongName);
					var chartPath:Dynamic = (meta != null && Reflect.hasField(meta, 'chartPath')) ? Reflect.field(meta, 'chartPath') : null;
					var replayDifficulty:String = getDifficultyFromChartPath(chartPath, meta);
					
					// 将难度添加到对应歌曲的列表中
					if (!cachedReplayIndex.exists(formattedSongName))
					{
						cachedReplayIndex.set(formattedSongName, []);
					}
					
					var difficultyList:Array<String> = cachedReplayIndex.get(formattedSongName);
					if (difficultyList.indexOf(replayDifficulty) == -1)
					{
						difficultyList.push(replayDifficulty);
					}
				}
			}
			catch (e:Dynamic)
			{
				trace('Failed to preload replay file ${f}: ' + e);
			}
		}
	}
	#end

	private function updateReplayBottomText(?forceUpdate:Bool = false):Void
	{
		if (songs.length == 0)
			return;
		#if FEATURE_FILESYSTEM
		// 限制回放文本更新频率，避免每帧都更新（UI更新开销）
		// 但切换曲目/难度时强制更新（forceUpdate = true）
		var currentTime:Float = FlxG.game.ticks / 1000;
		if (!forceUpdate && currentTime - lastReplayCheckTime < 0.5) // 每0.5秒更新一次文本
		{
			// 使用缓存的文本
			if (cachedReplayText.length > 0)
			{
				bottomText.text = cachedReplayText;
				bottomText.y = FlxG.height - bottomText.height - 2;
				bottomBG.y = bottomText.y - 4;
				bottomBG.makeGraphic(FlxG.width, Std.int(bottomText.height) + 8, 0x99000000);
			}
			return;
		}
		
		lastReplayCheckTime = currentTime;
		
		// 检测回放文件夹是否有变化（新增、修改或删除回放文件）
		var moddirCheck:String = (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0) ? Mods.currentModDirectory : 'global';
		var replayFolderCheck:String = Paths.mods(moddirCheck + '/replay');
		if (FileSystem.exists(replayFolderCheck))
		{
			var folderStat = FileSystem.stat(replayFolderCheck);
			var currentMTime:Float = (folderStat != null && Reflect.hasField(folderStat, 'mtime')) ? Reflect.field(folderStat, 'mtime').getTime() : 0;
			
			// 如果文件夹修改时间变化，重新加载索引
			if (currentMTime > lastReplayFolderMTime + 1000) // 加1秒缓冲，避免频繁重载
			{
				lastReplayFolderMTime = currentMTime;
				preloadReplayIndex(); // 重新加载索引
			}
		}
		
		// 使用预加载的索引，不再扫描文件系统
		var currentSongName:String = Paths.formatToSongPath(songs[curSelected].songName);
		var currentDifficultyName:String = Difficulty.getString(curDifficulty, false);
		
		var difficultyList:Array<String> = cachedReplayIndex.exists(currentSongName) ? cachedReplayIndex.get(currentSongName) : null;
		var songReplayCount:Int = (difficultyList != null) ? difficultyList.length : 0;
		var matchedReplayCount:Int = (difficultyList != null && difficultyList.indexOf(currentDifficultyName) != -1) ? 1 : 0;
		
		// Generate hint text based on index data
		if (songReplayCount > 0)
		{
			if (matchedReplayCount > 0)
			{
				// Current difficulty has matching replays
				cachedReplayText = bottomString + '\nThis song has ${songReplayCount} replay(s) - Press F7 to watch';
			}
			else
			{
				// Song has replays but current difficulty doesn't
				cachedReplayText = bottomString + '\nThis song has ${songReplayCount} replay(s) (but no replay for ${currentDifficultyName} difficulty)';
			}
		}
		else
		{
			// Current song has no replay files
			cachedReplayText = bottomString;
		}
		
		bottomText.text = cachedReplayText;
		
		// Adjust position based on text height to prevent overflow
		bottomText.y = FlxG.height - bottomText.height - 2;
		bottomBG.y = bottomText.y - 4;
		bottomBG.makeGraphic(FlxG.width, Std.int(bottomText.height) + 8, 0x99000000);
		#end
	}

	

	private function positionHighscore()
	{
		// 高分面板放置在右上角筛选器下方；
		// searchTxt 可能在 MusicPlayer 初始化时尚未创建，此时退化为顶部定位
		var topY:Float = (searchTxt != null) ? (SEARCH_Y_SHOWN + searchTxt.height + 6) : 10;
		scoreText.y = topY;
		modText.y = scoreText.y + scoreText.height + 2;
		diffText.y = modText.y + modText.height + 2;

		scoreText.x = FlxG.width - scoreText.width - 6;
		scoreBG.scale.x = FlxG.width - scoreText.x + 6;
		scoreBG.x = FlxG.width - (scoreBG.scale.x / 2);
		scoreBG.y = scoreText.y - 6;
		diffText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		diffText.x -= diffText.width / 2;
		modText.x = Std.int(scoreBG.x + (scoreBG.width / 2));
		modText.x -= modText.width / 2;
	}

	private function updateModText():Void
	{
		var modDir:String = backend.Mods.currentModDirectory;
		var newName:String = (modDir != null && modDir.length > 0) ? modDir : 'Friday Night Funkin\'';
		var display:String = '◆ ' + newName + ' ◆';
		if (modText.text != display)
		{
			modText.text = display;
			// 文本变化导致宽度变化，重新按背景框居中
			modText.x = Std.int(scoreBG.x + (scoreBG.width / 2)) - Std.int(modText.width / 2);
		}
	}

	var _drawDistance:Int = 4;
	var _lastVisibles:Array<Int> = [];
	private var lastLerpSelected:Float = -9999; // 用于检测lerpSelected是否变化

	public function updateTexts(elapsed:Float = 0.0)
	{
		// 每帧更新lerp位置
		lerpSelected = FlxMath.lerp(curSelected, lerpSelected, Math.exp(-elapsed * 9.6));
		
		// 检测lerpSelected是否变化足够大，需要重新计算可见范围
		var lerpChanged:Bool = Math.abs(lerpSelected - lastLerpSelected) > 0.5;
		
		if (lerpChanged)
		{
			updateVisibleItems();
			lastLerpSelected = lerpSelected;
		}
		else
		{
			// 只更新已可见的对象位置，不遍历所有对象
			for (i in _lastVisibles)
			{
				var item:Alphabet = grpSongs.members[i];
				item.x = ((item.targetY - lerpSelected) * item.distancePerItem.x) + item.startPosition.x;
				item.y = ((item.targetY - lerpSelected) * 1.3 * item.distancePerItem.y) + item.startPosition.y;
			}
		}
	}

	private function updateVisibleItems():Void
	{
		// 隐藏之前的可见对象
		for (i in _lastVisibles)
		{
			grpSongs.members[i].visible = grpSongs.members[i].active = false;
			if (iconArray[i] != null)
			{
				iconArray[i].visible = iconArray[i].active = false;
			}
		}
		_lastVisibles = [];

		// 计算当前可见范围（基于lerpSelected而不是curSelected，使过渡更平滑）
		var min:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected - _drawDistance)));
		var max:Int = Math.round(Math.max(0, Math.min(songs.length, lerpSelected + _drawDistance)));
		
		// 只显示可见范围内的对象
		for (i in min...max)
		{
			var item:Alphabet = grpSongs.members[i];
			item.visible = item.active = true;
			item.x = ((item.targetY - lerpSelected) * item.distancePerItem.x) + item.startPosition.x;
			item.y = ((item.targetY - lerpSelected) * 1.3 * item.distancePerItem.y) + item.startPosition.y;
			item.alpha = (i == curSelected) ? 1.0 : 0.6; // 设置选中项的透明度（选中不透明，未选中半透明）

			// 延迟加载图标：只在需要显示时才创建
			if (!iconLoadStatus[i])
			{
				Mods.currentModDirectory = songs[i].folder;
				iconArray[i] = new HealthIcon(songs[i].songCharacter);
				iconArray[i].sprTracker = item;
				iconArray[i].visible = false;
				iconArray[i].active = false;
				grpIcons.add(iconArray[i]);
				iconLoadStatus[i] = true;
			}
			
			var icon:HealthIcon = iconArray[i];
			if (icon != null)
			{
				icon.visible = icon.active = true;
				icon.alpha = (i == curSelected) ? 1.0 : 0.6; // 设置选中项的透明度
			}
			
			_lastVisibles.push(i);
		}
	}

	private var lastSectionHit:Int = -1;

	override function stepHit():Void
	{
		super.stepHit();

		// 每section（章节）触发背景缩放动画（不再是每4步）
		if (lastSectionHit != curSection && player.playingMusic)
		{
			lastSectionHit = curSection;
			sectionHit();
		}
	}

	private var lastBeatHit:Int = -1;
	private var iconScaleLerp:Float = 0; // 图标缩放Lerp进度 (0-1)
	private var iconBeatElapsed:Float = 0; // 图标节拍动画已过去时间
	private var iconBeatDuration:Float = 0; // 图标节拍动画总时长

	override function beatHit():Void
	{
		// trace('beatHit called, curBeat: ' + curBeat + ', lastBeatHit: ' + lastBeatHit + ', playingMusic: ' + player.playingMusic);
		if (lastBeatHit >= curBeat || !player.playingMusic || !FlxG.sound.music.playing)
		{
			// trace('beatHit blocked: lastBeatHit >= curBeat = ' + (lastBeatHit >= curBeat) + ', !playingMusic = ' + (!player.playingMusic));
			return;
		}

		lastBeatHit = curBeat;

		// 选中图标立刻缩放到1.1，然后开始lerp回1
		if (iconArray != null && iconArray[curSelected] != null)
		{
			var icon:HealthIcon = iconArray[curSelected];
			icon.scale.set(1.1, 1.1);
			iconBeatElapsed = 0;
			iconBeatDuration = Conductor.crochet / 1000;
		}
	}

	override function sectionHit():Void
	{
		// 背景每section缩放一次（每section触发一次）
		// 不再调用super.sectionHit()，避免父类中的额外缩放
		// 只有当缩放接近完成时才重新触发，避免在lerp动画中重复设置
		if (bg != null && player.playingMusic && FlxG.sound.music.playing && bg.scale.x <= 1.01)
		{
			bg.scale.set(1.05, 1.05);
			bgBeatElapsed = 0;
			bgBeatDuration = Conductor.crochet / 1000;
		}
	}

	override function destroy():Void
	{
		// 清理背景缩放状态
		bgScaleLerp = 0;
		bgBeatElapsed = 0;
		bgBeatDuration = 0;

		// 重置Freeplay播放标志
		isFreeplayPlayingMusic = false;

		// 清理谱面缓存，释放内存
		_songDataCache.clear();
		_songPathCache.clear();
		#if (sys && FEATURE_FILESYSTEM)
		_prefetchMutex.acquire();
		_prefetchDone.clear();
		_prefetchMutex.release();
		_prefetchBusy.clear();
		#end

		super.destroy();

		FlxG.autoPause = ClientPrefs.data.autoPause;
		if (!FlxG.sound.music.playing && !stopMusicPlay)
			FlxG.sound.playMusic(Paths.music('freakyMenu'));

		// 清理BPM提示
		bpmText = null;
		bpmTextBG = null;
	}
}

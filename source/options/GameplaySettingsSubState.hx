package options;

class GameplaySettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = LanguageBasic.getPhrase('gameplay_menu', 'Gameplay Settings');
		rpcTitle = 'Gameplay Settings Menu'; //for Discord Rich Presence

		//I'd suggest using "Downscroll" as an example for making your own option since it is the simplest here
		var option:Option = new Option(
			"Downscroll",
			Language.get("downscroll_desc"),
			'downScroll',
			BOOL);
		addOption(option);

		var option:Option = new Option(
			"Middlescroll",
			Language.get("middlescroll_desc"),
			'middleScroll',
			BOOL);
		addOption(option);

		var option:Option = new Option(
			"Opponent Notes",
			Language.get("opponentnotes_desc"),
			'opponentStrums',
			BOOL);
		addOption(option);

		var option:Option = new Option(
			"Ghost Tapping",
			Language.get("ghosttapping_desc"),
			'ghostTapping',
			BOOL);
		addOption(option);

		var option:Option = new Option(
			"Input System",
			"选择输入判定系统模式\nDefault = 传统模式（按时间升序，最近的优先）\nRhythm = Rhythm模式（只允许击中离判定线最近的音符，其余触发Miss）",
			'inputSystem',
			STRING,
			['default', 'rhythm']);
		addOption(option);

		var option:Option = new Option(
			"Auto Pause",
			Language.get("autopause_desc"),
			'autoPause',
			BOOL);
		addOption(option);
		option.onChange = onChangeAutoPause;

		var option:Option = new Option(
			"Pop Up Score",
			Language.get("popupscore_desc"),
			'popUpRating',
			BOOL);
		addOption(option);

		var option:Option = new Option(
			"Disable Reset Button",
			Language.get("disablereset_desc"),
			'noReset',
			BOOL);
		addOption(option);

		var option:Option = new Option(
			"Force Hold Animations",
			Language.get("force_hold_animations_desc"),
			'forceHoldAnimations',
			BOOL);
		addOption(option);

		#if mobile
		var option:Option = new Option(
			"Game Over Vibration",
			Language.get("gameovervibration_desc"),
			'gameOverVibration',
			BOOL);
		addOption(option);
		option.onChange = onChangeVibration;

		var mobileCompOption:Option = new Option(
			"Mobile Judgment Compensation",
			Language.get("mobilejudgmentcomp_desc", ["自动为触屏输入叠加判定偏移以补偿触屏延迟"]),
			'mobileJudgmentCompensation',
			BOOL);
		addOption(mobileCompOption);

		var mobileOffsetOption:Option = new Option(
			"Mobile Judgment Offset",
			Language.get("mobilejudgmentoffset_desc", ["移动端判定补偿量（毫秒）"]),
			'mobileJudgmentOffset',
			FLOAT);
		mobileOffsetOption.displayFormat = '%vms';
		mobileOffsetOption.scrollSpeed = 5;
		mobileOffsetOption.minValue = 0.0;
		mobileOffsetOption.maxValue = 30.0;
		mobileOffsetOption.changeValue = 1.0;
		addOption(mobileOffsetOption);
		#end

		var option:Option = new Option(
			"Sustains as One Note",
			Language.get("sustainsasone_desc"),
			'guitarHeroSustains',
			BOOL);
		addOption(option);

		var option:Option = new Option(
			"Hitsound Volume",
			Language.get("hitsoundvolume_desc"),
			'hitsoundVolume',
			PERCENT);
		addOption(option);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		option.onChange = onChangeHitsoundVolume;

		var option:Option = new Option(
			"Hitsound",
			Language.get("hitsound_desc"),
			'hitsound',
			STRING,
			CoolUtil.coolTextFile(Paths.txt('hitsoundList')));
		addOption(option);
		option.onChange = onChangeHitsound;

		var option:Option = new Option(
			"Rating Offset",
			Language.get("ratingoffset_desc"),
			'ratingOffset',
			INT);
		option.displayFormat = '%vms';
		option.scrollSpeed = 20;
		option.minValue = -30;
		option.maxValue = 30;
		addOption(option);

		var option:Option = new Option(
			"Safe Frames",
			Language.get("safeframes_desc"),
			'safeFrames',
			FLOAT);
		option.scrollSpeed = 5;
		option.minValue = 2;
		option.maxValue = 15;
		option.changeValue = 0.1;
		addOption(option);

		var hitWindowPresetOption:Option = new Option(
			"Hit Window Preset",
			Language.get("hitwindowpreset_desc"),
			'hitWindowPreset',
			STRING,
			['Leather', 'Psych / Kade', 'Funkin\'', 'Custom']);
		hitWindowPresetOption.onChange = onChangeHitWindowPreset;
		addOption(hitWindowPresetOption);

		var perfectWindowOption:Option = new Option(
			"Perfect!! Hit Window",
			Language.get("perfectwindow_desc"),
			'perfectWindow',
			FLOAT);
		perfectWindowOption.displayFormat = '%vms';
		perfectWindowOption.scrollSpeed = 15;
		perfectWindowOption.minValue = 5;
		perfectWindowOption.maxValue = 45.0;
		perfectWindowOption.changeValue = 0.1;
		perfectWindowOption.onChange = function() { adjustHitWindow('perfectWindow', ClientPrefs.data.perfectWindow); markPresetCustom(); };
		addOption(perfectWindowOption);

		var sickWindowOption:Option = new Option(
			"Sick! Hit Window",
			Language.get("sickwindow_desc"),
			'sickWindow',
			FLOAT);
		sickWindowOption.displayFormat = '%vms';
		sickWindowOption.scrollSpeed = 15;
		sickWindowOption.minValue = 15.0;
		sickWindowOption.maxValue = 75.0;
		sickWindowOption.changeValue = 0.1;
		sickWindowOption.onChange = function() { adjustHitWindow('sickWindow', ClientPrefs.data.sickWindow); markPresetCustom(); };
		addOption(sickWindowOption);

		var goodWindowOption:Option = new Option(
			"Good Hit Window",
			Language.get("goodwindow_desc"),
			'goodWindow',
			FLOAT);
		goodWindowOption.displayFormat = '%vms';
		goodWindowOption.scrollSpeed = 30;
		goodWindowOption.minValue = 15.0;
		goodWindowOption.maxValue = 130.0;
		goodWindowOption.changeValue = 0.1;
		goodWindowOption.onChange = function() { adjustHitWindow('goodWindow', ClientPrefs.data.goodWindow); markPresetCustom(); };
		addOption(goodWindowOption);

		var badWindowOption:Option = new Option(
			"Bad Hit Window",
			Language.get("badwindow_desc"),
			'badWindow',
			FLOAT);
		badWindowOption.displayFormat = '%vms';
		badWindowOption.scrollSpeed = 60;
		badWindowOption.minValue = 15.0;
		badWindowOption.maxValue = 200.0;
		badWindowOption.changeValue = 0.1;
		badWindowOption.onChange = function() { adjustHitWindow('badWindow', ClientPrefs.data.badWindow); markPresetCustom(); };
		addOption(badWindowOption);

		var shitWindowOption:Option = new Option(
			"Shit Hit Window",
			Language.get("shitwindow_desc", ["判定兜底窗口，同时作为 safeZoneOffset 的固定值上限"]),
			'shitWindow',
			FLOAT);
		shitWindowOption.displayFormat = '%vms';
		shitWindowOption.scrollSpeed = 60;
		shitWindowOption.minValue = 135.0;
		shitWindowOption.maxValue = 300.0;
		shitWindowOption.changeValue = 1.0;
		shitWindowOption.onChange = function() { adjustHitWindow('shitWindow', ClientPrefs.data.shitWindow); markPresetCustom(); };
		addOption(shitWindowOption);

		var useShitWindowOption:Option = new Option(
			"Use Shit Window as SafeZone",
			Language.get("useshitwindow_desc", ["启用后 safeZoneOffset 使用 Shit Window 固定值，而非通过 Safe Frames 计算"]),
			'useShitWindowAsSafeZone',
			BOOL);
		addOption(useShitWindowOption);

		var softEdgeOption:Option = new Option(
			"Soft Judgment Edge",
			Language.get("softedge_desc", ["在判定窗口的最外 20% 边缘启用软插值，避免卡边界时出现判定跳变"]),
			'softJudgmentEdge',
			BOOL);
		addOption(softEdgeOption);

		presetDependentOptions = [perfectWindowOption, sickWindowOption, goodWindowOption, badWindowOption];

		super();

		// 初始化完成后，根据当前预设刷新禁用状态
		refreshPresetDisabledState();
	}

	var presetDependentOptions:Array<Option> = null;

	function onChangeHitsoundVolume()
	{
		var useSound:String = 'hitsound';
		if (ClientPrefs.data.hitsound != 'none' && ClientPrefs.data.hitsound != null && ClientPrefs.data.hitsound.length > 0)
			useSound = 'hitsounds/' + ClientPrefs.data.hitsound;
		FlxG.sound.play(Paths.sound(useSound), ClientPrefs.data.hitsoundVolume);
	}

	function onChangeHitsound()
	{
		var soundName:String = ClientPrefs.data.hitsound;
		if (soundName != null && soundName != 'none')
			FlxG.sound.play(Paths.sound('hitsounds/' + soundName), 1.0);
	}

	function onChangeAutoPause()
		FlxG.autoPause = ClientPrefs.data.autoPause;

	function onChangeVibration()
	{
		if(ClientPrefs.data.gameOverVibration)
			lime.ui.Haptic.vibrate(0, 500);
	}

	// 添加联动逻辑：保持窗口严格升序 (perfect < sick < good < bad < shit)
	// 被联动的窗口只会跟随当前值，不会无限自增/自减。
	function adjustHitWindow(optionKey:String, newValue:Float) {
		switch(optionKey) {
			case 'perfectWindow':
				ClientPrefs.data.perfectWindow = newValue;
				if (newValue >= ClientPrefs.data.sickWindow) {
					ClientPrefs.data.sickWindow = newValue;
				}
			case 'sickWindow':
				ClientPrefs.data.sickWindow = newValue;
				if (newValue <= ClientPrefs.data.perfectWindow) {
					ClientPrefs.data.perfectWindow = newValue;
				} else if (newValue >= ClientPrefs.data.goodWindow) {
					ClientPrefs.data.goodWindow = newValue;
				}
			case 'goodWindow':
				ClientPrefs.data.goodWindow = newValue;
				if (newValue <= ClientPrefs.data.sickWindow) {
					ClientPrefs.data.sickWindow = newValue;
				} else if (newValue >= ClientPrefs.data.badWindow) {
					ClientPrefs.data.badWindow = newValue;
				}
			case 'badWindow':
				ClientPrefs.data.badWindow = newValue;
				if (newValue <= ClientPrefs.data.goodWindow) {
					ClientPrefs.data.goodWindow = newValue;
				} else if (newValue >= ClientPrefs.data.shitWindow) {
					ClientPrefs.data.shitWindow = newValue; // 与其它窗口保持一致的跟随策略
				}
			case 'shitWindow':
				ClientPrefs.data.shitWindow = newValue;
				if (newValue <= ClientPrefs.data.badWindow) {
					ClientPrefs.data.badWindow = newValue; // badWindow 跟随 shitWindow，不会无限减小
				}
			default:
		}
		// 所有窗口夹到合理范围，避免滑块溢出或顺序错乱
		function clamp(v:Float, lo:Float, hi:Float):Float { return Math.max(lo, Math.min(hi, v)); }
		ClientPrefs.data.perfectWindow = clamp(ClientPrefs.data.perfectWindow, 5,   250);
		ClientPrefs.data.sickWindow    = clamp(ClientPrefs.data.sickWindow,    15,  250);
		ClientPrefs.data.goodWindow    = clamp(ClientPrefs.data.goodWindow,    15,  250);
		ClientPrefs.data.badWindow     = clamp(ClientPrefs.data.badWindow,     15,  300);
		ClientPrefs.data.shitWindow    = clamp(ClientPrefs.data.shitWindow,    135, 300);
	}

	// 预设配置表 - 参考 Leather Engine timingPresets.txt
	// 名称, perfect, sick, good, bad, shit (单位: ms)
	static var hitWindowPresets:Map<String, { perfectWindow:Float, sickWindow:Float, goodWindow:Float, badWindow:Float, shitWindow:Float }> = [
		'Leather'      => { perfectWindow: 25.00, sickWindow: 50.00, goodWindow: 70.00,  badWindow: 100.00, shitWindow: 130.00 },
		'Psych / Kade' => { perfectWindow: 23.00, sickWindow: 45.00, goodWindow: 90.00,  badWindow: 135.00, shitWindow: 180.00 },
		'Funkin\''        => { perfectWindow: 16.00, sickWindow: 33.00, goodWindow: 124.00, badWindow: 149.00, shitWindow: 180.00 }
	];

	function onChangeHitWindowPreset()
	{
		var presetName:String = ClientPrefs.data.hitWindowPreset;

		if (hitWindowPresets.exists(presetName))
		{
			var preset = hitWindowPresets.get(presetName);
			ClientPrefs.data.perfectWindow = preset.perfectWindow;
			ClientPrefs.data.sickWindow = preset.sickWindow;
			ClientPrefs.data.goodWindow = preset.goodWindow;
			ClientPrefs.data.badWindow = preset.badWindow;
			ClientPrefs.data.shitWindow = preset.shitWindow;

			// 立刻刷新下方 4 个窗口选项的显示文本（复制 BaseOptionsMenu.updateTextFrom 的逻辑）
			for (opt in presetDependentOptions)
			{
				var val:Dynamic = opt.getValue();
				opt.text = opt.displayFormat.replace('%v', Std.string(val)).replace('%d', Std.string(opt.defaultValue));
			}
		}

		refreshPresetDisabledState();
	}

	// 根据预设切换: 非 Custom 状态下窗口滑块不可修改，Custom 状态下才解锁
	function refreshPresetDisabledState()
	{
		var isCustom:Bool = ClientPrefs.data.hitWindowPreset == 'Custom';
		for (opt in presetDependentOptions)
		{
			opt.disabled = !isCustom;
		}

		// 刷新视觉效果（改变 changeSelection 中的淡化逻辑依赖 curSelected）
		changeSelection(0);
	}

	function markPresetCustom()
	{
		// 当用户手动调整单个窗口时，自动切换到 Custom
		if (ClientPrefs.data.hitWindowPreset != 'Custom')
		{
			ClientPrefs.data.hitWindowPreset = 'Custom';
			refreshPresetDisabledState();
		}
	}
}

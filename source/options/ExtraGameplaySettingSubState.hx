package options;

class ExtraGameplaySettingSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Extra Options\nWTF, silly Chinese Option\n\nNot Done';
		rpcTitle = 'Extra Gameplay Settings Menu'; //for Discord Rich Presence

		//I'd suggest using "Downscroll" as an example for making your own option since it is the simplest here
		var option:Option = new Option('show Game Version', //Name
		"在FPS Counter的位置附加显示当前版本", //Description
		'exgameversion',
		BOOL);
		addOption(option);

		var option:Option = new Option('Focus Game', //Name
		"当游戏未处于焦点时会暂停", //Description
		'autoPause',
		BOOL);
		addOption(option);

		var option:Option = new Option('Show Extra-Rating',
		"显示额外的rating\n文件名（例子）: sick-extra.png\n别在pixel场景启用它，因为大喵没有做，除非你有类似贴图",
		'exratingDisplay',
		BOOL);
		addOption(option);

		var option:Option = new Option('Rating Bounce',
		"加强评分图标的跳动效果\n注：此选项存在较多bug，建议禁用",
		'ratbounce',
		BOOL);
		addOption(option);

		var option:Option = new Option('Extra-Rating Bounce',
		"加强扩展评分图标的跳动效果\n当然同上，这个选项也存在一些bug",
		'exratbounce',
		BOOL);
		addOption(option);

		var option:Option = new Option('Remove Perfect! Note Judgement',
		"如名，移除“Perfect！”评级\n同时扩展评级贴图也会改变",
		'rmperfect',
		BOOL);
		addOption(option);

		var option:Option = new Option('Ratings Opacity',
			'修改评级贴图的不透明度，100%为不修改.',
			'ratingsAlpha',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		var option:Option = new Option('HealthBar Style',
		"（施工中）\n设置健康条的样式",
		'healthbarstyle',
		STRING,
		['Psych', 'OS', 'Kade']);
		addOption(option);

		var option:Option = new Option('IconBop Style',
		"设置小图标的跳动样式",
		'iconbopstyle',
		STRING,
		['Psych', 'OS', 'MintRhythm', 'Kade', 'Leather', 'SB', 'Vanilla', 'VSlice', 'NONE']); // 补全选项
		addOption(option);

		var option:Option = new Option('ScoreTxt Style',
		'（施工中）\n修改scoreTxt的显示样式',
		'scoretxtstyle',
		STRING,
		['Psych', 'OS', 'MintRhythm', 'Kade']);
		addOption(option);

		var option:Option = new Option('Remove the "ms" offset',
		'移除Note命中时“xx ms”的显示\n可能会用到的功能',
		'rmmsTimeTxt',
		BOOL);
		addOption(option);

		var option:Option = new Option('ScoreTxt bounce',
		"命中Note时，scoreTxt会额外加上角度的跳动效果",
		'scoretxtbounce',
		BOOL);
		addOption(option);

		// 新增选项开始
		var option:Option = new Option('Loading Style',
		"设置加载界面的过渡样式",
		'customFadeStyle',
		STRING,
		['Vanilla', 'NovaFlare Move', 'NovaFlare Alpha', 'MintRhythm']);
		addOption(option);

		var option:Option = new Option('Single Note Splash Anim',
		"强制所有Note使用单一溅落动画",
		'forceSingleSplashAnim',
		BOOL);
		addOption(option);

		var option:Option = new Option('smooth HP Bar',
		"让血条变化更平滑",
		'smoothHP',
		BOOL);
		addOption(option);

		var option:Option = new Option('TimeBar Style',
		"设置时间条的显示样式",
		'timebarStyle',
		STRING,
		['default', 'Kade']);
		addOption(option);

		var option:Option = new Option('CPU Strums',
		"是否显示CPU的按键轨道",
		'cpuStrums',
		BOOL);
		addOption(option);

		var option:Option = new Option('BotPlayTxt Style',
		"设置BotPlay文字的样式",
		'botplayStyle',
		STRING,
		['Kade', 'Psych']);
		addOption(option);

		var option:Option = new Option('ShowCase Style',
		"设置结算界面的展示样式",
		'showcaseStyle',
		STRING,
		['Kade', 'Psych']);
		addOption(option);

		var option:Option = new Option('FPS-Txt Style',
				"设置FPS计数器的显示样式",
				'fpstxtStyle',
				STRING,
				['default', 'Kade']);
		/*option.onChange = function() {
			if (Main.fpsVar != null) {
				Main.fpsVar.updateText(); // 强制刷新文本格式
			}
		};*/
		addOption(option);

		/*var option = new Option(
			"Engine Language",
			"更改引擎界面语言",
			'language',
			'string',
			["en_us", "zh_cn", "zh_tw"]
		);
		/*option.onChange = function() {
			ClientPrefs.saveSettings();
			Language.load();
			refreshAllTexts();
		};*/
		addOption(option);
		// 新增选项结束

		super();
	}

	function onChangeHitsoundVolume()
		FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.data.hitsoundVolume);

	function onChangeAutoPause()
		FlxG.autoPause = ClientPrefs.data.autoPause;
}
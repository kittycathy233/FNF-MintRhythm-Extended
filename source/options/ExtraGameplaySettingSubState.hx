package options;

class ExtraGameplaySettingSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Extra Options\nWTF, silly Chinese Option\n\nNot Done';
		rpcTitle = 'Extra Gameplay Settings Menu'; //for Discord Rich Presence

		var option:Option = new Option('show Game Version', //Name
		Language.get("show_version_desc"), //Description
		'exgameversion',
		BOOL);
		addOption(option);

		var option:Option = new Option('Focus Game', //Name
		Language.get("focus_game_desc"), //Description
		'autoPause',
		BOOL);
		addOption(option);

		var option:Option = new Option('Show Extra-Rating',
		Language.get("show_exrating_desc"),
		'exratingDisplay',
		BOOL);
		addOption(option);

		var option:Option = new Option('Rating Bounce',
		Language.get("rating_bounce_desc"),
		'ratbounce',
		BOOL);
		addOption(option);

		var option:Option = new Option('Extra-Rating Bounce',
		Language.get("exrating_bounce_desc"),
		'exratbounce',
		BOOL);
		addOption(option);

		var option:Option = new Option('Remove Perfect! Note Judgement',
		Language.get("rm_perfect_judge_desc"),
		'rmperfect',
		BOOL);
		addOption(option);

		var option:Option = new Option('Ratings Opacity',
			Language.get("rating_opac_desc"),
			'ratingsAlpha',
			PERCENT);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		addOption(option);

		var option:Option = new Option('HealthBar Style',
		Language.get("healthbar_style_desc"),
		'healthbarstyle',
		STRING,
		['Psych', 'OS', 'Kade']);
		addOption(option);

		var option:Option = new Option('IconBop Style',
		Language.get("iconbop_style_desc"),
		'iconbopstyle',
		STRING,
		['Psych', 'OS', 'MintRhythm', 'Kade', 'Leather', 'SB', 'Vanilla', 'VSlice', 'NONE']); // 补全选项
		addOption(option);

		var option:Option = new Option('ScoreTxt Style',
		Language.get("scoretxt_style_desc"),
		'scoretxtstyle',
		STRING,
		['Psych', 'OS', 'MintRhythm', 'Kade']);
		addOption(option);

		var option:Option = new Option('Remove the "ms" offset',
		Language.get("rm_ms_offset_desc"),
		'rmmsTimeTxt',
		BOOL);
		addOption(option);

		var option:Option = new Option('ScoreTxt bounce',
		Language.get("scoretxt_bounce_desc"),
		'scoretxtbounce',
		BOOL);
		addOption(option);

		// 新增选项开始
		var option:Option = new Option('Loading Style',
		Language.get("loading_style_desc"),
		'customFadeStyle',
		STRING,
		['Vanilla', 'NovaFlare Move', 'NovaFlare Alpha', 'MintRhythm']);
		addOption(option);

		var option:Option = new Option('Single Note Splash Anim',
		Language.get("single_splashanim_desc"),
		'forceSingleSplashAnim',
		BOOL);
		addOption(option);

		var option:Option = new Option('smooth HP Bar',
		Language.get("smooth_hpbar_desc"),
		'smoothHP',
		BOOL);
		addOption(option);

		var option:Option = new Option('TimeBar Style',
		Language.get("timebar_style_desc"),
		'timebarStyle',
		STRING,
		['default', 'Kade']);
		addOption(option);

		var option:Option = new Option('CPU Strums',
		Language.get("cpu_strums_desc"),
		'cpuStrums',
		BOOL);
		addOption(option);

		var option:Option = new Option('BotPlayTxt Style',
		Language.get("botplaytxt_style_desc"),
		'botplayStyle',
		STRING,
		['Kade', 'Psych']);
		addOption(option);

		var option:Option = new Option('ShowCase Style',
		Language.get("showcase_style_desc"),
		'showcaseStyle',
		STRING,
		['Kade', 'Psych']);
		addOption(option);

		var option:Option = new Option('FPS-Txt Style',
		Language.get("fpstxt_style_desc"),
		'fpstxtStyle',
		STRING,
		['default', 'Kade']);
		addOption(option);

		var option:Option = new Option('Legacy Note Position',
		Language.get("legacy_notepos_desc"),
		'legacynotepos',
		BOOL);
		addOption(option);

		var option:Option = new Option('Ratings Position',
		Language.get("ratings_pos_desc"),
		'ratingsPos',
		STRING,
		['camHUD', 'camGame']);
		addOption(option);

		var option = new Option("Engine Language",
		Language.get("change_language_desc"),
        'language',
        STRING,
        ["en_us", "zh_cn", "zh_tw"]
        );
		option.onChange = function() {
			ClientPrefs.saveSettings(); // 保存设置
			Language.load();            // 立即重载语言
			refreshAllTexts();          // 自定义方法刷新界面文本
		};
		addOption(option);

		super();
	}

	function onChangeHitsoundVolume()
		FlxG.sound.play(Paths.sound('hitsound'), ClientPrefs.data.hitsoundVolume);

	function onChangeAutoPause()
		FlxG.autoPause = ClientPrefs.data.autoPause;
}
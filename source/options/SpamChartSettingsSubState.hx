package options;

class SpamChartSettingsSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = LanguageBasic.getPhrase('spam_chart_menu', 'Spam Chart Settings');
		rpcTitle = 'Spam Chart Settings Menu'; //for Discord Rich Presence

		// ===== 高密度谱面（SPAM）性能优化 =====
		var option:Option = new Option(Language.get('combo_sprite_pooling'),
			Language.get("combo_sprite_pooling_desc"),
			'comboSpritePooling',
			BOOL);
		addOption(option);

		option = new Option(Language.get('hide_missed_notes_cull'),
			Language.get("hide_missed_notes_desc"),
			'hideMissedNotes',
			BOOL);
		addOption(option);

		option = new Option(Language.get('low_latency_mode'),
			Language.get("low_latency_desc"),
			'lowLatency',
			BOOL);
		addOption(option);

		option = new Option(Language.get('instant_resolve_expired_notes'),
			Language.get("instant_resolve_expired_desc"),
			'instantResolveExpired',
			BOOL);
		addOption(option);

		option = new Option(Language.get('disable_per_note_scripts'),
			Language.get("disable_note_lua_desc"),
			'disableNoteLua',
			BOOL);
		addOption(option);

		option = new Option(Language.get('note_performance_optimization'),
			Language.get("note_optimization_desc"),
			'noteOptimization',
			BOOL);
		addOption(option);

		option = new Option(Language.get('note_object_pooling'),
			Language.get("note_pooling_desc"),
			'notePooling',
			BOOL);
		addOption(option);

		option = new Option(Language.get('max_notes_spawned_frame'),
			Language.get("max_notes_per_frame_desc"),
			'maxNotesPerFrame',
			INT);
		option.scrollSpeed = 60;
		option.minValue = 0;
		option.maxValue = 300;
		option.changeValue = 5;
		option.decimals = 0;
		addOption(option);

		super();
	}
}

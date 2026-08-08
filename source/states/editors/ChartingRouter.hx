package states.editors;

import backend.ClientPrefs;
import states.PlayState;
import states.LoadingState;
import states.editors.old.OldChartingState063;
import states.editors.old.OldChartingState073;

/**
 * 根据 ClientPrefs.data.chartingVersion 路由到对应版本的制谱器：
 *  - '0.6.3' -> OldChartingState063
 *  - '0.7.3' -> OldChartingState073
 *  - 其它(默认 '1.0') -> 现有 ChartingState (PE 1.0)
 *
 * 两个旧版制谱器是 4 键时代的产物（网格/音符/判定线全部硬编码为 4 轨），
 * 因此遇到多键谱面时会自动回落到 1.0 制谱器，避免进入后画面错位或崩溃。
 */
class ChartingRouter
{
	public static final VERSION_1_0:String = '1.0';
	public static final VERSION_0_7_3:String = '0.7.3';
	public static final VERSION_0_6_3:String = '0.6.3';

	public static final VERSIONS:Array<String> = [VERSION_1_0, VERSION_0_7_3, VERSION_0_6_3];

	/** 旧版制谱器只认 4 键谱面（mania == 3，缺省视为 4 键）。 */
	public static function currentChartIsFourKey():Bool
	{
		var song = PlayState.SONG;
		return song == null || song.mania == null || song.mania == 3;
	}

	/** 解析出实际可用的制谱器版本，必要时回落到 1.0。 */
	public static function resolveVersion():String
	{
		var version:String = ClientPrefs.data.chartingVersion;
		if (version == null || VERSIONS.indexOf(version) < 0)
			return VERSION_1_0;

		if (version != VERSION_1_0 && !currentChartIsFourKey())
		{
			trace('ChartingRouter: "${PlayState.SONG.song}" is a ${PlayState.SONG.mania + 1}K chart, '
				+ 'the $version editor only supports 4K -> falling back to the $VERSION_1_0 editor.');
			return VERSION_1_0;
		}
		return version;
	}

	public static function createChartingState():MusicBeatState
	{
		return switch (resolveVersion())
		{
			case VERSION_0_6_3: new OldChartingState063();
			case VERSION_0_7_3: new OldChartingState073();
			default: new ChartingState();
		}
	}

	public static function openChartingEditor(useLoadingState:Bool = false):Void
	{
		var state:MusicBeatState = createChartingState();

		if (useLoadingState)
			LoadingState.loadAndSwitchState(state, false);
		else
			MusicBeatState.switchState(state);
	}
}

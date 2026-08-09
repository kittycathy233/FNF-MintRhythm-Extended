package substates;

import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;

import states.MainMenuState;
import states.TitleState;
import backend.Language;

class OutdatedSubState extends MusicBeatSubstate
{
	var updateVersion:String;
	var leftState:Bool = false;

	public function new(updateVersion:String)
	{
		super();
		this.updateVersion = updateVersion;
	}

	var bg:FlxSprite;
	var warnText:FlxText;

	override function create()
	{
		controls.isInSubstate = true;
		final enter:String = (controls.mobileC) ? 'A' : 'ENTER';
		final back:String = (controls.mobileC) ? 'B' : 'BACK';

		super.create();

		bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.scrollFactor.set();
		bg.alpha = 0.0;
		add(bg);

		final warningHeader:String = Language.get('outdated_header', [MainMenuState.kathyEngineVersion]);
		final warningUpdate:String = Language.get('outdated_update', [enter, updateVersion]);
		final warningProceed:String = Language.get('outdated_proceed', [back]);
		final warningDisable:String = Language.get('outdated_disable');
		final warningFooter:String = Language.get('outdated_footer');

		final warningLines:Array<String> = [
			warningHeader,
			'-----------------------------------------------',
			warningUpdate,
			warningProceed,
			warningDisable,
			'-----------------------------------------------',
			warningFooter
		];

		warnText = new FlxText(0, 0, FlxG.width, warningLines.join('\n'), 32);
		warnText.setFormat(Paths.font(Language.get('game_font')), 32, FlxColor.WHITE, CENTER);
		warnText.scrollFactor.set();
		warnText.screenCenter(Y);
		warnText.alpha = 0.0;
		add(warnText);

		addTouchPad("NONE", "A_B");
		addTouchPadCamera();
		touchPad.alpha = 0;
		touchPad.visible = controls.mobileC; // 仅在移动端显示触摸板

		FlxTween.tween(bg, { alpha: 0.8 }, 0.6, { ease: FlxEase.sineIn });
		FlxTween.tween(warnText, { alpha: 1.0 }, 0.6, { ease: FlxEase.sineIn });
		if (controls.mobileC)
			FlxTween.tween(touchPad, { alpha: 1.0 }, 0.6, { ease: FlxEase.sineIn });
	}

	override function update(elapsed:Float)
	{
		if(!leftState) {
			if (controls.ACCEPT) {
				leftState = true;
				CoolUtil.browserLoad("https://github.com/kittycathy114/FNF-KathyEngine/releases");
			}
			else if(controls.BACK) {
				leftState = true;
			}
			if(leftState)
			{
				FlxG.sound.play(Paths.sound('cancelMenu'));
				FlxTween.tween(bg, { alpha: 0.0 }, 0.9, { ease: FlxEase.sineOut });
				FlxTween.tween(touchPad, { alpha: 0.0 }, 1, { ease: FlxEase.sineOut });
				FlxTween.tween(warnText, {alpha: 0}, 1, {
					ease: FlxEase.sineOut,
					onComplete: function (twn:FlxTween) {
						FlxG.state.persistentUpdate = true;
						controls.isInSubstate = false;
						close();
					}
				});
			}
		}
		super.update(elapsed);
	}
}

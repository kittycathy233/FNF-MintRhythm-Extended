package states.editors.old;

import flixel.addons.ui.FlxUITooltipManager;
import flixel.addons.ui.interfaces.IEventGetter;
import flixel.addons.ui.interfaces.IFireTongue;
import flixel.addons.ui.interfaces.IFlxUIState;
import flixel.addons.ui.interfaces.IFlxUIWidget;
#if FLX_MOUSE
import flixel.addons.ui.FlxUICursor;
#end

/**
 * Bridge state for the back-ported 0.6.3 / 0.7.3 chart editors.
 *
 * Those editors are built on `flixel-ui` widgets, which broadcast their interactions through
 * `FlxUI.event()`. That helper only delivers events when the currently active (sub)state
 * implements `IFlxUIState` -- something Psych 1.0's `MusicBeatState` does not do (it dropped
 * `FlxUIState` in favour of `PsychUI`).
 *
 * Instead of turning `MusicBeatState` back into a `FlxUIState` (which would affect the whole
 * engine), this thin subclass only adds the interface surface the widgets need, so the legacy
 * editors keep working untouched while the rest of the engine stays on the 1.0 base.
 *
 * NOTE: `tooltips` intentionally stays `null`. `FlxUITooltipManager` can only be constructed from a
 * real `FlxUIState`/`FlxUISubState`, and flixel-ui only dereferences it while parsing XML-defined
 * UIs -- something the ported editors never do (every widget is built in code).
 */
class OldEditorState extends MusicBeatState implements IEventGetter implements IFlxUIState
{
	public var tooltips(default, null):FlxUITooltipManager = null;
	#if FLX_MOUSE
	public var cursor:FlxUICursor = null;
	#end
	private var _tongue:IFireTongue = null;

	/** Mirrors `FlxUIState.forceFocus`; the ported editors never build a root `FlxUI`, so this is a no-op. */
	public function forceFocus(b:Bool, thing:IFlxUIWidget):Void {}

	public function getEvent(name:String, sender:IFlxUIWidget, data:Dynamic, ?params:Array<Dynamic>):Void {}

	public function getRequest(name:String, sender:IFlxUIWidget, data:Dynamic, ?params:Array<Dynamic>):Dynamic
		return null;
}

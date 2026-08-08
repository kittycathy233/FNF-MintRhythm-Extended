package states.editors.old;

import flixel.addons.ui.FlxUIDropDownMenu;
import flixel.addons.ui.StrNameLabel;
import flixel.addons.ui.FlxUI9SliceSprite;

/**
 * 兼容层：复刻 Psych Engine 0.6.x 的 FlxUIDropDownMenuCustom 构造签名
 * (x, y, ?data:Array<StrNameLabel>, ?callback:String->Void)，
 * 实际委托给 flixel-ui 2.6.5 的 FlxUIDropDownMenu。
 */
class FlxUIDropDownMenuCustom extends FlxUIDropDownMenu
{
	public function new(x:Float = 0, y:Float = 0, ?data:Array<StrNameLabel>, ?callback:String->Void)
	{
		super(x, y, data, callback);
		if (dropPanel != null)
			dropPanel.visible = false;
	}

	public static function makeStrIdLabelArray(data:Array<String>, useIndexID:Bool = false):Array<StrNameLabel>
	{
		return FlxUIDropDownMenu.makeStrIdLabelArray(data, useIndexID);
	}
}

package options;

/**
 * Options configuration constants
 * Centralized configuration for menu layout and behavior
 */
class OptionsConfig
{
	// Layout spacing
	public static final ITEM_SPACING:Int = 72;
	public static final LEFT_MARGIN:Int = 120;

	// Animation speeds
	public static final SELECTOR_LERP_SPEED:Float = 12;
	public static final SCALE_LERP_SPEED:Float = 16;

	// Selection scaling
	public static final SELECTED_SCALE:Float = 1.08;
	public static final NORMAL_SCALE:Float = 1.0;

	// Interaction timings
	public static final DOUBLE_CLICK_THRESHOLD:Float = 0.25;
	public static final INPUT_COOLDOWN:Float = 0.5;
	public static final TWEEN_DURATION:Float = 0.3;

	// Description box（负值为距屏幕底部偏移，越小越靠下）
	public static final DESC_Y_START:Float = -170;
	public static final DESC_Y_END:Float = -120;

	// Keybind settings
	public static final HOLD_THRESHOLD:Float = 0.5;
	public static final MAX_KEYBIND_WIDTH:Int = 320;

	// --- Submenu list layout (FlxText-based, replaces Alphabet rendering) ---
	// X position of the option label. Value/keybind columns are offset to the right.
	public static final SUBMENU_ITEM_X:Int = 220;
	// Font size for the option label and its value/keybind text.
	public static final SUBMENU_ITEM_SIZE:Int = 32;
	public static final SUBMENU_VALUE_SIZE:Int = 32;
	// Vertical distance between two consecutive list items.
	public static final SUBMENU_ITEM_SPACING:Float = 56;
	// Selected item is placed at this fraction of the screen height (keeps room for the description box).
	public static final SUBMENU_SELECTED_Y_RATIO:Float = 0.40;
	// Smoothing factor for the list scroll/scale/alpha animation (higher = snappier).
	public static final SUBMENU_LAYOUT_LERP:Float = 16;
	// How much the selected item is scaled up vs the others.
	public static final SUBMENU_SELECTED_SCALE:Float = 1.08;
	public static final SUBMENU_NORMAL_SCALE:Float = 1.0;
	// How far (px) the selected item shifts to the right for emphasis.
	public static final SUBMENU_SELECTED_OFFSET_X:Float = 30;

	// Opacity of the selected vs non-selected list items.
	// Non-selected uses a flat value (no distance falloff) so far items stay readable.
	public static final SUBMENU_SELECTED_ALPHA:Float = 1.0;
	public static final SUBMENU_UNSELECTED_ALPHA:Float = 0.72;
	// Disabled options are further dimmed by multiplying with this factor.
	// Kept high enough to stay readable so the name and prerequisite are legible.
	public static final SUBMENU_DISABLED_ALPHA_MULT:Float = 0.55;
	// Accent color for STRING (selectable/cycleable) option values, like the noteskin picker.
	public static final SUBMENU_STRING_COLOR:Int = 0xFF5CD6FF;
	// Arrow glyphs shown around STRING values to indicate they can be cycled left/right.
	public static final SUBMENU_STRING_ARROW:String = '‹ ›';
	// BOOL 选项启用/禁用配色（亮绿 / 亮红），比默认 GREEN/RED 更醒目
	public static final OPTION_ON_COLOR:Int = 0xFF4DFF8C;   // 亮绿
	public static final OPTION_OFF_COLOR:Int = 0xFFFF5C7A;  // 亮红
}

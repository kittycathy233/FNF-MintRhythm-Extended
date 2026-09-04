package backend;

import flixel.graphics.FlxGraphic;
import flixel.system.FlxAssets;
import openfl.Assets;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.geom.Matrix;
import openfl.text.AntiAliasType;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.text.TextFormatAlign;
import openfl.text.TextFieldAutoSize;

/**
 * 图片资源加载失败时的“就地定位标记”。
 *
 * 原理：把失败资源渲染成一张「左上 L 形角标 + flixel 默认 logo + 半透明底 + Failed 指引行 + 路径行」
 * 的占位贴图，由 Paths.cacheBitmap 返回给调用方。L 形角标交点相对资源锚点(贴图左上角)向右下偏移 4px，
 * 箭头仍指向资源生成位置。占位图被持续缓存，只构建一次。
 *
 * 仅当 ClientPrefs.data.assetErrorOverlay 开启时返回占位图（默认关闭，关闭时
 * Paths 仍返回 null，不改变引擎原有的“缺图即静默跳过”行为）。
 */
class AssetErrorOverlay
{
	/** 已生成的占位贴图缓存（按失败路径），避免同一资源反复重建。 */
	public static var cache:Map<String, FlxGraphic> = [];

	/** 失败时生成占位贴图；开关关闭或生成失败时返回 null。 */
	public static function makePlaceholder(path:String):FlxGraphic
	{
		if (path == null || (ClientPrefs.data != null && !ClientPrefs.data.assetErrorOverlay))
			return null;

		if (cache.exists(path))
		{
			var old:FlxGraphic = cache.get(path);
			// 兜底：旧 graphic 若已被 flixel 的 clearUnused 销毁，则丢弃重建，
			// 避免返回销毁图导致调用方回退成“仅 flixel 默认贴图”。
			if (old != null && old.bitmap != null)
				return old;
			cache.remove(path);
		}

		var bd:BitmapData = null;
		try
		{
			bd = buildPlaceholderBitmap(path);
		}
		catch (e:Dynamic)
		{
			bd = null;
		}

		// 健壮性：只要开关开启，就绝不静默退化回 flixel 默认图。
		// 文本绘制失败等极端情况也退回一张“底 + L 角标”的纯标记，而不是 null。
		if (bd == null)
		{
			try
			{
				bd = buildFallbackBitmap();
			}
			catch (e:Dynamic)
			{
				bd = null;
			}
		}
		if (bd == null)
			return null;

		var key:String = 'assetErrorOverlay://' + path;
		var gfx:FlxGraphic = FlxGraphic.fromBitmapData(bd, true, key);
		// 保护位图：状态/界面销毁时不被 clearUnused 回收，重进界面仍能拿到完整贴图。
		gfx.persist = true;
		gfx.destroyOnNoUse = false;
		cache.set(path, gfx);
		return gfx;
	}

	/** 清除占位图缓存。切换开关或希望立即生效时可调用，令后续请求重新构建。 */
	public static function clearCache():Void
	{
		cache.clear();
	}

	/** 兜底：仅“半透明底 + 白 L 角标”，不依赖 logo/文本绘制，保证缺失时总能给出可见标记。 */
	static function buildFallbackBitmap():BitmapData
	{
		var w:Int = 40;
		var h:Int = 40;
		var arm:Int = 20;
		var root:Sprite = new Sprite();
		root.graphics.beginFill(0x000000, 0.45);
		root.graphics.drawRect(0, 0, w, h);
		root.graphics.endFill();
		var lspr:Sprite = new Sprite();
		lspr.graphics.lineStyle(2, 0xFFFFFF);
		lspr.graphics.moveTo(0, 0);
		lspr.graphics.lineTo(0, arm);
		lspr.graphics.moveTo(0, 0);
		lspr.graphics.lineTo(arm, 0);
		lineStyleReset(lspr);
		root.addChild(lspr);
		var bd:BitmapData = new BitmapData(w, h, true, 0x00000000);
		bd.draw(root);
		return bd;
	}

	/**
	 * 绘制占位图：半透明底 + 左上 L 形角标（交点相对资源锚点右下偏移 4px）+ flixel 默认 logo + 两行文本。
	 * 无描边、logo 关闭平滑，尽量降低构建与内存开销。
	 */
	static function buildPlaceholderBitmap(path:String):BitmapData
	{
		var arm:Int = 20; // L 臂长
		var lw:Int = 4; // 主线宽
		var off:Int = 0; // L 角标偏移（贴 0,0，无偏移）
		var pad:Int = 8;
		var logoGap:Int = 6; // logo/文本区与 L 右臂的间距
		var logoShift:Int = 2; // logo 相对 L 角标交点的右偏移
		var lineGap:Int = 2; // 两行文本间距

		// 加载 flixel 默认 logo（占位图的“默认贴图”暗示），缩放至小尺寸
		var logo:Bitmap = null;
		var logoW:Int = 0;
		var logoH:Float = 0;
		try
		{
			var lBmp:BitmapData = Assets.getBitmapData('flixel/images/logo/default.png');
			if (lBmp != null)
			{
				logoH = 22;
				var scale:Float = logoH / lBmp.height;
				logoW = Std.int(lBmp.width * scale);
				logo = new Bitmap(lBmp);
				logo.scaleX = scale;
				logo.scaleY = scale;
				logo.smoothing = false; // 取消平滑，贴近像素、省性能
			}
		}
		catch (e:Dynamic)
		{
			logo = null;
			logoW = 0;
		}

		var titleRow:TextField = makeRow('Failed to load asset:', 12, 0xFFFFFF, true);
		var pathRow:TextField = makeRow(cleanDisplayPath(path), 10, 0xFFD54A, false);

		var textW:Int = Std.int(Math.max(titleRow.textWidth, pathRow.textWidth));
		var textH:Float = titleRow.textHeight + pathRow.textHeight + lineGap;
		// 文本区右沿（L 右臂或 logo 右沿，取靠外侧的防重叠）
		var contentRight:Int = Std.int(Math.max(off + arm, off + logoShift + logoW));
		var textX:Int = contentRight + logoGap;
		var refH:Float = Math.max(arm, Math.max(logoH, textH));
		var W:Int = textX + ((textW > 0) ? textW : 0) + pad;
		var H:Int = Std.int(Math.max(refH, logoH)) + pad * 2;

		// 半透明深色底
		var root:Sprite = new Sprite();
		root.graphics.beginFill(0x000000, 0.45);
		root.graphics.drawRect(0, 0, W, H);
		root.graphics.endFill();

		// 第一层：flixel 默认 logo（在 L 角标之下），位置与 L 交点相同再右移 logoShift，垂直接背景顶
		if (logo != null)
		{
			logo.x = off + logoShift;
			logo.y = 0;
			root.addChild(logo);
		}

		// 第二层：白色细 L 角标用独立 Sprite 绘制，盖在 logo 之上；交点垂直接背景顶(0)，水平右移 off
		var lspr:Sprite = new Sprite();
		lspr.graphics.lineStyle(lw, 0xFFFFFF);
		lspr.graphics.moveTo(off, 0);
		lspr.graphics.lineTo(off, arm);
		lspr.graphics.moveTo(off, 0);
		lspr.graphics.lineTo(off + arm, 0);
		lineStyleReset(lspr);
		root.addChild(lspr);

		if (textW > 0)
		{
			var tx:Float = textX;
			var ty:Float = Math.max((H - textH) / 2, pad * 0.5);
			titleRow.x = tx;
			titleRow.y = ty;
			pathRow.x = tx;
			pathRow.y = ty + titleRow.textHeight + lineGap;
			root.addChild(titleRow);
			root.addChild(pathRow);
		}

		var bd:BitmapData = new BitmapData(W, H, true, 0x00000000);
		bd.draw(root);
		return bd;
	}

	static function makeRow(text:String, size:Int, color:Int, bold:Bool):TextField
	{
		var tf:TextField = new TextField();
		var fmt:TextFormat = new TextFormat();
		fmt.size = size;
		fmt.bold = bold;
		fmt.color = color;
		fmt.align = TextFormatAlign.LEFT;
		fmt.font = FlxAssets.FONT_DEFAULT;
		tf.defaultTextFormat = fmt;
		tf.embedFonts = true;
		// 取消抗锯齿：锐利渲染
		tf.antiAliasType = AntiAliasType.NORMAL;
		tf.sharpness = 400;
		tf.selectable = false;
		tf.autoSize = TextFieldAutoSize.LEFT;
		tf.text = text;
		return tf;
	}

	static function lineStyleReset(s:Sprite):Void
	{
		s.graphics.lineStyle(0, 0, 0);
	}

	/** 去掉路径行里冗余的资产根目录前缀（如 `assets/`、`mods/<mod>/assets/`），便于阅读。 */
	static function cleanDisplayPath(path:String):String
	{
		var p:String = path;
		var idx:Int = p.indexOf('/assets/');
		if (idx >= 0)
			p = p.substr(idx + '/assets/'.length);
		else if (StringTools.startsWith(p, 'assets/'))
			p = p.substr('assets/'.length);
		return p;
	}
}
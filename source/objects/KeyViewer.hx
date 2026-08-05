package objects;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxBasic;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import backend.Paths;
import backend.ClientPrefs;
import states.PlayState;
import flixel.input.keyboard.FlxKey;
import openfl.display.Shape;
import openfl.display.BitmapData;
import openfl.display.BitmapDataChannel;
import openfl.geom.Matrix;
import openfl.geom.Point;
import openfl.geom.Rectangle;

/**
 * 游戏内按键显示覆盖层（KeyViewer）。
 * 复刻 JKPS 的 dark-minimalistic-nano + white-orange 主题：
 *   - 深色背景块 (25,25,25)，圆角 + 1px 描边
 *   - 按键本体为代码绘制的圆角深色块，圆角描边（默认白，按下立刻变橙黄）
 *   - 按下发光层为代码绘制的圆角橙黄填充，平滑淡入淡出（white-orange 的 Light animation 色 255,180,0）
 *   - 白色键名 (BlackSugarPlumCandy-Bold.ttf，支持中英日韩)
 *   - 显示 KPS / Total / Max
 *   - 可选资料条（ClientPrefs.keyViewerProfile）：左侧放圆角裁剪的自定义图标，底部显示自定义名字；
 *     没有图标（或选项关闭）时左侧不留空缺，按键在背景中垂直居中
 * 按键布局跟随玩家实际键位（multikey / mania），全部用矢量代码绘制，不依赖贴图。
 */
class KeyViewer extends FlxGroup
{
	// ---- 主题配色（dark-minimalistic-nano）----
	static final BG_COLOR:FlxColor = 0xFF191919; // 25,25,25
	static final TEXT_COLOR:FlxColor = 0xFFFFFFFF; // 白色
	static final FONT_NAME:String = 'BlackSugarPlumCandy-Bold.ttf'; // 支持中英日韩

	// ---- 按键按钮尺寸 ----
	static final SLOT_W:Int = 56;     // 按键槽位宽度（用于布局与背景，保持不变）
	static final BTN_SIZE:Int = 46;   // 实际按键视觉尺寸（比槽位小，留出圆角/间距感）
	static final BTN_GAP:Int = 8;
	static final TEXT_AREA_W:Int = 100; // 按键右侧统计文本区宽度（有图标时左侧图标区同宽）

	// ---- 描边（圆角描边，复刻 white-orange 主题）----
	static final BORDER_THICK:Int = 3;            // 按键描边厚度（像素）
	static final BORDER_COLOR:FlxColor = 0xFFFFFFFF; // 描边默认色（白）
	static final PRESS_COLOR:FlxColor = 0xFFFFB400;  // 按下高亮色（白橙主题：橙黄 255,180,0）
	static final CAP_COLOR:FlxColor = 0xFF1E1E1E;    // 按键本体深色（JKPS button 30,30,30）
	static final GLOW_ALPHA_MAX:Float = 0.65;        // 按下发光层最大不透明度
	static final KEY_RADIUS:Float = 10;              // 按键圆角半径
	static final BG_BORDER_THICK:Int = 1;            // 背景描边厚度（1px）
	static final BG_RADIUS:Float = 18;               // 背景圆角半径（稍大）

	// ---- 可选的「图标 + 名字」资料条（ClientPrefs.keyViewerProfile）----
	static final NAME_FONT_SIZE:Int = 15;
	static final NAME_TOP_PAD:Int = 4;      // 名字条与按键描边的间距（紧贴正下方）
	static final NAME_BOTTOM_PAD:Int = 6;   // 名字条底部与背景底边间距（略宽）
	static final NAME_LINE_GAP:Int = 8;     // 名字单行额外行高（受控，不依赖字体自带大行距）
	static final ICON_PAD:Int = 8;        // 图标距左侧区域边缘的内边距
	static final ICON_RADIUS:Float = 10;  // 图标圆角裁剪半径（实际角半径，单位像素）
	static final ICON_KEYS:Array<String> = ['keyViewer/icon', 'keyviewer/icon']; // 图标查找路径（大小写兼容）
	static final NAME_FILES:Array<String> = ['images/keyViewer/name.txt', 'images/keyviewer/name.txt'];
	static final DEFAULT_NAME:String = 'PLAYER';

	// ---- 按键轨迹可视化（复刻 JKPS Key press visualization）----
	static final VIS_SPEED:Float = 2.5;       // 每帧向上移动/拉长速度（≈ JKPS speed 60 的缩放）
	static final FADE_DIST:Float = 500;       // 飘出消失距离（Fade out distance）
	static final MAX_STRETCH:Float = 250;     // 按住时长条最大拉长量（上限）
	static final FADE_LINE:Float = 200;       // 遮罩线：距按键顶端 200px，白块超出此线被裁切渐隐
	static final VIS_SPAWN_Y:Float = -5;      // 生成位置相对按钮顶端的偏移（Spawn position offset 0,-5）
	static final PARTICLE_H:Float = 16;       // 单条轨迹粒子高度
	static final POOL_PER_KEY:Int = 12;       // 每键粒子池容量（上限同时存在的轨迹数）

	var keysArray:Array<String>;
	var keyCaps:Array<FlxSprite> = [];   // 按键本体（圆角深色填充）
	var keyBorders:Array<FlxSprite> = []; // 按键圆角描边外框（按下时颜色立刻变橙黄）
	var keyGlows:Array<FlxSprite> = [];  // 按键按下发光层（圆角橙黄，平滑淡入淡出）
	var keyLabels:Array<FlxText> = [];
	var keyPressGlow:Array<Float> = []; // 发光层按下强度 0..1（平滑动画）

	// 按键轨迹可视化粒子：particles[i] = 第 i 个键的粒子池
	// 按住时该条从按键顶端持续向上"拉长"（stretch 增长），松开后整条上飘（drift 增长）
	var particles:Array<Array<FlxSprite>> = [];
	var particleStretch:Array<Array<Float>> = []; // 按住期间已拉长量
	var particleDrift:Array<Array<Float>> = [];   // 松开后已上飘量
	var particleHolding:Array<Array<Bool>> = [];  // 该条当前是否仍处于按住状态
	var particleAnchorY:Array<Array<Float>> = []; // 长条底部锚定 y（按键顶端附近）

	var statsText:FlxText; // 右侧 KPS / Total / Max（单行多行文本，收紧行距）

	var iconSprite:FlxSprite; // 左侧自定义图标（可为 null）
	var nameText:FlxText;     // 底部自定义名字（可为 null）

	var keyTimes:Array<Float> = []; // 最近一次按下的时间戳（毫秒），用于计算 KPS
	var totalKeys:Int = 0;
	var maxKps:Int = 0; // 峰值 KPS

	var startTime:Float = 0;
	var saveDirty:Bool = false;   // Total 发生变化，待落盘
	var lastSaveAt:Float = -9999; // 上次落盘时间（毫秒），用于节流

	public function new()
	{
		super();

		// 累计按键总数：从持久存档读取，跨游戏重启保留
		totalKeys = ClientPrefs.data.keyViewerTotal;

		// 读取玩家实际键位（当前 mania 的 action 列表）
		keysArray = PlayState.instance.keysArray.copy();

		var nKeys:Int = keysArray.length;
		// 布局使用固定槽位 SLOT_W，使背景面板尺寸不随按键视觉大小变化
		var totalWidth:Int = nKeys * SLOT_W + (nKeys - 1) * BTN_GAP;

		// ---- 资料条（左侧图标 + 底部名字）----
		var profileOn:Bool = ClientPrefs.data.keyViewerProfile;
		var iconKey:String = profileOn ? findIconKey() : null;
		var iconBmp:BitmapData = null;
		if (iconKey != null)
		{
			// 必须 allowGPU=false：本引擎在 GPU 缓存开启时会丢弃位图的 CPU surface，
			// 之后用 BitmapData.draw 绘制它会触发 Cairo 段错误（cairo_paint）。
			var graphic = Paths.image(iconKey, null, false);
			if (graphic != null && graphic.bitmap != null && graphic.bitmap.width > 0 && graphic.bitmap.height > 0)
				iconBmp = graphic.bitmap;
		}
		var hasIcon:Bool = (iconBmp != null);

		// 左侧区域宽度：仅在「资料条开启且找到图标」时才留出空缺，其余情况一律收起（最左按键左侧无空缺）
		var leftW:Int = hasIcon ? TEXT_AREA_W : 0;

		var keyAreaH:Int = SLOT_W + BTN_GAP * 2; // 按键区高度（用于居中按键与右侧统计）

		// 背景宽度不依赖名字条高度，先算出来，用于创建名字文本
		var bgW:Int = leftW + BTN_GAP * 2 + totalWidth + TEXT_AREA_W;

		// 底部名字文本（资料条开启时始终显示，可多行；先创建以定位）
		var nameBandH:Float = 0;
		if (profileOn)
		{
			nameText = new FlxText(0, 0, bgW, getProfileName(), NAME_FONT_SIZE);
			nameText.setFormat(Paths.font(FONT_NAME), NAME_FONT_SIZE, TEXT_COLOR, CENTER);
			nameText.scrollFactor.set(0, 0);
			// 用受控行高计算文本块高度，不信任字体自带的大行距/度量，避免背景被撑爆或文本溢出
			var lineCount:Int = getProfileName().split('\n').length;
			nameBandH = lineCount * (NAME_FONT_SIZE + NAME_LINE_GAP);
		}

		// 背景高度 = 按键区 + 紧贴按键描边下方的名字带（含上下内边距）
		// 按键在按键区内垂直居中，其底边距按键区底边为 (keyAreaH - BTN_SIZE) / 2，
		// 故按键底边相对背景顶边的偏移 = (keyAreaH + BTN_SIZE) / 2。
		var bgH:Int = Math.ceil((keyAreaH + BTN_SIZE) / 2 + NAME_TOP_PAD + nameBandH + NAME_BOTTOM_PAD);
		var bgX:Float = (FlxG.width - bgW) / 2; // 整个面板居中于屏幕
		var bgY:Float = FlxG.height - bgH - 6;

		// 按键在按键区内垂直居中
		var yPos:Float = bgY + (keyAreaH - BTN_SIZE) / 2;

		// 背景面板（圆角 + 1px 描边）
		var bg = makeRoundRect(bgW, bgH, BG_COLOR, BG_BORDER_THICK, BORDER_COLOR, BG_RADIUS);
		bg.setPosition(bgX, bgY);
		bg.alpha = 0.85;
		bg.scrollFactor.set(0, 0);
		add(bg);

		// 左侧自定义图标：等比缩小到合理尺寸（只缩不放）+ 圆角裁剪，
		// 尺寸上限取「左侧槽宽」与「按键区高度」较小者，避免显得过大；位置在整个面板（含名字条）内垂直居中
		if (hasIcon)
		{
			var maxW:Float = leftW - ICON_PAD * 2;
			var maxH:Float = keyAreaH - ICON_PAD * 2;
			var sc:Float = Math.min(maxW / iconBmp.width, maxH / iconBmp.height);
			if (sc > 1) sc = 1; // 图标本身较小时不放大，避免糊图
			var iw:Int = Std.int(Math.max(1, Math.round(iconBmp.width * sc)));
			var ih:Int = Std.int(Math.max(1, Math.round(iconBmp.height * sc)));

			var icon = new FlxSprite();
			icon.loadGraphic(makeRoundedBitmap(iconBmp, iw, ih, ICON_RADIUS));
			icon.setPosition(
				Math.round(bgX + (leftW - iw) / 2),
				Math.round(bgY + (bgH - ih) / 2)); // 含名字条的整块内垂直居中
			icon.scrollFactor.set(0, 0);
			icon.antialiasing = ClientPrefs.data.antialiasing;
			add(icon);
			iconSprite = icon;
		}

		// 按键区域起点（左侧区域 + 内边距）
		var keyStartX:Float = bgX + leftW + BTN_GAP;

		for (i in 0...nKeys)
		{
			var slotX:Float = keyStartX + i * (SLOT_W + BTN_GAP);
			var bx:Float = slotX + (SLOT_W - BTN_SIZE) / 2;

			// 按键本体：圆角深色填充（替代 Button.png 贴图）
			var cap = makeRoundRect(BTN_SIZE, BTN_SIZE, CAP_COLOR, 0, 0, KEY_RADIUS);
			cap.setPosition(bx, yPos);
			cap.scrollFactor.set(0, 0);
			add(cap);
			keyCaps.push(cap);

			// 按键按下发光层：圆角橙黄填充，alpha 平滑变化（替代 Animation.png）
			var glow = makeRoundRect(BTN_SIZE, BTN_SIZE, PRESS_COLOR, 0, 0, KEY_RADIUS);
			glow.setPosition(bx, yPos);
			glow.scrollFactor.set(0, 0);
			glow.alpha = 0;
			glow.scale.set(0.85, 0.85);
			add(glow);
			keyGlows.push(glow);

			// 按键圆角描边外框（按下时颜色立刻切换，不与发光层共用缓动）
			var border = makeRoundRect(BTN_SIZE, BTN_SIZE, FlxColor.TRANSPARENT, BORDER_THICK, BORDER_COLOR, KEY_RADIUS);
			border.setPosition(bx, yPos);
			border.scrollFactor.set(0, 0);
			add(border);
			keyBorders.push(border);

			// 键名文字（真实物理按键）
			var label = new FlxText(bx, yPos + (BTN_SIZE - 16) / 2, BTN_SIZE, getKeyName(keysArray[i]), 16);
			label.setFormat(Paths.font(FONT_NAME), 16, TEXT_COLOR, CENTER);
			label.scrollFactor.set(0, 0);
			add(label);
			keyLabels.push(label);

			keyPressGlow.push(0.0);

			// 预建该键的轨迹可视化粒子池（按下时激活：先拉长，松开后上飘消失）
			var pPool:Array<FlxSprite> = [];
			var pStretch:Array<Float> = [];
			var pDrift:Array<Float> = [];
			var pHolding:Array<Bool> = [];
			var pAnchor:Array<Float> = [];
			var pW:Float = BTN_SIZE; // 轨迹条宽度跟随按键（描边）宽度
			for (p in 0...POOL_PER_KEY)
			{
				var pSpr = new FlxSprite(bx + (BTN_SIZE - pW) / 2, yPos);
				pSpr.makeGraphic(Math.round(pW), Math.round(PARTICLE_H), TEXT_COLOR);
				pSpr.scrollFactor.set(0, 0);
				pSpr.visible = false;
				pSpr.active = false;
				add(pSpr);
				pPool.push(pSpr);
				pStretch.push(0);
				pDrift.push(0);
				pHolding.push(false);
				pAnchor.push(0);
			}
			particles.push(pPool);
			particleStretch.push(pStretch);
			particleDrift.push(pDrift);
			particleHolding.push(pHolding);
			particleAnchorY.push(pAnchor);
		}

		// 右侧 KPS / Total / Max：用单个多行文本，行距收紧（STAT_LINE_GAP），并在按键区内垂直居中
		var textX:Float = keyStartX + totalWidth + BTN_GAP;
		var textW:Float = TEXT_AREA_W - BTN_GAP;
		statsText = new FlxText(textX, 0, textW, 'KPS: 0\nTotal: 0\nMax: 0', 14);
		statsText.setFormat(Paths.font(FONT_NAME), 14, TEXT_COLOR, LEFT);
		statsText.scrollFactor.set(0, 0);
		statsText.y = Math.round(bgY + (keyAreaH - statsText.height) / 2);
		add(statsText);

		// 底部名字：紧贴按键描边正下方（取按键底边），水平居中于背景，并在文本带内垂直居中（兼容多行）
		if (nameText != null)
		{
			var keyBottom:Float = yPos + BTN_SIZE;
			var nameTopY:Float = keyBottom + NAME_TOP_PAD;
			nameText.x = bgX; // 对齐到背景左缘（宽度=bgW 且居中，故文本水平居中于背景）
			nameText.y = Math.round(nameTopY + Math.max(0, (nameBandH - nameText.height) / 2));
			add(nameText);
		}

		// 全部挂到 camOther 相机（覆盖层顶部，位于 HUD 之上）
		for (member in members)
		{
			if (member != null && Std.isOfType(member, FlxSprite))
				member.cameras = [PlayState.instance.camOther];
		}

		startTime = FlxG.game.ticks;
	}

	override public function update(elapsed:Float):Void
	{
		super.update(elapsed);

		var now:Float = FlxG.game.ticks;
		var controls = PlayState.instance.controls;

		for (i in 0...keysArray.length)
		{
			var action:String = keysArray[i];
			var glow = keyGlows[i];

			// 发光层按下强度（0→1 淡入，1→0 淡出），用于平滑动画
			var target:Float = controls.pressed(action) ? 1.0 : 0.0;
			keyPressGlow[i] = FlxMath.lerp(target, keyPressGlow[i], Math.exp(-elapsed * 18));

			// 按键描边：按下立刻切换为橙黄，松开立刻恢复白色（与发光动画不同）
			keyBorders[i].color = controls.pressed(action) ? PRESS_COLOR : BORDER_COLOR;

			// 发光层：圆角橙黄填充，平滑淡入淡出 + 轻微缩放
			glow.alpha = keyPressGlow[i] * GLOW_ALPHA_MAX;
			glow.scale.set(
				FlxMath.lerp(0.85, 1.0, keyPressGlow[i]),
				FlxMath.lerp(0.85, 1.0, keyPressGlow[i]));

			if (controls.justPressed(action))
			{
				keyTimes.push(now);
				totalKeys++;
				saveDirty = true; // Total 变化，待落盘
				spawnTrail(i); // 生成一条从按键顶端向上拉长的轨迹长条
			}

			// 更新该键的所有轨迹粒子
			var pool:Array<FlxSprite> = particles[i];
			var stretch:Array<Float> = particleStretch[i];
			var drift:Array<Float> = particleDrift[i];
			var holding:Array<Bool> = particleHolding[i];
			var anchorY:Array<Float> = particleAnchorY[i];

			for (p in 0...pool.length)
			{
			var spr:FlxSprite = pool[p];
			if (!spr.active) continue;

		if (holding[p])
		{
			if (controls.pressed(action))
			{
				// 按住中：长条从 0 高度向上拉长，到遮罩线(200)即暂停（封顶不再变长）
				stretch[p] = Math.min(FADE_LINE, stretch[p] + VIS_SPEED);
			}
			else
			{
				// 刚松开：转为飘走阶段（整体上飘、淡出回收）
				holding[p] = false;
			}
		}
		else
		{
			// 已松开：整条向上飘走（高度保持，整体飞向遮罩线）
			drift[p] += VIS_SPEED;
			spr.y -= VIS_SPEED;
		}

		// 长条高度完全由 stretch 决定（stretch=0 即最小高度≈0，瞬间点击不产生高块）
		var h:Float = Math.max(1, stretch[p]);
		spr.setGraphicSize(Math.round(BTN_SIZE), Math.round(h));
		spr.updateHitbox();
		if (holding[p])
		{
			// 按住期：底部钉在按键顶端(anchorY)，顶部向上延伸 h
			spr.y = anchorY[p] - h;
			spr.alpha = 1;
		}
		// 飘走阶段：spr.y 已在前面 spr.y -= VIS_SPEED 累积上飘，这里不再重设（否则会被钉回原位）

			// 遮罩线（fade line）：距按键顶端 FADE_LINE 处，白块超出此线的部分被水平裁断
			// 注意：clipRect 使用帧（纹理）坐标，需把屏幕局部差按 scale.y 换算回帧坐标，
			// 否则 setGraphicSize 拉长后坐标单位不一致会导致整条被误裁（瞬间消失）
			var fadeLineY:Float = anchorY[p] - FADE_LINE;
			var lineLocalTex:Float = (fadeLineY - spr.y) / spr.scale.y; // 遮罩线在帧局部坐标系的 y
			if (lineLocalTex <= 0)
			{
				spr.clipRect = null; // 整条都在线以下：完整显示
			}
			else if (lineLocalTex >= spr.frameHeight)
			{
				spr.clipRect = new flixel.math.FlxRect(0, 0, spr.width, 0); // 整条都在线以上：裁掉不可见
			}
			else
			{
				// 只保留遮罩线以下的部分，顶部被裁断
				spr.clipRect = new flixel.math.FlxRect(0, lineLocalTex, spr.width, spr.frameHeight - lineLocalTex);
			}

			// 飘走阶段整体淡出
			if (!holding[p])
				spr.alpha = Math.max(0, spr.alpha - VIS_SPEED / FADE_DIST);

			// 回收：仅飘走阶段，整条越过遮罩线（底部到线以上）或 alpha 归零
			var bottomY:Float = spr.y + spr.height;
			if (!holding[p] && (spr.alpha <= 0.001 || bottomY <= fadeLineY))
			{
				spr.visible = false;
				spr.active = false;
				spr.alpha = 0;
				spr.clipRect = null;
			}
			}
		}

		// 计算 KPS（最近 1 秒内的按键数）
		var cutoff:Float = now - 1000;
		while (keyTimes.length > 0 && keyTimes[0] < cutoff)
			keyTimes.shift();

		var currentKps:Int = keyTimes.length;
		if (currentKps > maxKps)
			maxKps = currentKps;

		if (statsText != null)
			statsText.text = 'KPS: ' + currentKps + '\nTotal: ' + totalKeys + '\nMax: ' + maxKps;

		// 节流落盘：Total 变化后至少每 1 秒写一次，避免每次按键都刷盘
		if (saveDirty && now - lastSaveAt > 1000)
			flushTotal();
	}

	// 将累计 Total 写入持久存档（ClientPrefs 会自动保存）
	function flushTotal():Void
	{
		if (ClientPrefs.data.keyViewerTotal != totalKeys)
		{
			ClientPrefs.data.keyViewerTotal = totalKeys;
			ClientPrefs.saveSettings();
		}
		saveDirty = false;
		lastSaveAt = FlxG.game.ticks;
	}

	override function destroy():Void
	{
		// 销毁前兜底保存，防止漏掉最后一秒内的按键
		if (saveDirty)
			flushTotal();
		super.destroy();
	}

	/**
	 * 在第 i 个键顶部生成一条轨迹粒子（按键轨迹可视化）。
	 * 从粒子池中取一个未激活的，重置位置/透明度/进度后激活。
	 */
	function spawnTrail(i:Int):Void
	{
		var pool:Array<FlxSprite> = particles[i];
		var stretch:Array<Float> = particleStretch[i];
		var drift:Array<Float> = particleDrift[i];
		var holding:Array<Bool> = particleHolding[i];
		var anchorY:Array<Float> = particleAnchorY[i];

		// 快速连按：先把该键仍在"按住"状态的上一条转成飘走，避免多条长条根部重叠
		for (q in 0...pool.length)
		{
			if (pool[q].active && holding[q])
				holding[q] = false;
		}

		for (p in 0...pool.length)
		{
			if (!pool[p].active)
			{
				var spr:FlxSprite = pool[p];
			var btn:FlxSprite = keyCaps[i];
			var pW:Float = BTN_SIZE; // 轨迹条宽度跟随按键（描边）宽度
				// 底部锚定在按键顶端（含生成偏移），长条将由此向上延伸
				anchorY[p] = btn.y + VIS_SPAWN_Y;
				spr.x = btn.x + (BTN_SIZE - pW) / 2;
				spr.setGraphicSize(Math.round(pW), Math.round(PARTICLE_H));
				spr.updateHitbox();
				spr.y = anchorY[p] - PARTICLE_H; // 初始为单块高度
				spr.alpha = 1;
				spr.clipRect = null;
				spr.visible = true;
				spr.active = true;
				stretch[p] = 0;
				drift[p] = 0;
				holding[p] = true;
				return;
			}
		}
		// 池满则忽略（同时按下超过 POOL_PER_KEY 条轨迹时）
	}

	/**
	 * 将 action 名转换为可读物理按键名。
	 * 从 Controls 的 keyboardBinds 取第一个绑定键。
	 */
	function getKeyName(action:String):String
	{
		var binds = PlayState.instance.controls.keyboardBinds.get(action);
		if (binds == null || binds.length == 0)
			return convertActionName(action);

		var key:FlxKey = binds[0];
		var name:String = key.toString();
		// 修正常见按键显示
		switch (name)
		{
			case 'LEFT': return '←';
			case 'RIGHT': return '→';
			case 'UP': return '↑';
			case 'DOWN': return '↓';
			case 'SPACE': return 'SPACE';
			case 'ENTER': return 'ENTER';
			case 'SHIFT': return 'SHIFT';
			case 'LSHIFT': return 'L-SHIFT';
			case 'RSHIFT': return 'R-SHIFT';
			case 'CAPSLOCK': return 'CAPS';
			case 'BACKSPACE': return 'BACK';
			case 'ESCAPE': return 'ESC';
			case 'TAB': return 'TAB';
			case 'CTRL': return 'CTRL';
			case 'LCTRL': return 'L-CTRL';
			case 'RCTRL': return 'R-CTRL';
			case 'ALT': return 'ALT';
			case 'LALT': return 'L-ALT';
			case 'RALT': return 'R-ALT';
			case 'SEMICOLON': return ';';
			case 'COMMA': return ',';
			case 'PERIOD': return '.';
			case 'SLASH': return '/';
			case 'BACKSLASH': return '\\';
			case 'QUOTE': return '\'';
			case 'LBRACKET': return '[';
			case 'RBRACKET': return ']';
			case 'MINUS': return '-';
			case 'PLUS': return '=';
			default:
				// 单字符按键（A-Z, 0-9）原样返回
				if (name.length == 1) return name.toUpperCase();
				return name.toUpperCase();
		}
	}

	/**
	 * 当 action 没有键盘绑定时（如纯手柄），回退用 action 名首字母。
	 */
	function convertActionName(action:String):String
	{
		if (action.startsWith('note_'))
			return action.substr(5, 1).toUpperCase();
		return action.substr(0, 1).toUpperCase();
	}

	/**
	 * 查找左侧自定义图标（images/keyViewer/icon.png，兼容全小写目录名）。
	 * 找不到时返回 null，此时左侧空缺会被收起。
	 */
	function findIconKey():String
	{
		for (key in ICON_KEYS)
			if (Paths.fileExists('images/$key.png', IMAGE))
				return key;
		return null;
	}

	/**
	 * 把源位图等比缩放绘制到 w×h，并做圆角裁剪（超出圆角的部分 alpha 置 0）。
	 * 实现：先按目标尺寸平滑重绘，再用一张圆角遮罩的 alpha 通道覆盖结果 alpha。
	 */
	function makeRoundedBitmap(src:BitmapData, w:Int, h:Int, radius:Float):BitmapData
	{
		// 防御：源位图无效或目标尺寸不合法时，直接返回空白，避免 Cairo 段错误
		if (src == null || src.width <= 0 || src.height <= 0 || w <= 0 || h <= 0)
			return new BitmapData(Std.int(Math.max(1, w)), Std.int(Math.max(1, h)), true, 0x00000000);

		w = Std.int(Math.max(1, w));
		h = Std.int(Math.max(1, h));

		var out = new BitmapData(w, h, true, 0x00000000);
		var mtx = new Matrix();
		mtx.scale(w / src.width, h / src.height);
		out.draw(src, mtx, null, null, null, true);

		// 圆角遮罩：圆角内 alpha=255，圆角外 alpha=0
		// 注意：Cairo 在圆角半径超过矩形一半时会崩溃，这里把半径钳制到安全范围
		var r:Float = Math.min(radius, Math.min(w, h) / 2 - 0.5);
		if (r < 0) r = 0;
		var mask = new BitmapData(w, h, true, 0x00000000);
		var shape = new Shape();
		var g = shape.graphics;
		g.beginFill(0xFFFFFF, 1);
		g.drawRoundRect(0, 0, w, h, r * 2, r * 2);
		g.endFill();
		mask.draw(shape, null, null, null, null, true);

		out.copyChannel(mask, new Rectangle(0, 0, w, h), new Point(0, 0), BitmapDataChannel.ALPHA, BitmapDataChannel.ALPHA);
		mask.dispose();
		return out;
	}

	/**
	 * 取底部显示的自定义名字：
	 * 优先 ClientPrefs.keyViewerName，其次 images/keyViewer/name.txt，最后回退默认名。
	 */
	function getProfileName():String
	{
		var name:String = ClientPrefs.data.keyViewerName;
		if (name != null) name = name.trim();

		if (name == null || name.length == 0)
		{
			for (file in NAME_FILES)
			{
				var txt:String = Paths.getTextFromFile(file);
				if (txt != null)
				{
					txt = txt.trim();
					if (txt.length > 0)
					{
						// 支持多行：保留换行（背景高度会随行数自适应）
						name = ~/(\r\n|\r)/g.replace(txt, '\n');
						break;
					}
				}
			}
		}

		if (name == null || name.length == 0) name = DEFAULT_NAME;
		return name;
	}

	/**
	 * 用矢量绘制一个圆角矩形 sprite：填充 fill 色，并以 thickness 像素的 stroke 色描边。
	 * 用于背景面板等需要圆角+描边的元素。
	 */
	function makeRoundRect(w:Int, h:Int, fill:FlxColor, thickness:Int, stroke:FlxColor, radius:Float):FlxSprite
	{
		var bd = new BitmapData(w, h, true, 0x00000000);
		var shape = new Shape();
		var g = shape.graphics;
		if (thickness > 0)
			g.lineStyle(thickness, stroke, 1);
		g.beginFill(fill, 1);
		g.drawRoundRect(thickness / 2, thickness / 2, w - thickness, h - thickness, radius, radius);
		g.endFill();
		bd.draw(shape);

		var spr = new FlxSprite();
		spr.loadGraphic(bd);
		return spr;
	}
}

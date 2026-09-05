/*
 * Copyright (C) 2025 Mobile Porting Team
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

package mobile.substates;

import flixel.FlxObject;
import flixel.FlxSprite;
import mobile.backend.TouchUtil;
import flixel.input.touch.FlxTouch;
import flixel.ui.FlxButton as UIButton;
import objects.CheckboxThingie;

class MobileControlSelectSubState extends MusicBeatSubstate
{
	var options:Array<String> = ['Pad-Right', 'Pad-Left', 'Pad-Custom', 'Hitbox', 'Pad-Both'];
	var control:MobileControls;
	var leftArrow:FlxSprite;
	var rightArrow:FlxSprite;
	var itemText:FlxText;
	var positionText:FlxText;
	var positionTextBg:FlxSprite;
	var bg:FlxSprite;
	var ui:FlxCamera;
	var curOption:Int = MobileData.mode;
	var buttonBinded:Bool = false;
	var bindButton:TouchButton;
	var reset:UIButton;
	var tweenieShit:Float = 0;

	// 按钮吸附复选框
	var snapCheckbox:CheckboxThingie;
	var snapLabel:FlxText;

	// Hitbox 预览：进入时“渐显→保持→0.4s 后渐隐”的指示效果
	var hitboxTweenList:Map<TouchButton, Array<FlxTween>> = new Map();
	var hitboxWrappedButtons:Map<TouchButton, Bool> = new Map();

	public function new()
	{
		super();
		if (Std.parseInt(ClientPrefs.data.extraButtons) > 0)
			options.push('Pad-Extra');

		// 简单的变暗背景效果
		bg = new FlxSprite(0, 0);
		bg.makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		bg.alpha = 0;
		FlxTween.tween(bg, {alpha: 0.6}, 0.3, {
			ease: FlxEase.quadOut,
			onComplete: (twn:FlxTween) ->
			{
				FlxTween.tween(ui, {alpha: 1}, 0.2, {ease: FlxEase.circOut});
			}
		});
		add(bg);

		FlxG.mouse.visible = !FlxG.onMobile;

		ui = new FlxCamera();
		ui.bgColor.alpha = 0;
		ui.alpha = 0;
		FlxG.cameras.add(ui, false);

		itemText = new FlxText(0, 60, 0, '', 42);
		itemText.setFormat(Paths.font(Language.get('uitab_font')), 42, FlxColor.WHITE, FlxTextAlign.LEFT);
		itemText.cameras = [ui];
		add(itemText);

		leftArrow = new FlxSprite(0, itemText.y - 25);
		leftArrow.frames = Paths.getSparrowAtlas('campaign_menu_UI_assets');
		leftArrow.animation.addByPrefix('idle', 'arrow left');
		leftArrow.animation.addByPrefix('press', "arrow push left");
		leftArrow.animation.play('idle');
		leftArrow.cameras = [ui];
		add(leftArrow);

		itemText.x = leftArrow.width + 70;
		leftArrow.x = itemText.x - 60;

		rightArrow = new FlxSprite().loadGraphicFromSprite(leftArrow);
		rightArrow.flipX = true;
		rightArrow.setPosition(itemText.x + itemText.width + 10, itemText.y - 25);
		rightArrow.cameras = [ui];
		add(rightArrow);

		positionText = new FlxText(0, FlxG.height, FlxG.width / 4, '');
		positionText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, FlxTextAlign.LEFT);
		positionText.visible = false;

		positionTextBg = new FlxSprite(0, FlxG.height - 150);
		positionTextBg.makeGraphic(250, 150, FlxColor.BLACK);
		positionTextBg.visible = false;
		positionTextBg.alpha = 0.8;
		add(positionTextBg);
		positionText.cameras = [ui];
		add(positionText);

		var saveBtn = createTopRightButton(itemText.y - 25, Language.get('key_bind_save'), FlxColor.LIME, () ->
		{
			// 保存当前选中的模式与自定义位置，但不退出
			if (options[curOption].toLowerCase().contains('pad'))
				control.touchPad.setExtrasDefaultPos();
			if (options[curOption] == 'Pad-Extra')
			{
				showToast(Language.get('pad_extra_save'));
				return;
			}
			MobileData.mode = curOption;
			if (options[curOption] == 'Pad-Custom')
				MobileData.setTouchPadCustom(control.touchPad);
			FlxG.sound.play(Paths.sound('confirmMenu'));
			showToast(Language.get('mobile_controls_saved'));
		});
		add(saveBtn);

		// 直接关闭，不保存
		var exitBtn = createTopRightButton(saveBtn.y + saveBtn.height + 20, Language.get('mobile_btn_exit'), FlxColor.ORANGE, () ->
		{
			controls.isInSubstate = FlxG.mouse.visible = false;
			FlxG.sound.play(Paths.sound('cancelMenu'));
			MobileData.forcedMode = null;
			close();
		});
		add(exitBtn);

		reset = createTopRightButton(exitBtn.y + exitBtn.height + 20, Language.get('key_bind_reset'), FlxColor.RED, () ->
		{
			resetToDefaultLayout();
			FlxG.sound.play(Paths.sound('cancelMenu'));
		});
		add(reset);

		// 添加按钮吸附复选框（在屏幕左侧垂直居中附近）
		var centerY = FlxG.height / 2;
		snapCheckbox = new CheckboxThingie(50, centerY, MobileData.buttonSnap);
		snapCheckbox.cameras = [ui];
		snapCheckbox.setGraphicSize(Std.int(snapCheckbox.width) * 0.8);
		snapCheckbox.updateHitbox();
		snapCheckbox.visible = false; // 默认隐藏
		add(snapCheckbox);

		// 添加复选框标签
		snapLabel = new FlxText(snapCheckbox.x + snapCheckbox.width + 20, centerY, 0, Language.get('button_snap'), 40);
		snapLabel.setFormat(Paths.font(Language.get('uitab_font')), 40, FlxColor.WHITE);
		snapLabel.cameras = [ui];
		snapLabel.y += snapCheckbox.height / 2 - snapLabel.height / 2;
		snapLabel.visible = false; // 默认隐藏
		add(snapLabel);

		changeOption(0);
	}

	override function update(elapsed:Float)
	{
		// 检测复选框的触摸（只在复选框可见时）
		if (snapCheckbox.visible && TouchUtil.justPressed)
		{
			for (touch in FlxG.touches.list)
			{
				if (touch.overlaps(snapCheckbox, ui))
				{
					MobileData.buttonSnap = !MobileData.buttonSnap;
					snapCheckbox.daValue = MobileData.buttonSnap;
					FlxG.sound.play(Paths.sound('scrollMenu'));
					break;
				}
			}
		}

		checkArrowButton(leftArrow, () ->
		{
			changeOption(-1);
		});

		checkArrowButton(rightArrow, () ->
		{
			changeOption(1);
		});

		if (options[curOption] == 'Pad-Custom' || options[curOption] == 'Pad-Extra')
		{
			if (buttonBinded)
			{
				// 触摸释放、按钮丢失或触摸点丢失时，结束拖拽
				if (TouchUtil.justReleased || bindButton == null || TouchUtil.touch == null)
				{
					bindButton = null;
					buttonBinded = false;
				}
				else
					moveButton(TouchUtil.touch, bindButton);
			}
			else if (control.touchPad != null)
			{
				control.touchPad.forEachAlive((button:TouchButton) ->
				{
					if (button != null && button.justPressed && TouchUtil.touch != null)
						moveButton(TouchUtil.touch, button);
				});
			}
			// 只有在启用了按钮吸附时才执行吸附逻辑
			if (MobileData.buttonSnap)
			{
				control.touchPad.forEachAlive((button:TouchButton) ->
				{
					if (button != null && button.visible && button != bindButton && buttonBinded)
					{
						bindButton.centerBounds();
						button.bounds.immovable = true;
						bindButton.bounds.immovable = false;
						button.centerBounds();
						FlxG.overlap(bindButton.bounds, button.bounds, function(a:Dynamic, b:Dynamic)
						{ // these args dosen't work fuck them :/
							bindButton.centerInBounds();
							button.centerBounds();
							bindButton.bounds.immovable = true;
							button.bounds.immovable = false;
							// trace('button${bindButton.tag} & button${button.tag} collided');
						}, function(a:Dynamic, b:Dynamic)
						{
							if (!bindButton.bounds.immovable)
							{
								if (bindButton.bounds.x > button.bounds.x)
									bindButton.bounds.x = button.bounds.x + button.bounds.width;
								else
									bindButton.bounds.x = button.bounds.x - button.bounds.width;

								if (bindButton.bounds.y > button.bounds.y)
									bindButton.bounds.y = button.bounds.y + button.bounds.height;
								else if (bindButton.bounds.y != button.bounds.y)
									bindButton.bounds.y = button.bounds.y - button.bounds.height;
							}
							return true;
						});
						/*FlxG.collide(bindButton.bounds, button.bounds, function(a:Dynamic, b:Dynamic) { // these args dosen't work fuck them :/
							bindButton.centerInBounds();
							button.centerBounds();
							bindButton.bounds.immovable = true;
							button.bounds.immovable = false;
							trace('button${bindButton.tag} & button${button.tag} collided');
						});*/
					}
				});
			}
		}

		tweenieShit += 180 * elapsed;

		super.update(elapsed);
	}

	function changeControls(?type:Int, ?extraMode:Bool = false)
	{
		if (type == null)
			type = curOption;
		if (control != null)
			control.destroy();
		if (members.contains(control))
			remove(control);
		control = new MobileControls(type, extraMode);
		// 让控制层插在变暗背景之后、所有 UI（箭头/退出/复位/吸附复选框）之前，
		// 保证虚拟键/Hitbox 不会覆盖到顶部的 UI 层。
		insert(1, control);
		control.cameras = [ui];
	}

	function changeOption(change:Int)
	{
		FlxG.sound.play(Paths.sound('scrollMenu'));
		clearHitboxIndication();
		curOption += change;

		if (curOption < 0)
			curOption = options.length - 1;
		if (curOption >= options.length)
			curOption = 0;

		switch (options[curOption])
		{
			case 'Pad-Right' | 'Pad-Left' | 'Pad-Both':
				reset.visible = false;
				snapCheckbox.visible = false;
				snapLabel.visible = false;
				changeControls();
			case 'Hitbox':
				reset.visible = false;
				snapCheckbox.visible = false;
				snapLabel.visible = false;
				changeControls();
				indicateHitboxPreview();
			case 'Pad-Custom':
				reset.visible = true;
				snapCheckbox.visible = true;
				snapLabel.visible = true;
				changeControls();
			case 'Pad-Extra':
				reset.visible = true;
				snapCheckbox.visible = true;
				snapLabel.visible = true;
				changeControls(0, true);
				control.touchPad.forEachAlive((button:TouchButton) ->
				{
					// 预览只展示 S/G/T/P 四个额外键，隐藏方向键（方向键 tag 为 UP/LEFT/RIGHT/DOWN）
					var hideTags = ['UP', 'LEFT', 'RIGHT', 'DOWN'];
					if (hideTags.contains(button.tag.toUpperCase()))
						button.visible = button.active = false;
				});
		}
		updatePosText();
		setOptionText();
	}

	// 将当前可定制 Pad 的按钮位置清回默认布局（丢弃上次保存的自定义位置）
	function resetToDefaultLayout():Void
	{
		if (options[curOption] == 'Pad-Custom')
		{
			MobileData.save.data.buttons = null;
			MobileData.save.flush();
		}
		else if (options[curOption] == 'Pad-Extra')
		{
			MobileData.save.data.extraData = null;
			MobileData.save.flush();
		}
		changeOption(0); // 重建当前 pad，恢复默认布局
	}

	// 生成一个右上角样式统一的按钮
	function createTopRightButton(y:Float, label:String, color:FlxColor, onClick:Void->Void):UIButton
	{
		var btn = new UIButton(0, y, label, onClick);
		btn.color = color;
		btn.setGraphicSize(Std.int(btn.width) * 3);
		btn.updateHitbox();
		btn.x = FlxG.width - btn.width - 70;
		btn.label.setFormat(Paths.font(Language.get('uitab_font')), 36, FlxColor.WHITE, FlxTextAlign.CENTER);
		btn.label.fieldWidth = btn.width;
		btn.label.x = ((btn.width - btn.label.width) / 2) + btn.x;
		btn.label.offset.y = -10;
		btn.cameras = [ui];
		return btn;
	}

	// 在屏幕中央弹出一条短暂存盘/提示信息
	function showToast(text:String):Void
	{
		var toast = new FlxText(0, 0, FlxG.width / 2, text);
		toast.setFormat(Paths.font(Language.get('uitab_font')), 32, FlxColor.WHITE, FlxTextAlign.CENTER);
		toast.cameras = [ui];
		toast.screenCenter();
		add(toast);
		FlxTween.tween(toast, {alpha: 0}, 3.4, {
			ease: FlxEase.circOut,
			onComplete: (twn:FlxTween) ->
			{
				toast.destroy();
				remove(toast);
			}
		});
	}

	// 将标题行（左箭头 + 模式名 + 右箭头）整体水平居中
	function centerTitle():Void
	{
		itemText.updateHitbox();
		var arrowW:Float = rightArrow.width;
		var gapL:Float = 60; // leftArrow 到 itemText 的左间距
		var gapR:Float = 10; // itemText 到 rightArrow 的右间距
		var groupW:Float = itemText.width + arrowW + gapL + gapR;
		var leftmost:Float = (FlxG.width - groupW) / 2;
		itemText.x = leftmost + gapL;
		leftArrow.x = itemText.x - gapL;
		rightArrow.x = itemText.x + itemText.width + gapR;
	}

	function setOptionText()
	{
		itemText.text = localModeName(options[curOption]);
		centerTitle();
	}

	// Hitbox 预览指示：读取设置里的移动端按键不透明度，进入时“渐显→保持 0.4s→渐隐”。
	// 期间单个块可被触摸逻辑打断（触摸后交给 hitbox 自身的高亮/状态逻辑处理）。
	function indicateHitboxPreview():Void
	{
		if (control == null || control.hitbox == null)
			return;

		var target:Float = ClientPrefs.data.controlsAlpha;
		var hideIdle:Bool = ClientPrefs.data.hitboxHideIdle;
		var idleA:Float = hideIdle ? 0 : 0.00001;
		// 底部条条与“HitBox 隐藏待机”绑定：禁用时始终不显示，启用时随 hitbox 一起渐显并兼容触摸（触摸细节交给 hitbox 自身逻辑）
		var labelVisible:Bool = hideIdle;

		// 额外键区块在预览中稳定显示，方便查看额外按键数量与位置，不做“渐显→渐隐”
		var extras:Array<TouchButton> = [
			control.hitbox.buttonExtra,
			control.hitbox.buttonExtra2,
			control.hitbox.buttonExtra3,
			control.hitbox.buttonExtra4
		];

		control.hitbox.forEachAlive((button:TouchButton) ->
		{
			if (button == null)
				return;

			if (extras.contains(button))
			{
				button.alpha = target;
				if (button.label != null)
					button.label.alpha = labelVisible ? target : 0;
				return;
			}

			cancelHitboxIndicate(button);

			button.alpha = idleA;
			var tweens:Array<FlxTween> = [];
			// 渐显到设置的不透明度
			tweens.push(FlxTween.tween(button, {alpha: target}, 0.2, {ease: FlxEase.quadOut}));
			// 保持 0.4s 后渐隐回隐藏状态
			tweens.push(FlxTween.tween(button, {alpha: idleA}, 0.3, {ease: FlxEase.quadIn, startDelay: 0.4}));

			if (button.label != null)
			{
				if (labelVisible)
				{
					button.label.alpha = 0;
					tweens.push(FlxTween.tween(button.label, {alpha: target}, 0.2, {ease: FlxEase.quadOut}));
					tweens.push(FlxTween.tween(button.label, {alpha: 0}, 0.3, {ease: FlxEase.quadIn, startDelay: 0.4}));
				}
				else
					button.label.alpha = 0; // 禁用隐藏待机时，条条始终不显示
			}

			hitboxTweenList.set(button, tweens);
			wrapHitboxInterrupt(button);
		});
	}

	function cancelHitboxIndicate(button:TouchButton):Void
	{
		if (button == null || !hitboxTweenList.exists(button))
			return;
		var tweens:Array<FlxTween> = hitboxTweenList.get(button);
		for (tween in tweens)
			if (tween != null && tween.active)
				tween.cancel();
		hitboxTweenList.remove(button);
	}

	function clearHitboxIndication():Void
	{
		var buttons:Array<TouchButton> = [for (b in hitboxTweenList.keys()) b];
		for (b in buttons)
			cancelHitboxIndicate(b);
		hitboxWrappedButtons.clear();
	}

	function wrapHitboxInterrupt(button:TouchButton):Void
	{
		if (button == null || hitboxWrappedButtons.exists(button))
			return;
		hitboxWrappedButtons.set(button, true);
		var orig:Void->Void = button.onDown.callback;
		button.onDown.callback = function()
		{
			// 触摸打断指示渐隐，交给 hitbox 自身的高亮逻辑处理
			cancelHitboxIndicate(button);
			if (orig != null)
				orig();
		};
	}

	override function destroy():Void
	{
		clearHitboxIndication();
		super.destroy();
	}

	// 本地化触控模式名（存储值不变，仅显示翻译）
	function localModeName(name:String):String
	{
		return switch (name)
		{
			case 'Pad-Right': Language.get('mobile_mode_pad_right');
			case 'Pad-Left': Language.get('mobile_mode_pad_left');
			case 'Pad-Custom': Language.get('mobile_mode_pad_custom');
			case 'Pad-Extra': Language.get('mobile_mode_pad_extra');
			case 'Pad-Both': Language.get('mobile_mode_pad_both');
			case 'Hitbox': Language.get('mobile_mode_hitbox');
			default: name.replace('-', ' ');
		}
	}

	function updatePosText()
	{
		var optionName = options[curOption];
		if (optionName == 'Pad-Custom' || optionName == 'Pad-Extra')
		{
			positionText.visible = positionTextBg.visible = true;
			if (optionName == 'Pad-Custom')
			{
				positionText.text = '${Language.get('mobilec_left')} X: ${control.touchPad.buttonLeft.x} - Y: ${control.touchPad.buttonLeft.y}\n${Language.get('mobilec_down')} X: ${control.touchPad.buttonDown.x} - Y: ${control.touchPad.buttonDown.y}\n\n${Language.get('mobilec_up')} X: ${control.touchPad.buttonUp.x} - Y: ${control.touchPad.buttonUp.y}\n${Language.get('mobilec_right')} X: ${control.touchPad.buttonRight.x} - Y: ${control.touchPad.buttonRight.y}';
			}
			else
			{
				var pad = control.touchPad;
				positionText.text = '';
				var pairs:Array<Array<Dynamic>> = [
					['S', pad.buttonExtra],
					['G', pad.buttonExtra2],
					['T', pad.buttonExtra3],
					['P', pad.buttonExtra4]
				];
				for (p in pairs)
				{
					if (p[1] != null)
						positionText.text += p[0] + ' X: ' + p[1].x + ' - Y: ' + p[1].y + '\n';
				}
				positionText.text = positionText.text.substr(0, positionText.text.length - 1);
			}
			positionText.setPosition(0, (((positionTextBg.height - positionText.height) / 2) + positionTextBg.y));
		}
		else
			positionText.visible = positionTextBg.visible = false;
	}

	function checkArrowButton(button:FlxSprite, func:Void->Void)
	{
		if (TouchUtil.overlaps(button))
		{
			if (TouchUtil.pressed)
				button.animation.play('press');
			if (TouchUtil.justPressed)
			{
				if (options[curOption] == "Pad-Extra" && control.touchPad != null)
					control.touchPad.setExtrasDefaultPos();
				func();
			}
		}
		if (TouchUtil.justReleased && button.animation.curAnim.name == 'press')
			button.animation.play('idle');
		if (FlxG.keys.justPressed.LEFT && button == leftArrow || FlxG.keys.justPressed.RIGHT && button == rightArrow)
			func();
	}

	function moveButton(touch:FlxTouch, button:TouchButton):Void
	{
		if (touch == null || button == null)
		{
			bindButton = null;
			buttonBinded = false;
			return;
		}

		bindButton = button;
		buttonBinded = true;
		bindButton.x = touch.x - Std.int(bindButton.width / 2);
		bindButton.y = touch.y - Std.int(bindButton.height / 2);
		updatePosText();
	}
}

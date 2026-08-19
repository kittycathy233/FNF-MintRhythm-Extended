package backend.ui;

import backend.Paths;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flxsvg.FlxSvgSprite;
import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import openfl.utils.Assets;

class SvgUIButton extends FlxSpriteGroup
{
    public static final CLICK_EVENT = 'button_click';

    public var name:String;
    public var label(default, set):String;
    public var bg:FlxSvgSprite;
    public var text:FlxText;
    public var onClick:Void->Void;

    var _clickTween:FlxTween;
    var _isPressed:Bool = false;

    public function new(x:Float = 0, y:Float = 0, label:String = '', ?onClick:Void->Void = null, ?wid:Int = 80, ?hei:Int = 20)
    {
        super(x, y);
        
        // 创建SVG背景
        bg = new FlxSvgSprite(0, 0); // 设置初始位置为(0,0)
        bg.loadSvg(Assets.getText("assets/shared/images/svg/button/button1.svg"));
        bg.setGraphicSize(wid, hei);
        bg.updateHitbox();
        add(bg);

        // 创建文本并确保其位于SVG中心
        text = new FlxText(0, 0, wid, label);
        text.size = Std.parseInt(Language.get('button_text_size'));
        text.font = Paths.font(Language.get('uitab_font'));
        text.alignment = CENTER;
        text.borderStyle = OUTLINE;
        text.borderColor = FlxColor.BLACK;
        centerText(); // 居中文本
        add(text);

        this.onClick = onClick;
    }

    // 新增文本居中方法
    private function centerText():Void 
    {
        if (bg != null && text != null) 
        {
            // 确保文本在按钮中心
            text.x = 0;
            text.y = (bg.height - text.height) / 2;
            text.fieldWidth = bg.width;
        }
    }

    public function resize(width:Int, height:Int)
    {
        // 调整SVG背景大小
        bg.setGraphicSize(width, height);
        bg.updateHitbox();
        
        // 重置背景位置
        bg.x = 0;
        bg.y = 0;
        
        // 调整文本大小和位置
        text.fieldWidth = width;
        centerText();
        
        // 更新整个按钮的碰撞区域
        this.width = width;
        this.height = height;
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if(FlxG.mouse.justPressed && isOverlapping())
        {
            _isPressed = true;
            if(_clickTween != null) _clickTween.cancel();
            _clickTween = FlxTween.color(bg, 0.1, FlxColor.WHITE, FlxColor.GRAY, {ease: FlxEase.linear});
        }
        
        if(FlxG.mouse.justReleased && _isPressed)
        {
            _isPressed = false;
            if(_clickTween != null) _clickTween.cancel();
            _clickTween = FlxTween.color(bg, 0.1, FlxColor.GRAY, FlxColor.WHITE, {ease: FlxEase.linear});
            
            if(isOverlapping() && onClick != null)
            {
                onClick();
                PsychUIEventHandler.event(CLICK_EVENT, this);
            }
        }
    }

    private function isOverlapping():Bool
    {
        var mousePos = FlxG.mouse.getPositionInCameraView(camera);
        var screenPos = getScreenPosition(null, camera);
        return mousePos.x >= screenPos.x 
            && mousePos.x <= screenPos.x + width 
            && mousePos.y >= screenPos.y 
            && mousePos.y <= screenPos.y + height;
    }

    function set_label(v:String)
    {
        if(text != null && text.exists) text.text = v;
        return (label = v);
    }
}

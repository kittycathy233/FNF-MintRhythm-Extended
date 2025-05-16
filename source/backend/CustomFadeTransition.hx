package backend;

import flixel.util.FlxGradient;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.FlxSprite;
import openfl.utils.Assets;
import flixel.FlxObject;
import states.MainMenuState;
import sys.FileSystem;
import haxe.io.Path;
import backend.ClientPrefs;

class CustomFadeTransition extends FlxSubState {
    public static var finishCallback: Void -> Void;
    var isTransIn: Bool = false;
    var transBlack: FlxSprite;
    var transGradient: FlxSprite;
    var duration: Float;
    var loadLeft: FlxSprite;
    var loadRight: FlxSprite;
    var loadAlpha: FlxSprite;
    var WaterMark: FlxText;
    var EventText: FlxText;
    var transBG: FlxSprite;
    static var mintRhythmImages:Array<String> = [];
    static var lastRandomIndex:Int = -1;

	var baLoadingPics:FlxSprite;
    var baLoadingPicTween: FlxTween;
    var loadLeftTween: FlxTween;
    var loadRightTween: FlxTween;
    var loadAlphaTween: FlxTween;
    var EventTextTween: FlxTween;
    var loadTextTween: FlxTween;
    public function new(duration: Float, isTransIn: Bool) {
        this.duration = duration;
        this.isTransIn = isTransIn;
        super();
    }
    override function create() {
        
        var cam: FlxCamera = new FlxCamera();
        cam.bgColor = 0x00;
        FlxG.cameras.add(cam, false);
        cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
        
        // 原版
        var width: Int = Std.int(FlxG.width / Math.max(camera.zoom, 0.001));
        var height: Int = Std.int(FlxG.height / Math.max(camera.zoom, 0.001));
        if (ClientPrefs.data.customFadeStyle == 'NovaFlare Move') {
            loadRight = new FlxSprite(isTransIn ? 0 : 1280, 0).loadGraphic(Paths.image('menuExtend/CustomFadeTransition/NF/loadingR'));
            loadRight.scrollFactor.set();
            loadRight.antialiasing = ClientPrefs.data.antialiasing;        
            add(loadRight);
            loadRight.setGraphicSize(FlxG.width, FlxG.height);
            loadRight.updateHitbox();
            
            loadLeft = new FlxSprite(isTransIn ? 0 : -1280, 0).loadGraphic(Paths.image('menuExtend/CustomFadeTransition/NF/loadingL'));
            loadLeft.scrollFactor.set();
            loadLeft.antialiasing = ClientPrefs.data.antialiasing;
            add(loadLeft);
            loadLeft.setGraphicSize(FlxG.width, FlxG.height);
            loadLeft.updateHitbox();
            
            WaterMark = new FlxText(isTransIn ? 50 : -1230, 720 - 50 - 50 * 2, 0, 'MINTRHYTHM EXTENDED V' + MainMenuState.mrExtendVersion, 50);
            WaterMark.scrollFactor.set();
            WaterMark.setFormat(Assets.getFont("assets/fonts/loadText.ttf").fontName, 50, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
            WaterMark.antialiasing = ClientPrefs.data.antialiasing;
            add(WaterMark);
            
            EventText = new FlxText(isTransIn ? 50 : -1230, 720 - 50 - 50, 0, 'LOADING . . . . . . ', 50);
            EventText.scrollFactor.set();
            EventText.setFormat(Assets.getFont("assets/fonts/loadText.ttf").fontName, 50, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
            EventText.antialiasing = ClientPrefs.data.antialiasing;
            add(EventText);
            
            if (!isTransIn) {
                try {
                    FlxG.sound.play(Paths.sound('NFE/loading_close_move')/*,ClientPrefs.data.CustomFadeSound*/);
                } catch (e: Dynamic) {}
                loadLeftTween = FlxTween.tween(loadLeft, {x: 0}, duration, {
                    onComplete: function(twn: FlxTween) {
                        if (finishCallback != null) {
                            finishCallback();
                        }
                    },
                    ease: FlxEase.expoInOut
                });
                loadRightTween = FlxTween.tween(loadRight, {x: 0}, duration, {
                    onComplete: function(twn: FlxTween) {
                        if (finishCallback != null) {
                            finishCallback();
                        }
                    },
                    ease: FlxEase.expoInOut
                });
                loadTextTween = FlxTween.tween(WaterMark, {x: 50}, duration, {
                    onComplete: function(twn: FlxTween) {
                        if (finishCallback != null) {
                            finishCallback();
                        }
                    },
                    ease: FlxEase.expoInOut
                });
                EventTextTween = FlxTween.tween(EventText, {x: 50}, duration, {
                    onComplete: function(twn: FlxTween) {
                        if (finishCallback != null) {
                            finishCallback();
                        }
                    },
                    ease: FlxEase.expoInOut
                });
            } else {
                try {
                    FlxG.sound.play(Paths.sound('NFE/loading_open_move')/*,ClientPrefs.data.CustomFadeSound*/);
                } catch (e: Dynamic) {}
                EventText.text = 'COMPLETED !';
                loadLeftTween = FlxTween.tween(loadLeft, {x: -1280}, duration, {
                    onComplete: function(twn: FlxTween) {
                        close();
                    },
                    ease: FlxEase.expoInOut
                });
                loadRightTween = FlxTween.tween(loadRight, {x: 1280}, duration, {
                    onComplete: function(twn: FlxTween) {
                        close();
                    },
                    ease: FlxEase.expoInOut
                });
                loadTextTween = FlxTween.tween(WaterMark, {x: -1230}, duration, {
                    onComplete: function(twn: FlxTween) {
                        close();
                    },
                    ease: FlxEase.expoInOut
                });
                EventTextTween = FlxTween.tween(EventText, {x: -1230}, duration, {
                    onComplete: function(twn: FlxTween) {
                        close();
                    },
                    ease: FlxEase.expoInOut
                });
            }
        } else if (ClientPrefs.data.customFadeStyle == 'NovaFlare Alpha') {
            loadAlpha = new FlxSprite( 0, 0).loadGraphic(Paths.image('menuExtend/CustomFadeTransition/NF/loadingAlpha'));
            loadAlpha.scrollFactor.set();
            loadAlpha.antialiasing = ClientPrefs.data.antialiasing;		
            add(loadAlpha);
            loadAlpha.setGraphicSize(FlxG.width, FlxG.height);
            loadAlpha.updateHitbox();
            
            WaterMark = new FlxText( 50, 720 - 50 - 50 * 2, 0, 'MINTRHYTHM ENGINE V' + MainMenuState.mrExtendVersion, 50);
            WaterMark.scrollFactor.set();
            WaterMark.setFormat(Assets.getFont("assets/fonts/loadText.ttf").fontName, 50, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
            WaterMark.antialiasing = ClientPrefs.data.antialiasing;
            add(WaterMark);
            
            EventText= new FlxText( 50, 720 - 50 - 50, 0, 'LOADING . . . . . . ', 50);
            EventText.scrollFactor.set();
            EventText.setFormat(Assets.getFont("assets/fonts/loadText.ttf").fontName, 50, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
            EventText.antialiasing = ClientPrefs.data.antialiasing;
            add(EventText);
            
            if(!isTransIn) {
                try{
                    FlxG.sound.play(Paths.sound('NFE/loading_close_alpha'));
                }
                WaterMark.alpha = 0;
                EventText.alpha = 0;
                loadAlpha.alpha = 0;
                loadAlphaTween = FlxTween.tween(loadAlpha, {alpha: 1}, duration, {
                    onComplete: function(twn:FlxTween) {
                        if(finishCallback != null) {
                            finishCallback();
                        }
                    },
                ease: FlxEase.sineInOut});
                
                loadTextTween = FlxTween.tween(WaterMark, {alpha: 1}, duration, {
                    onComplete: function(twn:FlxTween) {
                        if(finishCallback != null) {
                            finishCallback();
                        }
                    },
                ease: FlxEase.sineInOut});
                
                EventTextTween = FlxTween.tween(EventText, {alpha: 1}, duration, {
                    onComplete: function(twn:FlxTween) {
                        if(finishCallback != null) {
                            finishCallback();
                        }
                    },
                ease: FlxEase.sineInOut});
                
            } else {
                try{
                    FlxG.sound.play(Paths.sound('NFE/loading_open_alpha'));
                }
                EventText.text = 'COMPLETED !';
                loadAlphaTween = FlxTween.tween(loadAlpha, {alpha: 0}, duration, {
                    onComplete: function(twn:FlxTween) {
                        close();
                    },
                ease: FlxEase.sineInOut});
                
                loadTextTween = FlxTween.tween(WaterMark, {alpha: 0}, duration, {
                    onComplete: function(twn:FlxTween) {
                        close();
                    },
                ease: FlxEase.sineInOut});
                
                EventTextTween = FlxTween.tween(EventText, {alpha: 0}, duration, {
                    onComplete: function(twn:FlxTween) {
                        close();
                    },
                ease: FlxEase.sineInOut});
                
                
                }
            }  else if (ClientPrefs.data.customFadeStyle == 'MintRhythm') {
            // 初始化图片列表（只在第一次加载时）
            
            if (mintRhythmImages.length == 0) {
                var imagePath = Paths.getPath('images/menuExtend/CustomFadeTransition/Blue_Archive/CN/', IMAGE);
                if (FileSystem.exists(imagePath)) {
                    for (file in FileSystem.readDirectory(imagePath)) {
                        if (Path.extension(file).toLowerCase() != 'txt') {
                            mintRhythmImages.push('menuExtend/CustomFadeTransition/Blue_Archive/CN/' + Path.withoutExtension(file));
                        }
                    }
                }
                // 如果没有找到图片则使用默认
                if (mintRhythmImages.length == 0) {
                    mintRhythmImages.push('menuExtend/CustomFadeTransition/Blue_Archive/CN/LoadingImage_44_Kr');
                }
            }

            // 随机选择新图片（确保不重复）
            if (!isTransIn) {
                ClientPrefs.data.randomIndex = FlxG.random.int(0, mintRhythmImages.length - 1, [lastRandomIndex]);
            }
            lastRandomIndex = ClientPrefs.data.randomIndex;

            transBlack = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
            transBlack.setGraphicSize(FlxG.width * 1.2, FlxG.height * 1.2);
            transBlack.updateHitbox();
            transBlack.scrollFactor.set();
            transBlack.screenCenter();
            add(transBlack);

            transBG = new FlxSprite( 0, 0).loadGraphic(Paths.image('menuExtend/CustomFadeTransition/BA/Login_Pad_BG'));
            transBG.updateHitbox();
            transBG.scrollFactor.set();
            transBG.screenCenter();
           // add(transBG);

            // 图片加载（完全按照NovaFlare的方式）
            baLoadingPics = new FlxSprite(0, 0).loadGraphic(Paths.image(mintRhythmImages[ClientPrefs.data.randomIndex]));
            baLoadingPics.scrollFactor.set();
            baLoadingPics.antialiasing = ClientPrefs.data.antialiasing;
            baLoadingPics.screenCenter();
            baLoadingPics.setGraphicSize(Std.int(baLoadingPics.width), Std.int(baLoadingPics.height * 1.18));
            baLoadingPics.y = baLoadingPics.y - 20;
            baLoadingPics.updateHitbox();
            add(baLoadingPics);

            // 透明通道设置
            baLoadingPics.alpha = isTransIn ? 1 : 0;

            // 动画效果（保持和NovaFlare相同的缓动逻辑）
            if (!isTransIn) {
                FlxG.sound.play(Paths.sound('BA/UI_Loading'));
                baLoadingPicTween = FlxTween.tween(baLoadingPics, {alpha: 1}, duration, {
                    onComplete: function(twn:FlxTween) {
                        if (finishCallback != null) finishCallback();
                    },
                    ease: FlxEase.quartOut
                });
            } else {
                FlxG.sound.play(Paths.sound('BA/UI_Login'));
                baLoadingPicTween = FlxTween.tween(baLoadingPics, {alpha: 0}, duration, {
                    onComplete: function(twn:FlxTween) {
                        close();
                    },
                    ease: FlxEase.linear
                });
            }
        } else {
            //原版
            transGradient = FlxGradient.createGradientFlxSprite(1, height, (isTransIn ? [0x0, FlxColor.BLACK] : [FlxColor.BLACK, 0x0]));
            transGradient.scale.x = width;
            transGradient.updateHitbox();
            transGradient.scrollFactor.set();
            transGradient.screenCenter(X);
            add(transGradient);
            transBlack = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
            transBlack.scale.set(width, height + 400);
            transBlack.updateHitbox();
            transBlack.scrollFactor.set();
            transBlack.screenCenter(X);
            add(transBlack);
            if (isTransIn)
                transGradient.y = transBlack.y - transBlack.height;
            else
                transGradient.y = -transGradient.height;
        }

        super.create();
    }
    override function update(elapsed: Float) {
        if (ClientPrefs.data.customFadeStyle == 'Vanilla') {
            super.update(elapsed);
            final height: Float = FlxG.height * Math.max(camera.zoom, 0.001);
            final targetPos: Float = transGradient.height + 50 * Math.max(camera.zoom, 0.001);
            if (duration > 0)
                transGradient.y += (height + targetPos) * elapsed / duration;
            else
                transGradient.y = (targetPos) * elapsed;
            if (isTransIn)
                transBlack.y = transGradient.y + transGradient.height;
            else
                transBlack.y = transGradient.y - transBlack.height;
            if (transGradient.y >= targetPos) {
                close();
                if (finishCallback != null) finishCallback();
                finishCallback = null;
            }
        } else if (ClientPrefs.data.customFadeStyle == 'MintRhythm') {
            transBlack.alpha = baLoadingPics.alpha;
           // transBG.alpha = baLoadingPics.alpha;
           /* if (baLoadingPics.alpha <= 0) {
                close();
                if (finishCallback != null) finishCallback();
                finishCallback = null;
            }
*/
			/*//还没改
            super.update(elapsed);
            final height: Float = FlxG.height * Math.max(camera.zoom, 0.001);
            final targetPos: Float = transGradient.height + 50 * Math.max(camera.zoom, 0.001);
            if (duration > 0)
                transGradient.y += (height + targetPos) * elapsed / duration;
            else
                transGradient.y = (targetPos) * elapsed;
            if (isTransIn)
                transBlack.y = transGradient.y + transGradient.height;
            else
                transBlack.y = transGradient.y - transBlack.height;
            if (transGradient.y >= targetPos) {
                close();
                if (finishCallback != null) finishCallback();
                finishCallback = null;
            }*/
        }
    }
}
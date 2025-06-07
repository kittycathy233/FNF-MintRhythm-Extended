package backend;

import flixel.input.keyboard.FlxKey;

class ExtraKeysHandler {
    public static var instance:ExtraKeysHandler;

    public var data:ExtraKeysData;

    public function new() {
        reloadExtraKeys();
    }

    public function reloadExtraKeys() {
        trace('Loading Extra Keys data...');

        var parser = new json2object.JsonParser<ExtraKeysData>();
        var dataPath:String = 'data/extrakeys.json';
        var dataText:String = Paths.getTextFromFile(dataPath);
		parser.fromJson(dataText);
		data = parser.value;

        trace('Load complete.');
    }
}

class ExtraKeysData {
    // indexing
    public var keys:Array<EKManiaMode>;

    // these are only used to set the colors into your save data!
    public var colors:Array<EKNoteColor>;
    public var pixelNoteColors:Array<EKNoteColor>;

    public var animations:Array<EKAnimation>;
    public var maxKeys:Int;
    public var minKeys:Int;

    // these are used to set your keybinds into your save data!
    // also used when you click the Default Reset button
    public var keybinds:Array<Array<Array<Int>>>;

    // I said i wouldnt, but here it is! Anyway...
    public var scales:Array<Float>;

    // I also said this wouldnt be here
    public var pixelScales:Array<Float>;
}

class EKManiaMode {
    // 4k = 0,1,2,3
    public var notes:Array<Int>;
}

class EKNoteColor {
    public var inner:String;
    public var border:String;
    public var outline:String;

    public function new(){}
}

class EKAnimation {
    // arrowLEFT
    public var strum:String;

    // left confirm
    public var anim:String;

    // purple hold end
    public var note:String;

    // singLEFT
    public var sing:String;

    // 0
    public var pixel:Int;
}
package states;

/**
 * 剧情播放器 / 编辑器共用的数据结构。
 *
 *   StoryCharDef  角色定义（引用 Spine 的 atlas / skeleton，以及站位、缩放等）
 *   StoryLine     一句台词
 *   StoryFile     整个剧情文件
 *
 * 角色与台词都通过 JSON 描述；编辑器保存时会把这些定义写进同一个 JSON，
 * 并把引用的 Spine 资源（atlas / skeleton / 贴图）复制到 JSON 同级的
 * `<文件名>_assets/` 目录，使剧情可随文件一起分发（"保存要附带"）。
 */
typedef StoryCharDef =
{
	id:String,
	?name:String,
	?affiliation:String, // 所属（如 "联邦学生会"）
	atlasPath:String,
	skeletonPath:String,
	?x:Float,            // 屏幕归一化 x（0..1）
	?y:Float,            // 屏幕归一化 y（0..1）
	?scale:Float,
	?flipX:Bool,
	?skin:String,
	?defaultAnim:String
}

typedef StoryLine =
{
	?character:String,   // 引用 StoryCharDef.id；留空 / null 表示旁白
	?name:String,        // 覆盖角色名（可选）
	?affiliation:String, // 覆盖所属（可选）
	?expression:String,  // 该句使用的 Spine 动画
	?text:String,
	?boxState:String,    // 'normal' | 'angry'
	?speed:Float,        // 打字机每字间隔（秒）
	?sound:String        // 打字音效
}

typedef StoryFile =
{
	?background:String, // 颜色 '#1a1a24' / '0x...' 或图片路径
	?music:String,      // 背景音乐（Paths.music 名称）
	?characters:Array<StoryCharDef>,
	lines:Array<StoryLine>
}

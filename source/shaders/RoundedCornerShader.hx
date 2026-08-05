package shaders;

import flixel.system.FlxAssets.FlxShader;

/**
 * 圆角裁剪 shader：在 GPU 上按 UV 计算圆角矩形 SDF，将圆角外的像素 alpha 置 0。
 * 适用于无法预渲染位图的动画精灵（gif / 精灵图集），与静态 png 的 makeRoundedBitmap 圆角效果一致。
 *
 * 用法：
 *   sprite.shader = new RoundedCornerShader();
 *   sprite.shader.uSize.value = [渲染宽, 渲染高];   // 显示尺寸（像素）
 *   sprite.shader.uRadius.value = [圆角半径];
 */
class RoundedCornerShader extends FlxShader
{
	@:glFragmentSource('
		varying float openfl_Alphav;
		varying vec4 openfl_ColorMultiplierv;
		varying vec4 openfl_ColorOffsetv;
		varying vec2 openfl_TextureCoordv;

		uniform bool openfl_HasColorTransform;
		uniform vec2 openfl_TextureSize;
		uniform sampler2D bitmap;

		uniform bool hasTransform;
		uniform bool hasColorTransform;

		vec4 flixel_texture2D(sampler2D bitmap, vec2 coord)
		{
			vec4 color = texture2D(bitmap, coord);
			if (!hasTransform)
			{
				return color;
			}

			if (color.a == 0.0)
			{
				return vec4(0.0, 0.0, 0.0, 0.0);
			}

			if (!hasColorTransform)
			{
				return color * openfl_Alphav;
			}

			color = vec4(color.rgb / color.a, color.a);

			mat4 colorMultiplier = mat4(0);
			colorMultiplier[0][0] = openfl_ColorMultiplierv.x;
			colorMultiplier[1][1] = openfl_ColorMultiplierv.y;
			colorMultiplier[2][2] = openfl_ColorMultiplierv.z;
			colorMultiplier[3][3] = openfl_ColorMultiplierv.w;

			color = clamp(openfl_ColorOffsetv + (color * colorMultiplier), 0.0, 1.0);

			if (color.a > 0.0)
			{
				return vec4(color.rgb * color.a * openfl_Alphav, color.a * openfl_Alphav);
			}
			return vec4(0.0, 0.0, 0.0, 0.0);
		}

		uniform vec2 uSize;
		uniform float uRadius;

		float roundedBoxSDF(vec2 p, vec2 halfSize, float r)
		{
			r = min(r, min(halfSize.x, halfSize.y));
			vec2 q = abs(p) - halfSize + vec2(r);
			return min(max(q.x, q.y), 0.0) + length(max(q, vec2(0.0))) - r;
		}

		void main()
		{
			vec4 color = flixel_texture2D(bitmap, openfl_TextureCoordv);

			vec2 uv = openfl_TextureCoordv;
			vec2 p = (uv - 0.5) * uSize;
			float d = roundedBoxSDF(p, uSize * 0.5, uRadius);
			float cover = 1.0 - smoothstep(-1.0, 1.0, d);

			color.rgb *= cover;
			color.a *= cover;

			gl_FragColor = color;
		}')
	@:glVertexSource('
		attribute float openfl_Alpha;
		attribute vec4 openfl_ColorMultiplier;
		attribute vec4 openfl_ColorOffset;
		attribute vec4 openfl_Position;
		attribute vec2 openfl_TextureCoord;

		varying float openfl_Alphav;
		varying vec4 openfl_ColorMultiplierv;
		varying vec4 openfl_ColorOffsetv;
		varying vec2 openfl_TextureCoordv;

		uniform mat4 openfl_Matrix;
		uniform bool openfl_HasColorTransform;
		uniform vec2 openfl_TextureSize;

		attribute float alpha;
		attribute vec4 colorMultiplier;
		attribute vec4 colorOffset;
		uniform bool hasColorTransform;

		void main(void)
		{
			openfl_Alphav = openfl_Alpha;
			openfl_TextureCoordv = openfl_TextureCoord;

			if (openfl_HasColorTransform) {
				openfl_ColorMultiplierv = openfl_ColorMultiplier;
				openfl_ColorOffsetv = openfl_ColorOffset / 255.0;
			}

			gl_Position = openfl_Matrix * openfl_Position;

			openfl_Alphav = openfl_Alpha * alpha;
			if (hasColorTransform)
			{
				openfl_ColorOffsetv = colorOffset / 255.0;
				openfl_ColorMultiplierv = colorMultiplier;
			}
		}')

	public function new()
	{
		super();
		// 初始化，避免未赋值导致的 GL 警告
		this.uSize.value = [1.0, 1.0];
		this.uRadius.value = [0.0];
	}
}

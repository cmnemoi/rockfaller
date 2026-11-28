/**
 * A PixiJS batch plugin that applies a sprite's color matrix in the batch shader, as the fork's DrawableShader does,
 * instead of a ColorMatrixFilter: a filter draws its sprite into a texture of its own, two render target switches.
 * Each vertex carries the matrix's four rows and its offset, so sprites of different colors still draw in one batch.
 * PixiJS 6.0.2's externs have no BatchPluginFactory: the plugin is built from the PIXI global.
 * @spec html5.h2d.color::color-matrix-in-batch
 */
class ColorMatrixBatch {
	public static inline var PLUGIN = "colorMatrix";
	// Position (2), texture coordinate (2), texture id (1), the matrix's four rows (16) and offset (4).
	static inline var VERTEX_SIZE = 25;
	static inline var ROWS = 4;
	static inline var ROW_LENGTH = 5;
	static inline var OFFSET_COLUMN = 4;

	static inline var VERTEX = "
precision highp float;
attribute vec2 aVertexPosition;
attribute vec2 aTextureCoord;
attribute float aTextureId;
attribute vec4 aRed;
attribute vec4 aGreen;
attribute vec4 aBlue;
attribute vec4 aAlpha;
attribute vec4 aOffset;
uniform mat3 projectionMatrix;
uniform mat3 translationMatrix;
varying vec2 vTextureCoord;
varying float vTextureId;
varying vec4 vRed;
varying vec4 vGreen;
varying vec4 vBlue;
varying vec4 vAlpha;
varying vec4 vOffset;
void main(void) {
	gl_Position = vec4((projectionMatrix * translationMatrix * vec3(aVertexPosition, 1.0)).xy, 0.0, 1.0);
	vTextureCoord = aTextureCoord;
	vTextureId = aTextureId;
	vRed = aRed;
	vGreen = aGreen;
	vBlue = aBlue;
	vAlpha = aAlpha;
	vOffset = aOffset;
}";

	// The texture is premultiplied: the matrix works on straight colors, like the fork's shader. The color is not
	// clamped before the alpha multiplies it: the fork's blending does the same, and the framebuffer clamps.
	static inline var FRAGMENT = "
varying vec2 vTextureCoord;
varying float vTextureId;
varying vec4 vRed;
varying vec4 vGreen;
varying vec4 vBlue;
varying vec4 vAlpha;
varying vec4 vOffset;
uniform sampler2D uSamplers[%count%];
void main(void) {
	vec4 color;
	%forloop%
	if (color.a > 0.0) color.rgb /= color.a;
	vec4 result = vec4(dot(vRed, color), dot(vGreen, color), dot(vBlue, color), dot(vAlpha, color)) + vOffset;
	gl_FragColor = vec4(result.rgb * result.a, result.a);
}";

	static var registered = false;

	/** Before the renderer is made: a renderer makes its plugins when it is created. */
	public static function register() {
		if (registered) return;
		registered = true;
		var pixi:Dynamic = untyped PIXI;
		var plugin:Dynamic = pixi.BatchPluginFactory.create({
			vertex: VERTEX,
			fragment: FRAGMENT,
			geometryClass: geometryClass(pixi),
			vertexSize: VERTEX_SIZE,
		});
		plugin.prototype.packInterleavedGeometry = packInterleavedGeometry;
		pixi.Renderer.registerPlugin(PLUGIN, plugin);
	}

	/** Like PixiJS's BatchGeometry, with the matrix instead of the tint: one interleaved buffer, and its indices. */
	static function geometryClass(pixi:Dynamic):Dynamic {
		return js.Syntax.code("class ColorMatrixGeometry extends {0} {
			constructor(isStatic) {
				super();
				this._buffer = new {1}(null, isStatic, false);
				this._indexBuffer = new {1}(null, isStatic, true);
				this.addAttribute('aVertexPosition', this._buffer, 2, false, {2}.FLOAT)
					.addAttribute('aTextureCoord', this._buffer, 2, false, {2}.FLOAT)
					.addAttribute('aTextureId', this._buffer, 1, true, {2}.FLOAT)
					.addAttribute('aRed', this._buffer, 4, false, {2}.FLOAT)
					.addAttribute('aGreen', this._buffer, 4, false, {2}.FLOAT)
					.addAttribute('aBlue', this._buffer, 4, false, {2}.FLOAT)
					.addAttribute('aAlpha', this._buffer, 4, false, {2}.FLOAT)
					.addAttribute('aOffset', this._buffer, 4, false, {2}.FLOAT)
					.addIndex(this._indexBuffer);
			}
		}", pixi.Geometry, pixi.Buffer, pixi.TYPES);
	}

	/** PixiJS calls it on the plugin (this) for each sprite: writes its 4 vertices and 6 indices. */
	static function packInterleavedGeometry(sprite:Dynamic, attributeBuffer:Dynamic, indexBuffer:js.lib.Uint16Array, attributeIndex:Int, indexIndex:Int) {
		var plugin:Dynamic = js.Lib.nativeThis;
		var floats:js.lib.Float32Array = attributeBuffer.float32View;
		var firstVertex = Std.int(attributeIndex / plugin.vertexSize);
		var vertexData:Array<Float> = sprite.vertexData;
		var uvs:Array<Float> = sprite.uvs;
		var indices:Array<Int> = sprite.indices;
		var textureId:Float = sprite._texture.baseTexture._batchLocation;
		var matrix:Array<Float> = sprite.colorMatrix;
		var coordinate = 0;
		while (coordinate < vertexData.length) {
			floats[attributeIndex++] = vertexData[coordinate];
			floats[attributeIndex++] = vertexData[coordinate + 1];
			floats[attributeIndex++] = uvs[coordinate];
			floats[attributeIndex++] = uvs[coordinate + 1];
			floats[attributeIndex++] = textureId;
			for (row in 0...ROWS)
				for (column in 0...ROWS)
					floats[attributeIndex++] = matrix[row * ROW_LENGTH + column];
			for (row in 0...ROWS)
				floats[attributeIndex++] = matrix[row * ROW_LENGTH + OFFSET_COLUMN];
			coordinate += 2;
		}
		for (index in indices)
			indexBuffer[indexIndex++] = firstVertex + index;
	}
}

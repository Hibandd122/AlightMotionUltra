#version 100

attribute vec4 position;
attribute vec2 texcoord;
uniform mat4 texTransform;
varying vec2 st;

void main() {
	gl_Position = position;
	st = (vec4(texcoord.xy, 0, 1) * texTransform).xy;
}

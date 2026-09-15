#version 100

attribute vec4 position;
attribute vec2 texcoord;
varying vec2 st;

void main() {
	gl_Position = position;
	st = texcoord;
}

#version 100

attribute vec4 position;
uniform mat4 transform;

void main() {
	gl_Position = position * transform;
}

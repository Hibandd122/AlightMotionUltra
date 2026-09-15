#version 100

attribute vec4 position;
attribute float pointSize;
uniform mat4 transform;

void main() {
	gl_Position = position * transform;
	gl_PointSize = pointSize;
}

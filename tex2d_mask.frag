#version 100

precision mediump float;
uniform sampler2D texture;
uniform vec4 color;
varying vec2 st;

void main() {
    vec4 texColor = texture2D(texture,st);
    gl_FragColor = color * texColor.a;
}

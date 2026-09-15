#version 100

precision mediump float;
uniform sampler2D texture;
uniform float alpha;
varying vec2 st;

void main() {
    gl_FragColor = texture2D(texture,st) * alpha;
}

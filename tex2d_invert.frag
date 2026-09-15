#version 100

precision mediump float;
uniform sampler2D texture;
varying vec2 st;

void main() {
    vec4 texColor = texture2D(texture,st);
    gl_FragColor = vec4(1.0-texColor.r, 1.0-texColor.g, 1.0-texColor.b, 1.0);
}

#version 100

precision mediump float;
uniform sampler2D texture;
uniform float alpha;
varying vec2 st;
uniform vec4 color;

void main() {
    vec4 dst = texture2D(texture,st);
    vec4 src = color;
    gl_FragColor = (src*dst.a + dst*(1.0-src.a)*vec4(1.0,1.0,1.0,dst.a)) * alpha;
}

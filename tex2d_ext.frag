#version 100
#extension GL_OES_EGL_image_external : require

precision mediump float;
uniform samplerExternalOES texture;
uniform float alpha;
varying vec2 st;

void main() {
    gl_FragColor = texture2D(texture,st) * alpha;
}

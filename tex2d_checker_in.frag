#version 100

precision mediump float;
uniform sampler2D texture;
uniform float alpha;
varying vec2 st;
uniform vec4 color;
uniform vec4 color_a;
uniform vec4 color_b;
uniform float oneOverCheckSize;

void main() {
    float f = step(mod(floor(gl_FragCoord.x*oneOverCheckSize)+floor(gl_FragCoord.y*oneOverCheckSize),2.0),0.5);
    vec4 checkColor = mix(color_a,color_b,f);
    vec4 dst = texture2D(texture,st);
    vec4 src = color + checkColor*(1.0-color.a);
    gl_FragColor = (src*dst.a + dst*(1.0-src.a)*vec4(1.0,1.0,1.0,dst.a)) * alpha;
}

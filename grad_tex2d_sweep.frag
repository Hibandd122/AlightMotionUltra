#version 100

precision mediump float;
uniform vec4 color_start;
uniform vec4 color_end;
uniform vec2 start;
uniform vec2 end;
varying vec2 st;

void main() {
    vec4 dst = texture2D(texture,st);
    vec2 xy = st - start;
    vec2 zw = end - start;
    float a = atan(xy.x, xy.y);
    float b = atan(zw.x, zw.y);
    float f = mod(((a-b)+6.28),6.28)/6.28;
    vec4 src = mix(color_start,color_end,f);
    gl_FragColor = (src*dst.a + dst*(1.0-src.a)*vec4(1.0,1.0,1.0,dst.a)) * alpha;
}

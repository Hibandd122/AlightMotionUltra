#version 100

precision mediump float;
uniform sampler2D texture;
uniform float alpha;
varying vec2 st;
uniform vec4 color_start;
uniform vec4 color_end;
uniform vec2 start;
uniform vec2 end;

void main() {
    vec4 dst = texture2D(texture,st);
    float f = smoothstep(0.0,1.0,distance(st,start)/distance(end,start));
    vec4 src = mix(color_start,color_end,f);

    gl_FragColor = (src*dst.a + dst*(1.0-src.a)*vec4(1.0,1.0,1.0,dst.a)) * alpha;
}

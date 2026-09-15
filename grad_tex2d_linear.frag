#version 100

precision mediump float;
uniform vec4 color_start;
uniform vec4 color_end;
uniform vec2 start;
uniform vec2 end;
varying vec2 st;
uniform sampler2D texture;
uniform float alpha;

vec2 projectAndClamp(vec2 a, vec2 b) {
    return clamp(dot(a,b)/dot(b,b),0.0,1.0) * b;
}

void main() {
    vec4 dst = texture2D(texture,st);
    vec2 p = projectAndClamp(st-start, end-start)+start;
    float f = smoothstep(0.0,1.0,distance(p,start)/distance(end,start));
    vec4 src = mix(color_start,color_end,f);
    gl_FragColor = (src*dst.a + dst*(1.0-src.a)*vec4(1.0,1.0,1.0,dst.a)) * alpha;
}

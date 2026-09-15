#version 100

precision mediump float;
uniform vec4 color_start;
uniform vec4 color_end;
uniform vec2 start;
uniform vec2 end;
varying vec2 st;

vec2 projectAndClamp(vec2 a, vec2 b) {
    return clamp(dot(a,b)/dot(b,b),0.0,1.0) * b;
}

void main() {
//    vec2 st = gl_FragCoord.xy;
    vec2 p = projectAndClamp(st-start, end-start)+start;
    float f = smoothstep(0.0,1.0,distance(p,start)/distance(end,start));
    gl_FragColor = mix(color_start,color_end,f);
}

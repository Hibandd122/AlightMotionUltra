#version 100

precision mediump float;
uniform vec4 color_a;
uniform vec4 color_b;
uniform float oneOverCheckSize;
uniform vec4 offsetScale;

void main() {
    float f = step(mod(floor((gl_FragCoord.x + offsetScale.x)*oneOverCheckSize*offsetScale.z)+floor((gl_FragCoord.y + offsetScale.y)*oneOverCheckSize*offsetScale.w),2.0),0.5);
    gl_FragColor = mix(color_a,color_b,f);
}

#version 100

precision mediump float;
uniform vec4 color;

void main() {
//	float v = smoothstep(0.4,0.5,1.0-distance(gl_PointCoord,vec2(0.5,0.5)));
    float v = (1.0-(distance(gl_PointCoord,vec2(0.5,0.5))*2.0));
    float s = smoothstep(0.0,0.3,v);
	gl_FragColor = color * s;
}

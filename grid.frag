#version 100

precision highp float;
uniform vec4 color;
uniform float grid_spacing;
uniform vec2 grid_offset;
uniform float pixel_scale;
uniform float line_width;
varying vec2 st;

void main() {
    vec2 uv = abs(fract((st+grid_offset+grid_spacing*0.5+0.5)/grid_spacing)-0.5);
    float t = min(uv.x,uv.y);
//    vec2 t = smoothstep(line_width*1.25/grid_spacing,line_width*0.75/grid_spacing,uv);
//    vec2 t = clamp(vec2(1.,1.) - uv / (line_width/grid_spacing),0.,1.);
//    vec2 t = clamp(vec2(1.,1.) - (uv-(line_width/grid_spacing)) / (pixel_scale/grid_spacing),0.,1.);
    float p = clamp(1. - (t-(line_width/grid_spacing)) / (pixel_scale/grid_spacing),0.,1.);
//    float p = max(t.x,t.y);
    gl_FragColor = mix(vec4(0.),color,p);// * 0.0001 + vec4(uv,0.5,1.0)* 0.75;
}

//void main() {
//    vec2 t = mod(st,grid_spacing) + grid_offset;
//    float p = max(step(t.x,1.0), step(t.y,1.0));
//    gl_FragColor = mix(vec4(0.),color,p);
//}

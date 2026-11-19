shader_type spatial;
varying vec3 local_pos;
varying vec3 local_normal;
void vertex(){
    local_pos = VERTEX;
    local_normal = NORMAL;
}
float hash(vec2 p){
    return fract(sin(dot(p,vec2(41.37,79.21)))*4573.23);
}
void fragment(){
    vec2 uv = abs(local_normal.y)>0.5 ? local_pos.zx :
        vec2(abs(local_normal.x)>0.5 ? local_pos.z : local_pos.x,local_pos.y);
    uv = floor(uv*54.0)/54.0;
    float board = floor(uv.y*3.2);
    float grain = sin(uv.y*78.0+sin(uv.x*1.8+board)*2.0);
    float tone = 0.79+0.23*hash(vec2(board,8.0))+0.11*grain+0.12*hash(floor(uv*vec2(6.0,54.0)));
    float seam = smoothstep(0.02,0.10,fract(uv.y*3.2));
    ALBEDO = vec3(0.27,0.155,0.085)*tone*mix(0.35,1.0,seam);
    ROUGHNESS = 0.96;
}

void light() {
    float incidence = max(dot(NORMAL, LIGHT), 0.0);
    float level = 0.35 * smoothstep(0.18, 0.22, incidence)
                + 0.35 * smoothstep(0.49, 0.54, incidence)
                + 0.30 * smoothstep(0.78, 0.83, incidence);
    DIFFUSE_LIGHT += ALBEDO * LIGHT_COLOR * ATTENUATION * level / PI;
}

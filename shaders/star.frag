#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

// Uniform order matters: it is the index order used from Dart (StarPainter).
uniform vec2 uSize;      // 0,1
uniform float uTime;     // 2
uniform float uLoad;     // 3
uniform float uRadius;   // 4  (fraction of min(size))
uniform float uExplode;  // 5
uniform float uNebula;   // 6
uniform float uSeed;     // 7
uniform float uFlash;    // 8
uniform float uRingR;    // 9
uniform float uRingA;    // 10
uniform float uFlareT;   // 11
uniform float uFlareA;   // 12
uniform vec2 uOff;       // 13,14
uniform vec2 uShake;     // 15,16
uniform float uDetail;   // 17  (1 = full detail, 0 = mini)
uniform float uZoom;     // 18  (>1 makes the star bigger in its box)

out vec4 fragColor;

vec4 permute(vec4 x){ return mod(((x*34.0)+1.0)*x, 289.0); }
vec4 taylorInvSqrt(vec4 r){ return 1.79284291400159 - 0.85373472095314*r; }
float snoise(vec3 v){
  const vec2 C = vec2(1.0/6.0, 1.0/3.0); const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);
  vec3 i = floor(v + dot(v, C.yyy)); vec3 x0 = v - i + dot(i, C.xxx);
  vec3 g = step(x0.yzx, x0.xyz); vec3 l = 1.0 - g; vec3 i1 = min(g.xyz, l.zxy); vec3 i2 = max(g.xyz, l.zxy);
  vec3 x1 = x0 - i1 + C.xxx; vec3 x2 = x0 - i2 + 2.0*C.xxx; vec3 x3 = x0 - 1.0 + 3.0*C.xxx;
  i = mod(i, 289.0);
  vec4 p = permute(permute(permute(i.z + vec4(0.0, i1.z, i2.z, 1.0)) + i.y + vec4(0.0, i1.y, i2.y, 1.0)) + i.x + vec4(0.0, i1.x, i2.x, 1.0));
  float n_ = 1.0/7.0; vec3 ns = n_*D.wyz - D.xzx;
  vec4 j = p - 49.0*floor(p*ns.z*ns.z);
  vec4 x_ = floor(j*ns.z); vec4 y_ = floor(j - 7.0*x_);
  vec4 x = x_*ns.x + ns.yyyy; vec4 y = y_*ns.x + ns.yyyy; vec4 h = 1.0 - abs(x) - abs(y);
  vec4 b0 = vec4(x.xy, y.xy); vec4 b1 = vec4(x.zw, y.zw);
  vec4 s0 = floor(b0)*2.0 + 1.0; vec4 s1 = floor(b1)*2.0 + 1.0; vec4 sh = -step(h, vec4(0.0));
  vec4 a0 = b0.xzyw + s0.xzyw*sh.xxyy; vec4 a1 = b1.xzyw + s1.xzyw*sh.zzww;
  vec3 p0 = vec3(a0.xy, h.x); vec3 p1 = vec3(a0.zw, h.y); vec3 p2 = vec3(a1.xy, h.z); vec3 p3 = vec3(a1.zw, h.w);
  vec4 norm = taylorInvSqrt(vec4(dot(p0,p0), dot(p1,p1), dot(p2,p2), dot(p3,p3)));
  p0 *= norm.x; p1 *= norm.y; p2 *= norm.z; p3 *= norm.w;
  vec4 m = max(0.6 - vec4(dot(x0,x0), dot(x1,x1), dot(x2,x2), dot(x3,x3)), 0.0); m = m*m;
  return 42.0*dot(m*m, vec4(dot(p0,x0), dot(p1,x1), dot(p2,x2), dot(p3,x3)));
}
float fbm(vec3 p){ float a = 0.5, s = 0.0; for (int i = 0; i < 5; i++){ s += a*snoise(p); p = p*2.03 + 17.1; a *= 0.5; } return s; }
float fbm3(vec3 p){ float a = 0.5, s = 0.0; for (int i = 0; i < 3; i++){ s += a*snoise(p); p = p*2.1 + 9.3; a *= 0.5; } return s; }
float hash(vec2 p){ return fract(sin(dot(p, vec2(127.1, 311.7)))*43758.5453); }
vec3 hash33(vec3 p){ p = fract(p*vec3(0.1031, 0.1030, 0.0973)); p += dot(p, p.yxz + 33.33); return fract((p.xxy + p.yxx)*p.zyx); }

// Worley (cellular) noise: returns distance to nearest and second-nearest feature point.
// Solar granulation is convection cells: bright hot centers, dark cool lanes between them.
vec2 worley(vec3 p){
  vec3 i = floor(p), f = fract(p);
  float d1 = 8.0, d2 = 8.0;
  for (int x = -1; x <= 1; x++)
  for (int y = -1; y <= 1; y++)
  for (int z = -1; z <= 1; z++){
    vec3 g = vec3(float(x), float(y), float(z));
    vec3 r = g + hash33(i + g) - f;
    float d = dot(r, r);
    if (d < d1){ d2 = d1; d1 = d; } else if (d < d2){ d2 = d; }
  }
  return vec2(sqrt(d1), sqrt(d2));
}

// Approximate blackbody tint by stress level: hot blue-white -> Sun -> orange -> red giant.
vec3 starColor(float L){
  vec3 c0 = vec3(0.60, 0.74, 1.00), c1 = vec3(1.00, 0.88, 0.66), c2 = vec3(1.00, 0.60, 0.28), c3 = vec3(1.00, 0.33, 0.13), c4 = vec3(0.85, 0.15, 0.06);
  if (L < 0.35) return mix(c0, c1, L/0.35);
  if (L < 0.60) return mix(c1, c2, (L-0.35)/0.25);
  if (L < 0.85) return mix(c2, c3, (L-0.60)/0.25);
  return mix(c3, c4, clamp((L-0.85)/0.3, 0.0, 1.0));
}

void main(){
  vec2 frag = FlutterFragCoord().xy;
  float px = 1.0/min(uSize.x, uSize.y);
  vec2 uv = (frag - 0.5*uSize)*px/uZoom + uShake;
  uv.y = -uv.y;
  float t = uTime, L = uLoad, R = max(uRadius, 0.0001);
  float agit = clamp((L - 0.42)/0.65, 0.0, 1.0);
  vec3 col = vec3(0.0);

  /* nebula left by the supernova, with the seed of the next star */
  if (uNebula > 0.001){
    vec3 q = vec3(uv*2.3, t*0.015);
    float warp = fbm3(q*1.3 + 3.0);
    float n = fbm(q + vec3(warp*1.4, warp, 0.0));
    float n2 = fbm3(q*2.0 - vec3(warp, 0.0, t*0.01));
    float fall = exp(-length(uv)*(1.0 + uSeed*0.6)*2.0);
    float dens = smoothstep(-0.25, 0.75, n)*fall;
    vec3 nc = mix(vec3(0.95, 0.25, 0.55), vec3(0.45, 0.30, 1.0), smoothstep(-0.3, 0.4, n2));
    nc = mix(nc, vec3(0.15, 0.75, 0.95), smoothstep(0.15, 0.6, n2 - n*0.4));
    float dust = smoothstep(0.1, 0.5, fbm3(q*3.0 + 7.0));
    col += nc*dens*(1.1 - 0.5*dust)*uNebula*1.4;
    float r0 = length(uv);
    float sr = 0.012 + 0.02*uSeed;
    float pulse = 0.85 + 0.15*sin(t*2.2);
    col += vec3(0.85, 0.92, 1.0)*(exp(-r0/sr)*1.6 + exp(-r0/(sr*5.0))*0.45*pulse)*uNebula;
    float spikes = exp(-abs(uv.x)/0.002)*exp(-abs(uv.y)/(0.05 + 0.06*uSeed)) + exp(-abs(uv.y)/0.002)*exp(-abs(uv.x)/(0.05 + 0.06*uSeed));
    col += vec3(0.8, 0.9, 1.0)*spikes*0.5*uNebula*pulse;
  }

  /* the star */
  float alive = 1.0 - smoothstep(0.08, 0.18, uExplode);
  if (alive > 0.001 && uRadius > 0.0005){
    vec2 su = uv - uOff;
    float r = length(su);
    vec3 sc = starColor(L);
    float a = atan(su.y, su.x);
    vec2 dir = vec2(cos(a), sin(a));
    float d = max(r - R, 0.0)/R;

    // corona streamers + halo
    float rays = fbm3(vec3(dir*2.2, t*0.05 + d*1.2))*0.5 + 0.5;
    float rays2 = snoise(vec3(dir*5.5, t*0.08 - d*0.8))*0.5 + 0.5;
    float corona = exp(-d*(4.2 - agit*1.6))*(0.35 + 1.1*rays*rays2*(0.8 + agit*0.8));
    float halo = exp(-d*1.4)*0.28 + exp(-d*0.5)*0.06;
    // spicules: fine jets of chromospheric plasma along the limb
    float spic = smoothstep(0.35, 0.9, snoise(vec3(dir*48.0, t*0.35 + d*10.0)))*exp(-d/0.045)*smoothstep(0.0, 0.004, d);
    // quiescent prominences
    float band = smoothstep(0.0, 0.015, d)*(1.0 - smoothstep(0.03, 0.12 + agit*0.35, d));
    float loops = smoothstep(0.62 - agit*0.3, 0.95, fbm3(vec3(dir*3.5, t*0.07) + vec3(d*5.0, 0.0, 0.0)) + 0.35);
    float prom = band*loops*(0.25 + agit*1.8);
    vec3 cc = mix(sc, vec3(1.0), 0.3);
    vec3 outside = cc*(corona + halo)*1.05 + vec3(1.0, 0.38, 0.22)*(prom*1.6 + spic*0.9*uDetail);

    // photosphere
    vec3 inside = vec3(0.0);
    if (r < R + 2.0*px){
      float rr = min(r/R, 1.0);
      float z = sqrt(max(1.0 - rr*rr, 0.0));
      vec3 n = vec3(su/R, z);
      // differential rotation: equator spins faster than the poles
      float ang = t*0.035*(1.0 + 0.35*(1.0 - n.y*n.y));
      n.xz = mat2(cos(ang), -sin(ang), sin(ang), cos(ang))*n.xz;
      float speed = 0.04 + agit*0.22;
      // supergranulation / large-scale mottling (subtle)
      float big = fbm(n*2.0 + vec3(0.0, 0.0, t*speed*0.6));
      // granulation: many small convection cells, low contrast at this distance
      vec3 wp = n*(uDetail > 0.5 ? 44.0 : 24.0) + vec3(big*0.3, t*speed*0.8, t*speed*0.5);
      vec2 w = worley(wp);
      float lanes = smoothstep(0.0, 0.24, w.y - w.x);
      float cell = 1.0 - w.x*0.3;
      float fine = uDetail > 0.5 ? smoothstep(0.0, 0.35, abs(snoise(n*90.0 - vec3(0.0, t*speed*1.3, 0.0)))) : 1.0;
      float gran = lanes*cell*(0.75 + 0.25*fine);
      // a few sunspot groups (only when stressed): penumbra + darker umbra
      float spotN = snoise(n*1.7 + vec3(0.0, t*0.012, 3.0)) + 0.25*snoise(n*6.0 + 11.0);
      float act = smoothstep(0.45, 0.95, L);
      float spots = smoothstep(0.6, 0.72, spotN)*act;
      float umbra = smoothstep(0.74, 0.84, spotN)*act;
      // faculae: bright patches near the limb
      float faculae = smoothstep(0.25, 0.65, big)*pow(1.0 - z, 1.6);
      // limb darkening (quadratic law, solar coefficients)
      float mu = z;
      float limb = 1.0 - 0.6*(1.0 - mu) - 0.2*(1.0 - mu)*(1.0 - mu);
      float I = (1.25 + 0.16*big)*mix(0.84, 1.03, gran)*(1.0 - 0.42*spots - 0.42*umbra)*limb + faculae*0.22;
      vec3 c = sc*I;
      // hot core over-exposes toward white, like a real photo of a star
      c = mix(c, vec3(1.0, 0.98, 0.94), clamp(I - 0.95, 0.0, 1.0)*0.75*z);
      c *= mix(vec3(1.0), vec3(1.0, 0.6, 0.4), pow(1.0 - z, 2.4));
      inside = c*1.85;
    }
    float edge = 1.0 - smoothstep(R - 1.5*px, R + 1.5*px, r);
    vec3 starCol = mix(outside, inside, edge);
    starCol += vec3(1.0, 0.55, 0.38)*exp(-abs(r - R)/(R*0.012))*0.35*(0.5 + agit);

    /* completion flare: coronal loops follow the field lines of a magnetic dipole buried under the
       surface, r = L*sin^2(theta). Every loop is anchored in the star. Footpoint flash, post-flare
       arcade lighting loop by loop, then the outer flux rope erupts into a CME plume. */
    if (uFlareT >= 0.0 && uFlareT < 1.0){
      float ft = uFlareT;
      vec2 fd = vec2(cos(uFlareA), sin(uFlareA)), pd = vec2(-fd.y, fd.x);
      vec2 q = su/R;
      float rq = length(q);
      float rise = 1.0 - exp(-ft*3.2);
      float fade = 1.0 - smoothstep(0.5, 1.0, ft);
      float early = 1.0 - smoothstep(0.0, 0.45, ft);
      vec2 c0 = fd*0.86;
      vec2 v = q - c0;
      float rv = length(v);
      float ct = dot(v, pd)/max(rv, 1e-4);
      float s2 = max(1.0 - ct*ct, 1e-3);
      float turb = fbm3(vec3(q*5.0, t*0.6 + ft*4.0));
      float turb2 = fbm3(vec3(q*12.0, t*0.9 - ft*5.0));
      float Lp = rv/s2*(1.0 + turb*0.07);
      float front = smoothstep(-0.02, 0.08, dot(v, fd));
      float outer = smoothstep(0.985, 1.005, rq);
      float vis = mix(0.45, 1.0, outer)*front;
      // position along each loop (-1..1) drives brightness knots so loops are not clean rings
      float along = ct;
      float knots = 0.55 + 0.45*fbm3(vec3(along*3.0, Lp*6.0, t*0.4 + ft*2.0));
      float arc = 0.0;
      float arcGlow = 0.0;
      for (int k = 0; k < 4; k++){
        float fk = float(k);
        float Lk = 0.16 + fk*0.075 + rise*0.05 + turb2*0.012;
        float wk = 0.012 + 0.007*fk;
        float on = smoothstep(fk*0.08, fk*0.08 + 0.18, ft);
        float dl = abs(Lp - Lk);
        arc += exp(-dl/wk)*on*(1.0 - fk*0.15);
        arcGlow += exp(-dl/(wk*5.0))*on*0.25;
      }
      arc *= knots;
      // erupting flux rope: ragged, broken, fading as it tears open
      float Le = 0.45 + rise*1.25;
      float tear = smoothstep(0.3, 0.75, ft);
      float broken = smoothstep(-0.15, 0.35, fbm3(vec3(along*4.0, t*0.3, ft*3.0)));
      float rope = exp(-abs(Lp - Le + turb*0.1)/(0.05 + 0.12*rise))*broken*(1.0 - 0.75*tear)*0.7;
      // CME: diffuse, wispy cloud expanding behind the rope (soft, not a balloon)
      float wisp = fbm3(vec3(q*2.2 - fd*ft*1.5, t*0.2)) * 0.5 + 0.5;
      float plume = smoothstep(Le*1.15, Le*0.35, Lp)*smoothstep(0.3, 0.6, Lp)*wisp*wisp*0.55*rise*(1.0 - 0.4*tear);
      vec2 apex = c0 + fd*Le*0.9;
      float core = exp(-length(q - apex)/(0.08 + 0.14*rise))*(0.4 + 0.6*wisp)*0.8;
      float foot = exp(-length(q - fd*0.985)/0.1)*early;
      float F = (arc*1.5 + arcGlow + rope + plume + core)*vis*fade + foot*2.6;
      vec3 hot = vec3(1.0, 0.96, 0.88), plasma = mix(vec3(1.0, 0.5, 0.25), sc*1.2, 0.35);
      starCol += mix(plasma, hot, clamp(arc*0.5 + foot, 0.0, 1.0))*F*1.6;
      starCol += sc*exp(-length(q - fd)*1.6)*0.7*early;
    }
    if (uRingA > 0.0) starCol += mix(sc, vec3(1.0), 0.5)*exp(-abs(r - uRingR)/0.006)*uRingA;
    col += starCol*alive;
  }

  /* supernova shock shell */
  if (uExplode > 0.0 && uExplode < 1.0){
    float e = uExplode;
    float r = length(uv);
    float a = atan(uv.y, uv.x);
    float rs = 0.06 + e*0.85;
    float fil = fbm3(vec3(cos(a)*4.0, sin(a)*4.0, e*3.0))*0.5 + 0.5;
    float shell = exp(-abs(r - rs)/(0.008 + e*0.05))*(0.4 + 1.4*fil)*(1.0 - e);
    float inner = exp(-r/(0.05 + e*0.4))*(1.0 - e)*0.8;
    vec3 ec = mix(vec3(1.0, 0.95, 0.85), mix(vec3(1.0, 0.45, 0.25), vec3(0.85, 0.35, 1.0), e), smoothstep(0.0, 0.5, e));
    col += ec*(shell*1.6 + inner);
  }

  col += vec3(1.0, 0.97, 0.94)*uFlash*2.0;
  col = 1.0 - exp(-col*1.35);
  col = pow(col, vec3(0.95));
  // transparent where dark so the glass and sky show through (premultiplied output)
  float alpha = clamp(max(col.r, max(col.g, col.b))*1.6, 0.0, 1.0);
  fragColor = vec4(col, alpha);
}

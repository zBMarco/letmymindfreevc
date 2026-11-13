#version 460 core
#include <flutter/runtime_effect.glsl>
precision highp float;

// One planet lit by the star. Drawn over a small square around the planet.
// Uniform order matters: it is the index order used from Dart (SolarSystem).
uniform vec2 uCenter;   // 0,1   planet center in canvas pixels
uniform float uRadius;  // 2     planet radius in pixels
uniform vec3 uLight;    // 3,4,5 direction planet -> star (x right, y up, z toward viewer)
uniform vec3 uColor;    // 6,7,8 task type color
uniform vec3 uStar;     // 9,10,11 star light color
uniform float uKind;    // 12    0 rocky/ocean, 1 gas giant, 2 ice world
uniform float uSeed;    // 13    0..1, unique per planet
uniform float uSpin;    // 14    rotation angle
uniform float uRing;    // 15    1 = has rings
uniform float uAlpha;   // 16
uniform float uTime;    // 17

out vec4 fragColor;

float hash3(vec3 p){
  p = fract(p*0.3183099 + 0.1);
  p *= 17.0;
  return fract(p.x*p.y*p.z*(p.x + p.y + p.z));
}
float vnoise(vec3 x){
  vec3 i = floor(x), f = fract(x);
  f = f*f*(3.0 - 2.0*f);
  return mix(mix(mix(hash3(i + vec3(0.0, 0.0, 0.0)), hash3(i + vec3(1.0, 0.0, 0.0)), f.x),
                 mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), f.x), f.y),
             mix(mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), f.x),
                 mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), f.x), f.y), f.z);
}
float fbm(vec3 p){
  float a = 0.5, s = 0.0;
  for (int i = 0; i < 4; i++){ s += a*vnoise(p); p = p*2.02 + 3.7; a *= 0.5; }
  return s/0.9375;
}
mat2 rot(float a){ return mat2(cos(a), sin(a), -sin(a), cos(a)); }

void main(){
  vec2 p = (FlutterFragCoord().xy - uCenter)/uRadius;
  p.y = -p.y;
  float aa = 1.5/uRadius;
  float rr = dot(p, p);
  float r = sqrt(rr);
  vec3 L = normalize(uLight);

  // col is premultiplied light, alpha is coverage
  vec3 col = vec3(0.0);
  float alpha = 0.0;

  float atm = uKind < 0.5 ? 1.0 : (uKind < 1.5 ? 0.65 : 0.85);
  vec3 atmCol = mix(uColor, vec3(0.70, 0.85, 1.0), 0.45)*uStar;

  // thin atmosphere glowing just outside the limb, only on the day side
  if (r > 1.0){
    vec2 pd = p/r;
    float day = clamp(dot(pd, L.xy)*0.9 + 0.25 + L.z*0.3, 0.0, 1.0);
    // backlit: light scatters forward through the atmosphere and the whole limb glows
    float fwd = pow(clamp(-L.z, 0.0, 1.0), 1.5);
    float halo = exp(-(r - 1.0)*16.0)*(day*0.6 + fwd*0.9)*atm;
    col += atmCol*halo;
    alpha += halo*0.8;
  }

  float zf = sqrt(max(1.0 - rr, 0.0));
  float disk = 1.0 - smoothstep(1.0 - aa, 1.0 + aa, r);
  if (disk > 0.0){
    vec3 n = vec3(p, zf);
    // body frame: axial tilt, then spin around the axis
    vec3 b = n;
    b.yz = rot(0.35 + uSeed*0.3)*b.yz;
    b.xz = rot(uSpin)*b.xz;
    vec3 q = b*2.2 + uSeed*17.0;

    vec3 base;
    float spec = 0.0;
    if (uKind < 0.5){
      // rocky world: oceans, continents tinted by the type color, polar caps, moving clouds
      float h = fbm(q*1.2);
      float land = smoothstep(0.47, 0.53, h);
      float detail = fbm(q*4.0);
      vec3 ocean = mix(uColor*0.22, vec3(0.02, 0.07, 0.17), 0.55);
      vec3 ground = mix(uColor*0.8, mix(uColor, vec3(0.55, 0.45, 0.32), 0.5), detail);
      float ice = smoothstep(0.78, 0.92, abs(b.y) + detail*0.12);
      base = mix(ocean, ground, land);
      base = mix(base, vec3(0.92, 0.95, 1.0), ice);
      spec = (1.0 - land)*(1.0 - ice);
      float cl = smoothstep(0.52, 0.78, fbm(q*1.6 + vec3(uTime*0.02, 0.0, 0.0)));
      base = mix(base, vec3(1.0), cl*0.85);
      spec *= 1.0 - cl;
    } else if (uKind < 1.5){
      // gas giant: turbulent latitude bands and one great storm
      float y = b.y;
      float turb = fbm(vec3(q.x*0.6, y*6.0, q.z*0.6) + vec3(uTime*0.015, 0.0, 0.0));
      float bands = sin(y*(9.0 + uSeed*6.0) + turb*3.2)*0.5 + 0.5;
      float fine = sin(y*31.0 + turb*5.0)*0.5 + 0.5;
      vec3 lightB = mix(uColor, vec3(1.0, 0.96, 0.88), 0.45);
      vec3 darkB = uColor*0.45 + vec3(0.06, 0.03, 0.0);
      base = mix(darkB, lightB, bands*0.8 + fine*0.2);
      vec3 sc = normalize(vec3(0.5, -0.35, 0.8));
      float st = 1.0 - smoothstep(0.0, 0.22, length((b - sc)*vec3(1.0, 1.8, 1.0)));
      base = mix(base, uColor*1.1 + vec3(0.15, 0.05, 0.0), st*0.8);
    } else {
      // ice world: pale crust with dark cracks
      float h = fbm(q*1.5);
      float cracks = 1.0 - smoothstep(0.0, 0.025, abs(fbm(q*3.0) - 0.5));
      base = mix(mix(uColor, vec3(0.9, 0.96, 1.0), 0.55), mix(uColor, vec3(1.0), 0.75), h);
      base = mix(base, uColor*0.45, cracks*0.6);
      spec = 0.35;
    }

    float ndl = dot(n, L);
    float diff = clamp(ndl*0.9 + 0.1, 0.0, 1.0)*smoothstep(-0.15, 0.15, ndl);
    vec3 H = normalize(L + vec3(0.0, 0.0, 1.0));
    float sp = pow(max(dot(n, H), 0.0), 40.0)*spec*smoothstep(0.0, 0.2, ndl);
    float fres = pow(1.0 - zf, 3.0);
    vec3 surf = base*uStar*diff*1.15 + uStar*sp*0.6;
    surf += atmCol*fres*smoothstep(-0.2, 0.5, ndl)*0.7*atm;  // scattering at the limb
    float fwd = pow(clamp(-L.z, 0.0, 1.0), 1.5);
    surf += atmCol*pow(1.0 - zf, 5.0)*fwd*1.4*atm;           // thin bright rim when backlit
    surf += base*vec3(0.10, 0.12, 0.17);                    // skylight keeps the night side readable
    col = mix(col, surf, disk);
    alpha = mix(alpha, 1.0, disk);
  }

  if (uRing > 0.5){
    // ring plane through the planet center; visible where it is in front of the sphere
    vec3 nr = normalize(vec3(0.18, 1.0, 0.42));
    float zr = -(nr.x*p.x + nr.y*p.y)/nr.z;
    vec3 P = vec3(p, zr);
    float d = length(P);
    if (d > 1.3 && d < 2.25 && (r > 1.0 || zr > zf)){
      float g = (d - 1.3)/0.95;
      float dens = (0.55 + 0.45*sin(g*40.0 + uSeed*10.0))*(0.6 + 0.4*sin(g*9.0 + 2.0));
      dens *= smoothstep(0.0, 0.06, g)*(1.0 - smoothstep(0.85, 1.0, g));
      dens *= 1.0 - 0.85*smoothstep(0.55, 0.6, g)*(1.0 - smoothstep(0.61, 0.66, g)); // a gap
      // the planet's shadow falls on the ring
      float b2 = dot(P, L);
      float disc = b2*b2 - (dot(P, P) - 1.0);
      float shadow = (disc > 0.0 && b2 < 0.0) ? 0.15 : 1.0;
      float lit = (0.6 + 0.6*abs(dot(nr, L)))*shadow;
      vec3 rc = mix(uColor, vec3(0.95, 0.9, 0.8), 0.6)*uStar*lit;
      float ra = clamp(dens*0.85, 0.0, 0.9);
      col = mix(col, rc, ra);
      alpha = mix(alpha, 1.0, ra);
    }
  }

  fragColor = vec4(min(col, vec3(1.0)), clamp(alpha, 0.0, 1.0))*uAlpha;
}

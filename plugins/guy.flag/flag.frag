#version 440
// Omnemo OS flag bar: red and white stripes as cloth in a light breeze.
// Compile: /usr/lib/qt6/bin/qsb --qt6 -o flag.frag.qsb flag.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
  mat4 qt_Matrix;
  float qt_Opacity;
  float phase;    // 0..2*pi, wraps; every wave below is a whole number of cycles
  float pxw;      // width in pixels
  float pxh;      // height in pixels
  float stripes;
  float wave;     // 0 = still cloth, 1 = full breeze
  vec4 red;
  vec4 white;
};
vec3 stripeColor(float i) { return mod(i, 2.0) < 0.5 ? red.rgb : white.rgb; }
void main() {
  vec2 uv = qt_TexCoord0;
  float x = uv.x * pxw;
  // Three swells of different length, all travelling right.
  float p1 = x * 0.021 - phase * 6.0;
  float p2 = x * 0.047 - phase * 9.0 + 1.3;
  float p3 = x * 0.009 - phase * 3.0 + 4.0;
  float lift  = sin(p1) * 0.55 + sin(p2) * 0.25 + sin(p3) * 0.45;
  float slope = cos(p1) * 0.55 + cos(p2) * 0.25 + cos(p3) * 0.45;
  // The stripes ride the swell by about a pixel and a half.
  float y = clamp(uv.y + wave * lift * (1.5 / pxh), 0.0, 0.9999);
  float s = y * stripes;
  float i = floor(s);
  float f = s - i;
  float px = stripes / pxh;               // one pixel, in stripe units
  vec3 c = stripeColor(i);
  if (f < px * 0.5 && i > 0.5)                  c = mix(stripeColor(i - 1.0), c, 0.5 + f / px);
  else if (f > 1.0 - px * 0.5 && i < stripes - 1.5) c = mix(c, stripeColor(i + 1.0), 0.5 - (1.0 - f) / px);
  // A little material: each stripe a touch deeper toward its foot.
  c *= 1.0 - 0.07 * f;
  // Light across the folds: brighter on the faces turned to the light.
  c *= 1.0 + wave * (0.11 * slope - 0.03);
  fragColor = vec4(c, 1.0) * qt_Opacity;
}

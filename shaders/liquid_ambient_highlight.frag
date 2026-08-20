#version 320 es

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 u_size;
uniform vec4 u_corner_radii;
uniform float u_angle;
uniform float u_falloff;
uniform float u_alpha;

out vec4 frag_color;

float radius_at(vec2 point) {
  if (point.x < 0.0) {
    return point.y < 0.0 ? u_corner_radii.x : u_corner_radii.w;
  }
  return point.y < 0.0 ? u_corner_radii.y : u_corner_radii.z;
}

vec2 rounded_rect_gradient(
  vec2 point,
  vec2 half_size,
  float radius
) {
  vec2 corner = abs(point) - (half_size - vec2(radius));
  if (corner.x >= 0.0 || corner.y >= 0.0) {
    return sign(point) * normalize(max(corner, vec2(0.0)));
  }
  float gradient_x = step(corner.y, corner.x);
  return sign(point) * vec2(gradient_x, 1.0 - gradient_x);
}

void main() {
  vec2 coordinate = FlutterFragCoord().xy;
  vec2 half_size = u_size * 0.5;
  vec2 centered = coordinate - half_size;
  float radius = min(
    radius_at(centered),
    min(half_size.x, half_size.y)
  );
  vec2 gradient = rounded_rect_gradient(
    centered,
    half_size,
    min(radius * 1.5, min(half_size.x, half_size.y))
  );
  vec2 normal = vec2(cos(u_angle), sin(u_angle));
  float direction = dot(gradient, normal);
  float intensity = pow(abs(direction), u_falloff);
  float positive = step(0.0, direction);
  frag_color = vec4(positive * intensity * u_alpha);
}

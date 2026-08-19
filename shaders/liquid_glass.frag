#version 320 es

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 u_size;
uniform sampler2D u_texture;
uniform float u_corner_radius;
uniform float u_refraction_height;
uniform float u_refraction_amount;
uniform float u_chromatic_aberration;

out vec4 frag_color;

float rounded_rect_distance(vec2 point, vec2 half_size, float radius) {
  vec2 distance = abs(point) - half_size + radius;
  return min(max(distance.x, distance.y), 0.0) +
      length(max(distance, 0.0)) - radius;
}

vec2 texture_coordinate(vec2 coordinate) {
  vec2 uv = clamp(coordinate / u_size, 0.0, 1.0);
#ifdef IMPELLER_TARGET_OPENGLES
  uv.y = 1.0 - uv.y;
#endif
  return uv;
}

void main() {
  vec2 coordinate = FlutterFragCoord().xy;
  vec2 half_size = u_size * 0.5;
  float radius = min(u_corner_radius, min(half_size.x, half_size.y));
  vec2 centered = coordinate - half_size;
  float distance = rounded_rect_distance(centered, half_size, radius);
  float inner_distance = max(-distance, 0.0);

  if (inner_distance >= u_refraction_height) {
    frag_color = texture(u_texture, texture_coordinate(coordinate));
    return;
  }

  float edge = clamp(
    1.0 - inner_distance / max(u_refraction_height, 0.001),
    0.0,
    1.0
  );
  float refraction = (
    1.0 - sqrt(max(1.0 - edge * edge, 0.0))
  ) * u_refraction_amount;
  float epsilon = 1.0;
  vec2 gradient = normalize(vec2(
    rounded_rect_distance(
      centered + vec2(epsilon, 0.0),
      half_size,
      radius
    ) - rounded_rect_distance(
      centered - vec2(epsilon, 0.0),
      half_size,
      radius
    ),
    rounded_rect_distance(
      centered + vec2(0.0, epsilon),
      half_size,
      radius
    ) - rounded_rect_distance(
      centered - vec2(0.0, epsilon),
      half_size,
      radius
    )
  ));
  vec2 refracted_coordinate = coordinate + gradient * refraction;
  vec2 dispersion = gradient * edge * u_chromatic_aberration;
  vec4 center = texture(
    u_texture,
    texture_coordinate(refracted_coordinate)
  );
  vec4 red = texture(
    u_texture,
    texture_coordinate(refracted_coordinate + dispersion)
  );
  vec4 blue = texture(
    u_texture,
    texture_coordinate(refracted_coordinate - dispersion)
  );
  vec3 color = min(vec3(red.r, center.g, blue.b), vec3(center.a));
  frag_color = vec4(color, center.a);
}

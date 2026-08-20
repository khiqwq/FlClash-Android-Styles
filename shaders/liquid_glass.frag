#version 320 es

#include <flutter/runtime_effect.glsl>

precision highp float;

uniform vec2 u_input_size;
uniform vec2 u_shape_origin;
uniform vec2 u_shape_size;
uniform vec4 u_corner_radii;
uniform float u_refraction_height;
uniform float u_refraction_amount;
uniform float u_chromatic_aberration;
uniform float u_depth_effect;
uniform sampler2D u_texture;

out vec4 frag_color;

float corner_radius(vec2 point) {
  if (point.x < 0.0) {
    return point.y < 0.0 ? u_corner_radii.x : u_corner_radii.w;
  }
  return point.y < 0.0 ? u_corner_radii.y : u_corner_radii.z;
}

float rounded_rect_distance(vec2 point, vec2 half_size) {
  float radius = min(
    corner_radius(point),
    min(half_size.x, half_size.y)
  );
  vec2 distance = abs(point) - half_size + radius;
  return min(max(distance.x, distance.y), 0.0) +
      length(max(distance, 0.0)) - radius;
}

vec2 texture_coordinate(vec2 coordinate) {
  return clamp(coordinate / u_input_size, vec2(0.0), vec2(1.0));
}

vec3 unpremultiplied_rgb(vec4 color) {
  return color.a > 0.0001 ? color.rgb / color.a : vec3(0.0);
}

void main() {
  vec2 coordinate = FlutterFragCoord().xy;
  vec2 half_size = u_shape_size * 0.5;
  vec2 centered = coordinate - u_shape_origin - half_size;
  float distance = rounded_rect_distance(centered, half_size);
  vec4 original = texture(u_texture, texture_coordinate(coordinate));

  if (distance > 0.0) {
    frag_color = original;
    return;
  }

  float inner_distance = max(-distance, 0.0);
  if (inner_distance >= u_refraction_height) {
    frag_color = original;
    return;
  }

  float edge = clamp(
    1.0 - inner_distance / max(u_refraction_height, 0.001),
    0.0,
    1.0
  );
  float epsilon = 0.75;
  vec2 raw_gradient = vec2(
    rounded_rect_distance(centered + vec2(epsilon, 0.0), half_size) -
        rounded_rect_distance(centered - vec2(epsilon, 0.0), half_size),
    rounded_rect_distance(centered + vec2(0.0, epsilon), half_size) -
        rounded_rect_distance(centered - vec2(0.0, epsilon), half_size)
  );
  raw_gradient.y += u_depth_effect * edge;
  float gradient_length = length(raw_gradient);
  vec2 gradient = gradient_length > 0.0001
      ? raw_gradient / gradient_length
      : vec2(0.0);
  float circle_map = 1.0 - sqrt(max(1.0 - edge * edge, 0.0));
  float refraction = -circle_map * max(u_refraction_amount, 0.0);
  vec2 refracted_coordinate = coordinate + gradient * refraction;
  vec2 dispersion = gradient * edge * max(u_chromatic_aberration, 0.0);
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
  vec3 color = vec3(
    unpremultiplied_rgb(red).r,
    unpremultiplied_rgb(center).g,
    unpremultiplied_rgb(blue).b
  );
  frag_color = vec4(color * center.a, center.a);
}

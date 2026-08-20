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

float radius_at(vec2 point) {
  if (point.x < 0.0) {
    return point.y < 0.0 ? u_corner_radii.x : u_corner_radii.w;
  }
  return point.y < 0.0 ? u_corner_radii.y : u_corner_radii.z;
}

float rounded_rect_distance(
  vec2 point,
  vec2 half_size,
  float radius
) {
  vec2 corner = abs(point) - (half_size - vec2(radius));
  float outside = length(max(corner, vec2(0.0))) - radius;
  float inside = min(max(corner.x, corner.y), 0.0);
  return outside + inside;
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

vec2 texture_coordinate(vec2 coordinate) {
  return clamp(coordinate / u_input_size, vec2(0.0), vec2(1.0));
}

float circle_map(float value) {
  return 1.0 - sqrt(max(1.0 - value * value, 0.0));
}

void main() {
  vec2 coordinate = FlutterFragCoord().xy;
  vec2 half_size = u_shape_size * 0.5;
  vec2 centered = coordinate - u_shape_origin - half_size;
  float radius = min(
    radius_at(centered),
    min(half_size.x, half_size.y)
  );
  float distance = rounded_rect_distance(centered, half_size, radius);
  vec4 original = texture(u_texture, texture_coordinate(coordinate));

  if (-distance >= u_refraction_height) {
    frag_color = original;
    return;
  }

  distance = min(distance, 0.0);
  float mapped_distance = circle_map(
    1.0 - -distance / max(u_refraction_height, 0.001)
  );
  float refraction = -mapped_distance * max(u_refraction_amount, 0.0);
  float gradient_radius = min(
    radius * 1.5,
    min(half_size.x, half_size.y)
  );
  vec2 center_direction = length(centered) > 0.0001
      ? normalize(centered)
      : vec2(0.0);
  vec2 gradient = normalize(
    rounded_rect_gradient(centered, half_size, gradient_radius) +
        u_depth_effect * center_direction
  );
  vec2 refracted_coordinate = coordinate + gradient * refraction;
  float dispersion_intensity =
      u_chromatic_aberration *
      ((centered.x * centered.y) / max(half_size.x * half_size.y, 0.001));
  vec2 dispersed_coordinate =
      refraction * gradient * dispersion_intensity;

  vec4 color = vec4(0.0);
  vec4 red = texture(
    u_texture,
    texture_coordinate(refracted_coordinate + dispersed_coordinate)
  );
  color.r += red.r / 3.5;
  color.a += red.a / 7.0;

  vec4 orange = texture(
    u_texture,
    texture_coordinate(
      refracted_coordinate + dispersed_coordinate * (2.0 / 3.0)
    )
  );
  color.r += orange.r / 3.5;
  color.g += orange.g / 7.0;
  color.a += orange.a / 7.0;

  vec4 yellow = texture(
    u_texture,
    texture_coordinate(
      refracted_coordinate + dispersed_coordinate * (1.0 / 3.0)
    )
  );
  color.r += yellow.r / 3.5;
  color.g += yellow.g / 3.5;
  color.a += yellow.a / 7.0;

  vec4 green = texture(
    u_texture,
    texture_coordinate(refracted_coordinate)
  );
  color.g += green.g / 3.5;
  color.a += green.a / 7.0;

  vec4 cyan = texture(
    u_texture,
    texture_coordinate(
      refracted_coordinate - dispersed_coordinate * (1.0 / 3.0)
    )
  );
  color.g += cyan.g / 3.5;
  color.b += cyan.b / 3.0;
  color.a += cyan.a / 7.0;

  vec4 blue = texture(
    u_texture,
    texture_coordinate(
      refracted_coordinate - dispersed_coordinate * (2.0 / 3.0)
    )
  );
  color.b += blue.b / 3.0;
  color.a += blue.a / 7.0;

  vec4 purple = texture(
    u_texture,
    texture_coordinate(refracted_coordinate - dispersed_coordinate)
  );
  color.r += purple.r / 7.0;
  color.b += purple.b / 3.0;
  color.a += purple.a / 7.0;

  frag_color = color;
}

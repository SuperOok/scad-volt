diameter = 37;
height = 0.4;
plain_layer_count = 5;
layer_index = 0; // [0:5]
star_layer_strip_count = 10;
star_layer_strip_index = 0; // [0:9]
slot_width = 15;
slot_height = 1;
slot_vertical_spacing = 14;
logo_file = "Logo_of_Volt.svg";
logo_width = 28;
logo_engrave_depth = 0.4;
star_tip_to_tip = 5;
star_inner_radius_ratio = 0.382;
star_edge_inset = 4;
star_count = 12;
star_index = 0; // [0:11]
part = "assembly"; // [assembly, backplate, layer, star_layer_strip, stars, star_single]

$fn = 96;
eps = 0.01;
star_ring_radius = diameter / 2 - star_edge_inset;
star_layer_z = plain_layer_count * height;
total_layer_count = plain_layer_count + 1;
star_layer_strip_width = diameter / star_layer_strip_count;

module star_2d(tip_to_tip, inner_radius_ratio = star_inner_radius_ratio) {
    outer_radius = tip_to_tip / 2;
    inner_radius = outer_radius * inner_radius_ratio;

    polygon([
        for (i = [0:9])
            let(
                angle = 90 + i * 36,
                radius = i % 2 == 0 ? outer_radius : inner_radius
            )
            [radius * cos(angle), radius * sin(angle)]
    ]);
}

module star_prism(tip_to_tip, prism_height = height) {
    linear_extrude(height = prism_height)
        star_2d(tip_to_tip);
}

module backplate() {
    union() {
        for (i = [0 : plain_layer_count - 1])
            plain_layer(i);

        star_layer();
    }
}

module plain_layer(index) {
    translate([0, 0, index * height])
        if (index == 0) {
            difference() {
                cylinder(d = diameter, h = height);
                bottom_logo_cutout();
                layer_slot_cutouts();
            }
        } else {
            difference() {
                cylinder(d = diameter, h = height);
                layer_slot_cutouts();
            }
        }
}

module layer_slot_cutouts() {
    for (y = [-slot_vertical_spacing / 2, slot_vertical_spacing / 2])
        translate([0, y, -eps])
            linear_extrude(height = height + 2 * eps)
                square([slot_width, slot_height], center = true);
}

module bottom_logo_cutout() {
    translate([0, 0, -eps])
        linear_extrude(height = logo_engrave_depth + eps)
            volt_logo_2d_bottom_readable();
}

module volt_logo_2d_bottom_readable() {
    mirror([1, 0, 0])
        resize([logo_width, 0], auto = true)
            import(file = logo_file, center = true);
}

module star_layer() {
    translate([0, 0, star_layer_z])
        star_layer_core();
}

module star_layer_core() {
    difference() {
        cylinder(d = diameter, h = height);
        star_ring_cutout();
        layer_slot_cutouts();
    }
}

module star_layer_strip(index) {
    strip_x_min = -diameter / 2 + index * star_layer_strip_width;
    strip_x_center = strip_x_min + star_layer_strip_width / 2;

    translate([0, 0, star_layer_z])
        intersection() {
            star_layer_core();
            translate([strip_x_center, 0, height / 2])
                cube(
                    [star_layer_strip_width, diameter + 2 * eps, height + 2 * eps],
                    center = true
                );
        }
}

module backplate_layer(index) {
    if (index < plain_layer_count)
        plain_layer(index);
    else
        star_layer();
}

module star_at_index(index, prism_height = height, z_offset = 0) {
    angle = 90 - index * 360 / star_count;

    translate([
        star_ring_radius * cos(angle),
        star_ring_radius * sin(angle),
        z_offset
    ])
        star_prism(star_tip_to_tip, prism_height);
}

module star_insert(index) {
    difference() {
        star_at_index(index, height, star_layer_z);
        translate([0, 0, star_layer_z])
            layer_slot_cutouts();
    }
}

module star_ring_insert() {
    for (i = [0 : star_count - 1])
        star_insert(i);
}

module star_ring_cutout() {
    for (i = [0 : star_count - 1])
        star_at_index(i, height + 2 * eps, -eps);
}

if (part == "backplate") {
    backplate();
} else if (part == "layer") {
    backplate_layer(layer_index);
} else if (part == "star_layer_strip") {
    star_layer_strip(star_layer_strip_index);
} else if (part == "stars") {
    star_ring_insert();
} else if (part == "star_single") {
    star_insert(star_index);
} else {
    color("#502379") backplate();
    color("#ffcc00") star_ring_insert();
}

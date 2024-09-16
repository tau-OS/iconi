public class Iconi.Utils {
    public static void create_svg_with_icon (string icon_path, Gdk.RGBA? background_color, bool? frame, bool? dev, string output_path) {
        int canvas_size = 128;
        int background_size = 104;
        int max_icon_size = 128;
        int margin = (canvas_size - background_size) / 2;

        var final_color = get_background_color (icon_path, background_color);

        var surface = new Cairo.SvgSurface (output_path, canvas_size, canvas_size);
        var cr = new Cairo.Context (surface);

        // 1. Create a linear gradient for the background
        var pattern = new Cairo.Pattern.linear (margin, margin, margin + background_size, margin + background_size);

        // Get the hue-shifted color (shift final_color by 30°)
        var hue_shifted_color = shift_hue (final_color, 30);

        // Add gradient stops: start with final_color at the top-left, end with hue-shifted_color at the bottom-right
        pattern.add_color_stop_rgba (0, final_color.red, final_color.green, final_color.blue, final_color.alpha);
        pattern.add_color_stop_rgba (1, hue_shifted_color.red, hue_shifted_color.green, hue_shifted_color.blue, hue_shifted_color.alpha);

        // 2. Draw the full rounded background with the gradient
        cr.set_source (pattern);
        draw_rounded_rectangle (cr, margin, margin, background_size, background_size, 24);
        cr.fill ();

        // 3. Render the user-provided icon, composite it onto the background
        try {
            var handle = new Rsvg.Handle.from_file (icon_path);
            if (handle != null) {
                // Get the dimensions of the icon
                var dim = handle.get_dimensions ();

                // Calculate scaling factor to fit icon within max_icon_size
                double scale = Math.fmin ((double) max_icon_size / dim.width, (double) max_icon_size / dim.height);

                // Calculate the actual size after scaling
                double scaled_width = dim.width * scale;
                double scaled_height = dim.height * scale;

                // Calculate position to center the icon
                double x = margin + (background_size - scaled_width) / 2;
                double y = margin + (background_size - scaled_height) / 2;

                // Apply transformations
                cr.save ();
                cr.translate (x, y);
                cr.scale (scale, scale);

                // Render the icon on top of the background
                handle.render_cairo (cr);

                // Restore the context
                cr.restore ();
            }
        } catch (Error e) {
            warning ("Error rendering icon: %s", e.message);
        }

        if (frame) {
            try {
                var resource = GLib.resources_lookup_data ("/com/fyralabs/Iconi/frame.svg", GLib.ResourceLookupFlags.NONE);
                var effects_handle = new Rsvg.Handle.from_data (resource.get_data ());
                if (effects_handle != null) {
                    cr.save ();

                    // Render the icon on top of the background
                    effects_handle.render_cairo (cr);

                    // Restore the context
                    cr.restore ();
                }
            } catch (Error e) {
                warning ("Error rendering icon: %s", e.message);
            }
        }

        try {
            var resource = GLib.resources_lookup_data ("/com/fyralabs/Iconi/effects.svg", GLib.ResourceLookupFlags.NONE);
            var effects_handle = new Rsvg.Handle.from_data (resource.get_data ());
            if (effects_handle != null) {
                cr.save ();

                // Render the icon on top of the background
                effects_handle.render_cairo (cr);

                // Restore the context
                cr.restore ();
            }
        } catch (Error e) {
            warning ("Error rendering icon: %s", e.message);
        }

        if (dev) {
            try {
                var resource = GLib.resources_lookup_data ("/com/fyralabs/Iconi/dev.svg", GLib.ResourceLookupFlags.NONE);
                var effects_handle = new Rsvg.Handle.from_data (resource.get_data ());
                if (effects_handle != null) {
                    cr.save ();

                    // Render the icon on top of the background
                    effects_handle.render_cairo (cr);

                    // Restore the context
                    cr.restore ();
                }
            } catch (Error e) {
                warning ("Error rendering icon: %s", e.message);
            }
        }

        cr.show_page ();
        surface.finish ();

        print ("SVG exported as '%s'.\n", output_path);
    }

// Draws a rounded rectangle
    public static void draw_rounded_rectangle (Cairo.Context cr, double x, double y, double width, double height, double radius) {
        cr.new_sub_path ();
        cr.arc (x + radius, y + radius, radius, Math.PI, -Math.PI / 2);
        cr.arc (x + width - radius, y + radius, radius, -Math.PI / 2, 0);
        cr.arc (x + width - radius, y + height - radius, radius, 0, Math.PI / 2);
        cr.arc (x + radius, y + height - radius, radius, Math.PI / 2, Math.PI);
        cr.close_path ();
    }

// Helper method to shift hue of a Gdk.RGBA color by a given degree (angle)
    public static Gdk.RGBA shift_hue (Gdk.RGBA color, double degrees) {
        // Convert RGBA to HCT for hue shifting
        double hue, saturation, valve;
        rgb_to_hsv (color.red, color.green, color.blue, out hue, out saturation, out valve);

        // Shift the hue by given degrees and normalize between 0 and 360
        hue = (hue + degrees).clamp (0, 360);

        // Convert back to Gdk.RGBA
        double[] new_color = hsv_to_rgb (hue, saturation, valve);

        Gdk.RGBA res = { (float) new_color[0], (float) new_color[1], (float) new_color[2], color.alpha };

        return res;
    }

    public static void rgb_to_hsv (double red, double green, double blue, out double hue, out double saturation, out double valve) {
        double min, max, delta;
        min = Math.fmin (red, Math.fmin (green, blue));
        max = Math.fmax (red, Math.fmax (green, blue));
        valve = max; // v
        delta = max - min;
        if (max != 0)
            saturation = delta / max; // s
        else {
            // r = g = b = 0
            saturation = 0;
            hue = -1;
            return;
        }
        if (red == max)
            hue = (green - blue) / delta; // between yellow & magenta
        else if (green == max)
            hue = 2 + (blue - red) / delta; // between cyan & yellow
        else
            hue = 4 + (red - green) / delta; // between magenta & cyan
        hue *= 60; // degrees
        if (hue < 0)
            hue += 360;
    }

// Helper method to convert HSV to RGB
    public static double[] hsv_to_rgb (double hue, double saturation, double valve) {
        int i;
        double f, p, q, t;
        double[] color = {};
        if (saturation == 0) {
            // achromatic (grey)
            color += valve;
            color += valve;
            color += valve;
            return color;
        }
        hue /= 60; // sector 0 to 5
        i = (int) Math.floor (hue);
        f = hue - i; // fractional part of hue
        p = valve * (1 - saturation);
        q = valve * (1 - saturation * f);
        t = valve * (1 - saturation * (1 - f));
        switch (i) {
        case 0 :
            color += valve;
            color += t;
            color += p;
            break;
        case 1:
            color += q;
            color += valve;
            color += p;
            break;
        case 2:
            color += p;
            color += valve;
            color += t;
            break;
        case 3:
            color += p;
            color += q;
            color += valve;
            break;
        case 4:
            color += t;
            color += p;
            color += valve;
            break;
        default: // case 5:
            color += valve;
            color += p;
            color += q;
            break;
        }

        return color;
    }

// Determines the background color
    public static Gdk.RGBA get_background_color (string icon_path, Gdk.RGBA? user_color) {
        Gdk.RGBA final_color = {};

        if (user_color != null) {
            final_color = user_color;
        } else {
            var average_color = extract_svg_path_color (icon_path);

            Gdk.RGBA dark_color = {};
            dark_color.parse ("#1d1d1d");

            Gdk.RGBA light_color = {};
            light_color.parse ("#fafafa");

            if (calculate_contrast (average_color, dark_color) > 4.5) {
                final_color = dark_color;
            } else {
                final_color = light_color;
            }
        }

        return final_color;
    }

// Extracts the average color from SVG paths
    public static Gdk.RGBA extract_svg_path_color (string icon_path) {
        Gdk.RGBA average_color = {};
        double total_red = 0.0, total_green = 0.0, total_blue = 0.0, total_alpha = 0.0;
        int path_count = 0;

        try {
            string contents;
            FileUtils.get_contents (icon_path, out contents);

            MarkupParser parser = MarkupParser ();
            MarkupParseContext context = new MarkupParseContext (parser, 0, null, null);

            parser.start_element = (context, element_name, attribute_names, attribute_values) => {
                if (element_name == "path") {
                    for (int i = 0; attribute_names[i] != null; i++) {
                        if (attribute_names[i] == "fill") {
                            Gdk.RGBA path_color = Gdk.RGBA ();
                            if (path_color.parse (attribute_values[i])) {
                                total_red += path_color.red;
                                total_green += path_color.green;
                                total_blue += path_color.blue;
                                total_alpha += path_color.alpha;
                                path_count++;
                            }
                            break;
                        }
                    }
                }
            };

            context.parse (contents, -1);

            if (path_count > 0) {
                average_color.red = (float) (total_red / path_count);
                average_color.green = (float) (total_green / path_count);
                average_color.blue = (float) (total_blue / path_count);
                average_color.alpha = (float) (total_alpha / path_count);
            } else {
                average_color.parse ("#ffffff");
            }
        } catch (Error e) {
            warning ("Error parsing SVG from %s: %s", icon_path, e.message);
            average_color.parse ("#ffffff");
        }

        return average_color;
    }

// Contrast calculation
    public static double calculate_contrast (Gdk.RGBA color1, Gdk.RGBA color2) {
        double luminance1 = calculate_luminance (color1);
        double luminance2 = calculate_luminance (color2);
        double contrast_ratio = (luminance1 > luminance2) ?
            (luminance1 + 0.05) / (luminance2 + 0.05) :
            (luminance2 + 0.05) / (luminance1 + 0.05);
        return Math.round (contrast_ratio * 100.0) / 100.0; // Rounded to 2 decimal places
    }

// Luminance calculation
    public static double calculate_luminance (Gdk.RGBA color) {
        double r = safe_channel ((color.red <= 0.03928) ?
                                 (color.red / 12.92) : Math.pow ((color.red + 0.055) / 1.055, 2.4));
        double g = safe_channel ((color.green <= 0.03928) ?
                                 (color.green / 12.92) : Math.pow ((color.green + 0.055) / 1.055, 2.4));
        double b = safe_channel ((color.blue <= 0.03928) ?
                                 (color.blue / 12.92) : Math.pow ((color.blue + 0.055) / 1.055, 2.4));

        return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    }

    public static double safe_channel (double channel) {
        return (channel <= 0.00001) ? 0.00001 : channel;
    }
}

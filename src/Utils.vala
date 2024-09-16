public class Iconi.Utils {
    public static bool generate_template_svg (string output_path) {
        int canvas_size = 128;
        int margin = 12;
        int icon_size = canvas_size - (2 * margin);

        var surface = new Cairo.SvgSurface (output_path, canvas_size, canvas_size);
        var cr = new Cairo.Context (surface);

        // Set line width
        cr.set_line_width (1);

        // Draw the outer rectangle
        cr.set_source_rgba (1, 0, 0, 0.2);
        draw_rounded_rectangle (cr, margin, margin, icon_size, icon_size, 24);
        cr.stroke ();

        // Draw the grid
        cr.set_source_rgba (0, 0, 0, 0.2);
        draw_rounded_rectangle (cr, margin, margin, icon_size, icon_size, 24);
        cr.clip ();
        cr.save ();
        for (int i = 1; i <= 7; i++) {
            double pos = i * (icon_size / 8.0) + margin;
            // Vertical lines
            cr.move_to (pos, margin);
            cr.line_to (pos, canvas_size - margin);
            // Horizontal lines
            cr.move_to (margin, pos);
            cr.line_to (canvas_size - margin, pos);
            cr.stroke ();
        }
        cr.restore ();

        // Draw the inner rectangles
        cr.set_source_rgba (1, 0, 0, 0.5);
        draw_rounded_rectangle (cr, 23, 23, icon_size - 22, icon_size - 22, 0);
        cr.stroke ();

        cr.set_source_rgba (1, 0, 0, 0.2);
        draw_rounded_rectangle (cr, 40, 40, 48, 48, 0);
        cr.stroke ();

        // Draw the circles
        cr.set_source_rgba (1, 0, 0, 0.5);
        cr.arc (canvas_size / 2, canvas_size / 2, (icon_size - 24) / 2, 0, 2 * Math.PI);
        cr.stroke ();

        cr.set_source_rgba (1, 0, 0, 0.2);
        cr.arc (canvas_size / 2, canvas_size / 2, 24, 0, 2 * Math.PI);
        cr.stroke ();

        // Draw the diagonal line at approximately 12° angle
        cr.set_line_width (6);
        cr.set_source_rgba (1, 0, 0, 0.5);
        cr.move_to (90, 12);
        cr.line_to (60, 128);
        cr.stroke ();

        cr.show_page ();
        surface.finish ();

        return true;
    }

    public static void create_svg_with_icon (string icon_path, bool? frame, bool? dev, string output_path) {
        int canvas_size = 128;
        int background_size = 104;
        int max_icon_size = 128;
        int margin = (canvas_size - background_size) / 2;

        var surface = new Cairo.SvgSurface (output_path, canvas_size, canvas_size);
        var cr = new Cairo.Context (surface);

        // Render the user-provided icon
        try {
            var handle = new Rsvg.Handle.from_file (icon_path);
            if (handle != null) {
                // Get the dimensions of the icon
                Rsvg.Length width, height;
                bool has_width, has_height;
                bool a;
                Rsvg.Rectangle b;
                handle.get_intrinsic_dimensions (out has_width, out width, out has_height, out height, out a, out b);

                double natural_width, natural_height;
                if (has_width && has_height && width.unit == Rsvg.Unit.PX && height.unit == Rsvg.Unit.PX) {
                    natural_width = width.length;
                    natural_height = height.length;
                } else {
                    // Fallback to a default size if dimensions are not available or not in pixels
                    natural_width = natural_height = max_icon_size;
                }

                // Calculate scaling factor to fit icon within max_icon_size
                double scale = Math.fmin ((double) max_icon_size / natural_width, (double) max_icon_size / natural_height);

                // Calculate the actual size after scaling
                double scaled_width = natural_width * scale;
                double scaled_height = natural_height * scale;

                // Calculate position to center the icon
                double x = margin + (background_size - scaled_width) / 2;
                double y = margin + (background_size - scaled_height) / 2;

                // Apply transformations
                cr.save ();
                cr.translate (x, y);
                cr.scale (scale, scale);

                // Render the icon
                var rect = Rsvg.Rectangle () {
                    x = 0,
                    y = 0,
                    width = natural_width,
                    height = natural_height
                };
                handle.render_document (cr, rect);

                // Restore the context
                cr.restore ();
            }
        } catch (Error e) {
            warning ("Error rendering icon: %s", e.message);
        }

        // Render effects (always applied)
        render_svg_resource (cr, "/com/fyralabs/Iconi/effects.svg");

        // Render frame (if enabled)
        if (frame) {
            render_svg_resource (cr, "/com/fyralabs/Iconi/frame.svg");
        }

        // Render developer badge (if enabled)
        if (dev) {
            render_svg_resource (cr, "/com/fyralabs/Iconi/dev.svg");
        }

        cr.show_page ();
        surface.finish ();

        print ("SVG exported as '%s'.\n", output_path);
    }

    private static void render_svg_resource (Cairo.Context cr, string resource_path) {
        try {
            var resource = GLib.resources_lookup_data (resource_path, GLib.ResourceLookupFlags.NONE);
            var handle = new Rsvg.Handle.from_data (resource.get_data ());
            if (handle != null) {
                var rect = Rsvg.Rectangle () {
                    x = 0,
                    y = 0,
                    width = 128,
                    height = 128
                };
                handle.render_document (cr, rect);
            }
        } catch (Error e) {
            warning ("Error rendering SVG resource %s: %s", resource_path, e.message);
        }
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
}

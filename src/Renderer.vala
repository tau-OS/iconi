public class IconRenderer : GLib.Object {
    private const int SVG_VIEWPORT_SIZE = 128;

    private IconModel model;
    private Rsvg.Handle? effects_handle;
    private Rsvg.Handle? frame_handle;
    private Rsvg.Handle? dev_handle;
    private double dev_bounds_x = 0.0;
    private double dev_bounds_y = 0.0;
    private double dev_bounds_width = 128.0;
    private double dev_bounds_height = 128.0;
    private bool dev_bounds_ready = false;

    public IconRenderer (IconModel model) {
        this.model = model;
        load_svg_assets ();
    }

    private void load_svg_assets () {
        effects_handle = load_svg_handle ("/com/fyralabs/Iconi/effects.svg", "effects");
        frame_handle = load_svg_handle ("/com/fyralabs/Iconi/frame.svg", "frame");
        dev_handle = load_svg_handle ("/com/fyralabs/Iconi/dev.svg", "dev");
        if (dev_handle != null) {
            Rsvg.Rectangle ink_rect;
            Rsvg.Rectangle logical_rect;
            try {
                if (dev_handle.get_geometry_for_element (null, out ink_rect, out logical_rect)) {
                    dev_bounds_x = ink_rect.x;
                    dev_bounds_y = ink_rect.y;
                    dev_bounds_width = ink_rect.width;
                    dev_bounds_height = ink_rect.height;
                    dev_bounds_ready = true;
                }
            } catch (GLib.Error geo_err) {
                GLib.warning ("Failed to read dev asset geometry: %s", geo_err.message);
            }
        }
    }

    private Rsvg.Handle? load_svg_handle (string resource_path, string label) {
        try {
            var stream = GLib.resources_open_stream (resource_path, GLib.ResourceLookupFlags.NONE);
            return new Rsvg.Handle.from_stream_sync (stream, null, Rsvg.HandleFlags.FLAGS_NONE, null);
        } catch (GLib.Error load_err) {
            GLib.warning ("Failed to load %s SVG asset: %s", label, load_err.message);
            return null;
        }
    }

    private void draw_rounded_rect_path (Cairo.Context cr, double x, double y, double width, double height, double radius) {
        double limited = GLib.Math.fmin (radius, GLib.Math.fmin (width, height) / 2.0);
        double right = x + width;
        double bottom = y + height;
        double r = limited;
        double pi = GLib.Math.PI;
        cr.new_path ();
        cr.move_to (x + r, y);
        cr.line_to (right - r, y);
        cr.arc (right - r, y + r, r, -pi / 2.0, 0.0);
        cr.line_to (right, bottom - r);
        cr.arc (right - r, bottom - r, r, 0.0, pi / 2.0);
        cr.line_to (x + r, bottom);
        cr.arc (x + r, bottom - r, r, pi / 2.0, pi);
        cr.line_to (x, y + r);
        cr.arc (x + r, y + r, r, pi, 3.0 * pi / 2.0);
        cr.close_path ();
    }

    public void render_icon (Cairo.Context cr, float preview) {
        float cx = (128.0f - preview) / 2.0f;
        float cy = (128.0f - preview) / 2.0f;
        double cx_d = (double) cx;
        double cy_d = (double) cy;
        double preview_d = (double) preview;
        double radius = 24.0;

        // Background
        if (model.use_gradient) {
            double angle_rad = model.gradient_angle * (GLib.Math.PI / 180.0);
            double dx = GLib.Math.cos (angle_rad);
            double dy = GLib.Math.sin (angle_rad);
            double half = preview_d / 2.0;
            double center_x = cx_d + half;
            double center_y = cy_d + half;
            double x0 = center_x - dx * half;
            double y0 = center_y - dy * half;
            double x1 = center_x + dx * half;
            double y1 = center_y + dy * half;
            var pattern = new Cairo.Pattern.linear (x0, y0, x1, y1);
            pattern.add_color_stop_rgba (0.0, model.background.red, model.background.green, model.background.blue, model.background.alpha);
            pattern.add_color_stop_rgba (1.0, model.gradient_secondary.red, model.gradient_secondary.green, model.gradient_secondary.blue, model.gradient_secondary.alpha);
            draw_rounded_rect_path (cr, cx_d, cy_d, preview_d, preview_d, radius);
            cr.set_source (pattern);
            cr.fill ();
        } else {
            float br = (float) model.background.red;
            float bg = (float) model.background.green;
            float bb = (float) model.background.blue;
            float ba = (float) model.background.alpha;
            cr.set_source_rgba (br, bg, bb, ba);
            draw_rounded_rect_path (cr, cx_d, cy_d, preview_d, preview_d, radius);
            cr.fill ();
        }

        // Elements
        int n = (int) model.elements.get_n_items ();
        for (int i = 0; i < n; i++) {
            var el = (IconElement) model.elements.get_item ((uint) i);

            float ex = cx + el.x;
            float ey = cy + el.y;
            float ew = el.width;
            float eh = el.height;

            ex = IconiUtils.clampf (ex, cx, cx + preview);
            ey = IconiUtils.clampf (ey, cy, cy + preview);
            ew = (float) GLib.Math.fmin (ew, (cx + preview) - ex);
            eh = (float) GLib.Math.fmin (eh, (cy + preview) - ey);

            cr.set_operator (IconiUtils.blend_to_operator (el.blend_mode));

            if (el.type == ElementType.RECTANGLE) {
                if (el.use_gradient) {
                    double angle_rad = el.gradient_angle * (GLib.Math.PI / 180.0);
                    double dx = GLib.Math.cos (angle_rad) * (double) ew;
                    double dy = GLib.Math.sin (angle_rad) * (double) eh;
                    var pattern = new Cairo.Pattern.linear (ex, ey, ex + dx, ey + dy);
                    pattern.add_color_stop_rgba (0.0, el.fill.red, el.fill.green, el.fill.blue, el.fill.alpha);
                    pattern.add_color_stop_rgba (1.0, el.gradient_secondary.red, el.gradient_secondary.green, el.gradient_secondary.blue, el.gradient_secondary.alpha);
                    cr.rectangle (ex, ey, ew, eh);
                    cr.set_source (pattern);
                    cr.fill_preserve ();
                } else {
                    float fr = (float) el.fill.red;
                    float fg = (float) el.fill.green;
                    float fb = (float) el.fill.blue;
                    float fa = (float) el.fill.alpha;
                    cr.set_source_rgba (fr, fg, fb, fa);
                    cr.rectangle (ex, ey, ew, eh);
                    cr.fill_preserve ();
                }
                float sr1 = (float) el.stroke.red;
                float sg1 = (float) el.stroke.green;
                float sb1 = (float) el.stroke.blue;
                float sa1 = (float) el.stroke.alpha;
                cr.set_source_rgba (sr1, sg1, sb1, sa1);
                cr.set_line_width (el.stroke_width);
                cr.stroke ();
            } else if (el.type == ElementType.CIRCLE) {
                double scale_x = ew / 2.0;
                double scale_y = eh / 2.0;
                double line_scale = (GLib.Math.fabs (scale_x) + GLib.Math.fabs (scale_y)) / 2.0;
                if (line_scale <= 0.0)line_scale = 1.0;
                cr.save ();
                cr.translate (ex + ew / 2.0f, ey + eh / 2.0f);
                cr.scale (scale_x, scale_y);
                cr.new_path ();
                cr.arc (0.0, 0.0, 1.0, 0.0, 2.0 * (float) GLib.Math.PI);
                if (el.use_gradient) {
                    double angle_rad = el.gradient_angle * (GLib.Math.PI / 180.0);
                    double dx = GLib.Math.cos (angle_rad);
                    double dy = GLib.Math.sin (angle_rad);
                    var pattern = new Cairo.Pattern.linear (-dx, -dy, dx, dy);
                    pattern.add_color_stop_rgba (0.0, el.fill.red, el.fill.green, el.fill.blue, el.fill.alpha);
                    pattern.add_color_stop_rgba (1.0, el.gradient_secondary.red, el.gradient_secondary.green, el.gradient_secondary.blue, el.gradient_secondary.alpha);
                    cr.set_source (pattern);
                } else {
                    float fr = (float) el.fill.red;
                    float fg = (float) el.fill.green;
                    float fb = (float) el.fill.blue;
                    float fa = (float) el.fill.alpha;
                    cr.set_source_rgba (fr, fg, fb, fa);
                }
                cr.fill_preserve ();
                float sr1 = (float) el.stroke.red;
                float sg1 = (float) el.stroke.green;
                float sb1 = (float) el.stroke.blue;
                float sa1 = (float) el.stroke.alpha;
                cr.set_source_rgba (sr1, sg1, sb1, sa1);
                cr.set_line_width (el.stroke_width / line_scale);
                cr.stroke ();
                cr.restore ();
            } else if (el.type == ElementType.LINE) {
                if (el.use_gradient) {
                    var pattern = new Cairo.Pattern.linear (ex, ey, ex + ew, ey + eh);
                    pattern.add_color_stop_rgba (0.0, el.stroke.red, el.stroke.green, el.stroke.blue, el.stroke.alpha);
                    pattern.add_color_stop_rgba (1.0, el.gradient_secondary.red, el.gradient_secondary.green, el.gradient_secondary.blue, el.gradient_secondary.alpha);
                    cr.set_source (pattern);
                } else {
                    float sr = (float) el.stroke.red;
                    float sg = (float) el.stroke.green;
                    float sb = (float) el.stroke.blue;
                    float sa = (float) el.stroke.alpha;
                    cr.set_source_rgba (sr, sg, sb, sa);
                }
                cr.set_line_width (el.stroke_width);
                cr.move_to (ex, ey);
                cr.line_to (ex + ew, ey + eh);
                cr.stroke ();
            }

            cr.set_operator (Cairo.Operator.OVER);
        }

        if (model.use_frame_overlay) {
            render_svg_overlay (cr, frame_handle, cx, cy, preview);
        }
        if (model.show_dev_badge) {
            render_dev_badge (cr, cx, cy, preview);
        }
        if (model.use_raised_effect) {
            render_svg_overlay (cr, effects_handle, cx, cy, preview);
        }
    }

    private void render_svg_overlay (Cairo.Context cr, Rsvg.Handle? handle, float cx, float cy, float preview) {
        if (handle == null)return;
        double preview_d = preview;
        double scale = preview_d / SVG_VIEWPORT_SIZE;
        cr.save ();
        cr.translate ((double) cx, (double) cy);
        cr.scale (scale, scale);
        render_svg_document (handle, cr, "overlay");
        cr.restore ();
    }

    private void render_dev_badge (Cairo.Context cr, float cx, float cy, float preview) {
        if (dev_handle == null)return;
        render_svg_overlay (cr, dev_handle, cx, cy, preview);
    }

    private void render_svg_document (Rsvg.Handle handle, Cairo.Context cr, string label) {
        try {
            Rsvg.Rectangle viewport = {};
            viewport.x = 0.0;
            viewport.y = 0.0;
            viewport.width = SVG_VIEWPORT_SIZE;
            viewport.height = SVG_VIEWPORT_SIZE;
            handle.render_document (cr, viewport);
        } catch (GLib.Error render_err) {
            GLib.warning ("Failed to render %s SVG: %s", label, render_err.message);
        }
    }
}
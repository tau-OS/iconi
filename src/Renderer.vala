public class IconRenderer : GLib.Object {
    private const int SVG_VIEWPORT_SIZE = 128;
    private const double SAFE_VIEW_SIZE = 109.0;

    private IconModel model;
    private Rsvg.Handle? effects_handle;
    private Rsvg.Handle? frame_handle;
    private Rsvg.Handle? dev_handle;
    private Rsvg.Handle? grid_dark_handle;
    private Rsvg.Handle? grid_light_handle;
    private double dev_bounds_x = 0.0;
    private double dev_bounds_y = 0.0;
    private double dev_bounds_width = 128.0;
    private double dev_bounds_height = 128.0;
    private bool dev_bounds_ready = false;
    private double dev_view_width = SAFE_VIEW_SIZE;
    private double dev_view_height = SAFE_VIEW_SIZE;
    private bool dev_view_ready = false;

    public IconRenderer (IconModel model) {
        this.model = model;
        load_svg_assets ();
    }

    private void load_svg_assets () {
        effects_handle = load_svg_handle ("/com/fyralabs/Iconi/effects.svg", "effects");
        frame_handle = load_svg_handle ("/com/fyralabs/Iconi/frame.svg", "frame");
        dev_handle = load_svg_handle ("/com/fyralabs/Iconi/dev.svg", "dev");
        grid_dark_handle = load_svg_handle ("/com/fyralabs/Iconi/grid-dark.svg", "grid dark");
        grid_light_handle = load_svg_handle ("/com/fyralabs/Iconi/grid-light.svg", "grid light");
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
                    if (logical_rect.width > 0.0 && logical_rect.height > 0.0) {
                        dev_view_width = logical_rect.width;
                        dev_view_height = logical_rect.height;
                        dev_view_ready = true;
                    }
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
        cr.new_path ();
        IconiUtils.append_rounded_rect (cr, x, y, width, height, radius, radius, radius, radius);
    }

    private void append_element_path (Cairo.Context cr, IconElement element, double x, double y, double width, double height, double expand = 0.0, bool reset_path = true) {
        if (reset_path) {
            cr.new_path ();
        }
        if (element.type == ElementType.RECTANGLE) {
            double rect_x = x - expand;
            double rect_y = y - expand;
            double rect_width = width + expand * 2.0;
            double rect_height = height + expand * 2.0;
            double corner_tl = element.corner_radius_top_left + expand;
            double corner_tr = element.corner_radius_top_right + expand;
            double corner_br = element.corner_radius_bottom_right + expand;
            double corner_bl = element.corner_radius_bottom_left + expand;
            IconiUtils.append_rounded_rect (cr, rect_x, rect_y, rect_width, rect_height, corner_tl, corner_tr, corner_br, corner_bl);
        } else if (element.type == ElementType.CIRCLE) {
            double center_x = x + width / 2.0;
            double center_y = y + height / 2.0;
            double radius_x = (width / 2.0) + expand;
            double radius_y = (height / 2.0) + expand;
            radius_x = GLib.Math.fmax (radius_x, 0.0);
            radius_y = GLib.Math.fmax (radius_y, 0.0);
            cr.new_sub_path ();
            cr.save ();
            cr.translate (center_x, center_y);
            cr.scale (radius_x, radius_y);
            cr.arc (0.0, 0.0, 1.0, 0.0, 2.0 * GLib.Math.PI);
            cr.restore ();
        }
    }

    private void update_bounds (ref bool initialized, ref double min_x, ref double min_y, ref double max_x, ref double max_y, double px, double py) {
        if (!initialized) {
            min_x = px;
            max_x = px;
            min_y = py;
            max_y = py;
            initialized = true;
            return;
        }
        min_x = GLib.Math.fmin (min_x, px);
        min_y = GLib.Math.fmin (min_y, py);
        max_x = GLib.Math.fmax (max_x, px);
        max_y = GLib.Math.fmax (max_y, py);
    }

    private bool build_group_path (Cairo.Context cr, ElementGroup group, float cx, float cy, float preview, double expand, double offset_x, double offset_y, out Cairo.Path? path, out double min_x, out double min_y, out double max_x, out double max_y, out double color_r, out double color_g, out double color_b, out int color_samples) {
        path = null;
        min_x = 0.0;
        min_y = 0.0;
        max_x = 0.0;
        max_y = 0.0;
        color_r = 0.0;
        color_g = 0.0;
        color_b = 0.0;
        color_samples = 0;

        bool bounds_initialized = false;
        bool has_path = false;

        int ne = (int) group.elements.get_n_items ();
        float max_xf = cx + preview;
        float max_yf = cy + preview;

        cr.save ();
        cr.new_path ();

        for (int i = 0; i < ne; i++) {
            var el = (IconElement) group.elements.get_item ((uint) i);
            if (el.type != ElementType.RECTANGLE && el.type != ElementType.CIRCLE) {
                continue;
            }

            float ex = cx + el.x;
            float ey = cy + el.y;
            float ew = el.width;
            float eh = el.height;

            ex = IconiUtils.clampf (ex, cx, max_xf);
            ey = IconiUtils.clampf (ey, cy, max_yf);
            ew = (float) GLib.Math.fmin (ew, max_xf - ex);
            eh = (float) GLib.Math.fmin (eh, max_yf - ey);

            if (ew <= 0.0f || eh <= 0.0f) {
                continue;
            }

            double ex_d = ex;
            double ey_d = ey;
            double ew_d = ew;
            double eh_d = eh;

            cr.save ();
            cr.translate (offset_x, offset_y);
            if (el.element_angle != 0.0) {
                double center_x = ex_d + ew_d / 2.0;
                double center_y = ey_d + eh_d / 2.0;
                cr.translate (center_x, center_y);
                cr.rotate (el.element_angle * (GLib.Math.PI / 180.0));
                cr.translate (-center_x, -center_y);
            }
            append_element_path (cr, el, ex_d, ey_d, ew_d, eh_d, expand, false);
            cr.restore ();

            bool rotated = (el.element_angle != 0.0);
            double angle_rad = rotated ? el.element_angle * (GLib.Math.PI / 180.0) : 0.0;
            double cos_a = rotated ? GLib.Math.cos (angle_rad) : 1.0;
            double sin_a = rotated ? GLib.Math.sin (angle_rad) : 0.0;
            double center_x_global = ex_d + ew_d / 2.0 + offset_x;
            double center_y_global = ey_d + eh_d / 2.0 + offset_y;

            if (el.type == ElementType.RECTANGLE) {
                double base_x = ex_d - expand;
                double base_y = ey_d - expand;
                double base_w = ew_d + expand * 2.0;
                double base_h = eh_d + expand * 2.0;
                double[] corner_x = { base_x, base_x + base_w, base_x + base_w, base_x };
                double[] corner_y = { base_y, base_y, base_y + base_h, base_y + base_h };
                for (int corner_idx = 0; corner_idx < 4; corner_idx++) {
                    double px = corner_x[corner_idx] + offset_x;
                    double py = corner_y[corner_idx] + offset_y;
                    if (rotated) {
                        double dx = px - center_x_global;
                        double dy = py - center_y_global;
                        double rot_x = center_x_global + dx * cos_a - dy * sin_a;
                        double rot_y = center_y_global + dx * sin_a + dy * cos_a;
                        px = rot_x;
                        py = rot_y;
                    }
                    update_bounds (ref bounds_initialized, ref min_x, ref min_y, ref max_x, ref max_y, px, py);
                }
            } else {
                double rx = (ew_d / 2.0) + expand;
                double ry = (eh_d / 2.0) + expand;
                rx = GLib.Math.fmax (rx, 0.0);
                ry = GLib.Math.fmax (ry, 0.0);
                double half_w;
                double half_h;
                if (rotated) {
                    double abs_cos = GLib.Math.fabs (cos_a);
                    double abs_sin = GLib.Math.fabs (sin_a);
                    double rx_cos = rx * abs_cos;
                    double ry_sin = ry * abs_sin;
                    double rx_sin = rx * abs_sin;
                    double ry_cos = ry * abs_cos;
                    half_w = GLib.Math.sqrt ((rx_cos * rx_cos) + (ry_sin * ry_sin));
                    half_h = GLib.Math.sqrt ((rx_sin * rx_sin) + (ry_cos * ry_cos));
                } else {
                    half_w = rx;
                    half_h = ry;
                }
                double left = center_x_global - half_w;
                double right = center_x_global + half_w;
                double top = center_y_global - half_h;
                double bottom = center_y_global + half_h;
                update_bounds (ref bounds_initialized, ref min_x, ref min_y, ref max_x, ref max_y, left, top);
                update_bounds (ref bounds_initialized, ref min_x, ref min_y, ref max_x, ref max_y, right, top);
                update_bounds (ref bounds_initialized, ref min_x, ref min_y, ref max_x, ref max_y, right, bottom);
                update_bounds (ref bounds_initialized, ref min_x, ref min_y, ref max_x, ref max_y, left, bottom);
            }

            color_r += el.fill.red;
            color_g += el.fill.green;
            color_b += el.fill.blue;
            color_samples++;

            has_path = true;
        }

        if (has_path) {
            path = cr.copy_path ();
        } else {
            path = null;
        }
        cr.restore ();

        return has_path;
    }

    private void render_group_shadow (Cairo.Context cr, ElementGroup group, float cx, float cy, float preview, bool combined_effect) {
        bool combined_done = false;
        if (combined_effect) {
            combined_done = render_group_shadow_combined (cr, group, cx, cy, preview);
        }
        if (combined_done) {
            render_group_shadow_individual (cr, group, cx, cy, preview, true);
        } else {
            render_group_shadow_individual (cr, group, cx, cy, preview, false);
        }
    }

    private void render_group_shadow_individual (Cairo.Context cr, ElementGroup group, float cx, float cy, float preview, bool skip_rectangles_and_circles) {
        int ne = (int) group.elements.get_n_items ();
        float max_x = cx + preview;
        float max_y = cy + preview;

        for (int blur_pass = 0; blur_pass < 3; blur_pass++) {
            cr.save ();
            double blur_spread = blur_pass * 2.0;
            double blur_alpha = 0.32 / 3.0;

            for (int i = 0; i < ne; i++) {
                var el = (IconElement) group.elements.get_item ((uint) i);
                if (skip_rectangles_and_circles && (el.type == ElementType.RECTANGLE || el.type == ElementType.CIRCLE)) {
                    continue;
                }

                float ex = cx + el.x;
                float ey = cy + el.y;
                float ew = el.width;
                float eh = el.height;

                ex = IconiUtils.clampf (ex, cx, max_x);
                ey = IconiUtils.clampf (ey, cy, max_y);
                ew = (float) GLib.Math.fmin (ew, max_x - ex);
                eh = (float) GLib.Math.fmin (eh, max_y - ey);

                bool is_line = (el.type == ElementType.LINE);
                if (!is_line && (ew <= 0.0f || eh <= 0.0f)) {
                    continue;
                }

                cr.save ();
                cr.translate (0, 4);

                if (el.element_angle != 0.0) {
                    double center_x = ex + ew / 2.0;
                    double center_y = ey + eh / 2.0;
                    cr.translate (center_x, center_y);
                    cr.rotate (el.element_angle * (GLib.Math.PI / 180.0));
                    cr.translate (-center_x, -center_y);
                }

                if (el.type == ElementType.RECTANGLE || el.type == ElementType.CIRCLE) {
                    append_element_path (cr, el, ex, ey, ew, eh, blur_spread);
                } else if (el.type == ElementType.LINE) {
                    cr.move_to (ex, ey);
                    cr.line_to (ex + ew, ey + eh);
                }

                if (group.shadow_chromatic) {
                    double sr = el.fill.red * 0.5;
                    double sg = el.fill.green * 0.5;
                    double sb = el.fill.blue * 0.5;
                    cr.set_source_rgba (sr, sg, sb, blur_alpha);
                } else {
                    cr.set_source_rgba (0.0, 0.0, 0.0, blur_alpha);
                }

                if (el.type == ElementType.LINE) {
                    cr.set_line_width (el.stroke_width + blur_spread);
                    cr.stroke ();
                } else {
                    cr.fill ();
                }

                cr.restore ();
            }

            cr.restore ();
        }
    }

    private bool render_group_shadow_combined (Cairo.Context cr, ElementGroup group, float cx, float cy, float preview) {
        bool any = false;

        for (int blur_pass = 0; blur_pass < 3; blur_pass++) {
            Cairo.Path? path;
            double min_x;
            double min_y;
            double max_x;
            double max_y;
            double color_r;
            double color_g;
            double color_b;
            int color_samples;

            double expand = blur_pass * 2.0;
            double offset_x = 0.0;
            double offset_y = 4.0;
            bool has_path = build_group_path (cr, group, cx, cy, preview, expand, offset_x, offset_y, out path, out min_x, out min_y, out max_x, out max_y, out color_r, out color_g, out color_b, out color_samples);
            if (!has_path || path == null) {
                continue;
            }

            if (max_x <= min_x || max_y <= min_y) {
                continue;
            }

            any = true;
            double blur_alpha = 0.32 / 3.0;

            cr.save ();
            cr.append_path (path);
            if (group.shadow_chromatic && color_samples > 0) {
                double sr = GLib.Math.fmin ((color_r / (double) color_samples) * 0.5, 1.0);
                double sg = GLib.Math.fmin ((color_g / (double) color_samples) * 0.5, 1.0);
                double sb = GLib.Math.fmin ((color_b / (double) color_samples) * 0.5, 1.0);
                cr.set_source_rgba (sr, sg, sb, blur_alpha);
            } else {
                cr.set_source_rgba (0.0, 0.0, 0.0, blur_alpha);
            }
            cr.fill ();
            cr.restore ();
        }

        return any;
    }

    private void render_group_raised_effect (Cairo.Context cr, ElementGroup group, float cx, float cy, float preview, bool combined_effect) {
        bool combined_done = false;
        if (combined_effect) {
            combined_done = render_group_raised_effect_combined (cr, group, cx, cy, preview);
        }
        if (!combined_done) {
            render_group_raised_effect_individual (cr, group, cx, cy, preview);
        }
    }

    private void render_group_raised_effect_individual (Cairo.Context cr, ElementGroup group, float cx, float cy, float preview) {
        int ne = (int) group.elements.get_n_items ();
        float max_x = cx + preview;
        float max_y = cy + preview;

        cr.save ();
        for (int i = 0; i < ne; i++) {
            var el = (IconElement) group.elements.get_item ((uint) i);
            if (el.type == ElementType.LINE || el.type == ElementType.SVG) {
                continue;
            }

            float ex = cx + el.x;
            float ey = cy + el.y;
            float ew = el.width;
            float eh = el.height;

            ex = IconiUtils.clampf (ex, cx, max_x);
            ey = IconiUtils.clampf (ey, cy, max_y);
            ew = (float) GLib.Math.fmin (ew, max_x - ex);
            eh = (float) GLib.Math.fmin (eh, max_y - ey);

            if (ew <= 0.0f || eh <= 0.0f) {
                continue;
            }

            double ex_d = ex;
            double ey_d = ey;
            double ew_d = ew;
            double eh_d = eh;
            double center_x = ex_d + ew_d / 2.0;
            double center_y = ey_d + eh_d / 2.0;

            cr.save ();
            if (el.element_angle != 0.0) {
                cr.translate (center_x, center_y);
                cr.rotate (el.element_angle * (GLib.Math.PI / 180.0));
                cr.translate (-center_x, -center_y);
            }

            // Create raised effect as a 2px stroke with linear gradient from top to bottom
            if (eh_d > 0.0) {
                double white_end = 4.0 / eh_d;
                double black_start = 1.0 - (4.0 / eh_d);

                var gradient = new Cairo.Pattern.linear (ex_d, ey_d, ex_d, ey_d + eh_d);
                gradient.set_extend (Cairo.Extend.PAD);
                gradient.add_color_stop_rgba (0.0, 1.0, 1.0, 1.0, 0.4);
                gradient.add_color_stop_rgba (white_end, 1.0, 1.0, 1.0, 0.4);
                gradient.add_color_stop_rgba (0.5, 0.0, 0.0, 0.0, 0.0);
                gradient.add_color_stop_rgba (black_start, 0.0, 0.0, 0.0, 0.2);
                gradient.add_color_stop_rgba (1.0, 0.0, 0.0, 0.0, 0.2);

                cr.set_source (gradient);
                append_element_path (cr, el, ex_d, ey_d, ew_d, eh_d);
                cr.set_line_width (2.0);
                cr.stroke ();
            }

            cr.restore ();
            cr.restore ();
        }
        cr.restore ();
    }

    private bool render_group_raised_effect_combined (Cairo.Context cr, ElementGroup group, float cx, float cy, float preview) {
        Cairo.Path? path;
        double min_x;
        double min_y;
        double max_x;
        double max_y;
        double color_r;
        double color_g;
        double color_b;
        int color_samples;
        bool has_path = build_group_path (cr, group, cx, cy, preview, 0.0, 0.0, 0.0, out path, out min_x, out min_y, out max_x, out max_y, out color_r, out color_g, out color_b, out color_samples);
        if (!has_path || path == null) {
            return false;
        }

        if (color_samples < 0) {
            color_r = color_g = color_b;
        }

        double width = max_x - min_x;
        double height = max_y - min_y;
        if (width <= 0.0 || height <= 0.0) {
            return false;
        }

        // Create raised effect as a 2px stroke with linear gradient from top to bottom
        cr.save ();

        if (height > 0.0) {
            double white_end = 4.0 / height;
            double black_start = 1.0 - (4.0 / height);

            var gradient = new Cairo.Pattern.linear (min_x, min_y, min_x, max_y);
            gradient.set_extend (Cairo.Extend.PAD);
            gradient.add_color_stop_rgba (0.0, 1.0, 1.0, 1.0, 0.4);
            gradient.add_color_stop_rgba (white_end, 1.0, 1.0, 1.0, 0.4);
            gradient.add_color_stop_rgba (0.5, 0.0, 0.0, 0.0, 0.0);
            gradient.add_color_stop_rgba (black_start, 0.0, 0.0, 0.0, 0.2);
            gradient.add_color_stop_rgba (1.0, 0.0, 0.0, 0.0, 0.2);

            cr.set_source (gradient);
            cr.append_path (path);
            cr.set_line_width (2.0);
            cr.stroke ();
        }

        cr.restore ();
        return true;
    }

    public void render_icon (Cairo.Context cr, float preview) {
        float canvas_size = SVG_VIEWPORT_SIZE;
        float cx = (canvas_size - preview) / 2.0f;
        float cy = (canvas_size - preview) / 2.0f;
        double preview_ratio = preview / SAFE_VIEW_SIZE;
        double radius = 24.0;

        // Background
        if (model.use_gradient) {
            double angle_rad = model.gradient_angle * (GLib.Math.PI / 180.0);
            double dx = GLib.Math.cos (angle_rad);
            double dy = GLib.Math.sin (angle_rad);
            double half = preview / 2.0;
            double center_x = cx + half;
            double center_y = cy + half;
            double x0 = center_x - dx * half;
            double y0 = center_y - dy * half;
            double x1 = center_x + dx * half;
            double y1 = center_y + dy * half;
            var pattern = new Cairo.Pattern.linear (x0, y0, x1, y1);
            pattern.add_color_stop_rgba (0.0, model.background.red, model.background.green, model.background.blue, model.background.alpha);
            pattern.add_color_stop_rgba (1.0, model.gradient_secondary.red, model.gradient_secondary.green, model.gradient_secondary.blue, model.gradient_secondary.alpha);
            draw_rounded_rect_path (cr, cx, cy, preview, preview, radius);
            cr.set_source (pattern);
            cr.fill ();
        } else {
            float br = (float) model.background.red;
            float bg = (float) model.background.green;
            float bb = (float) model.background.blue;
            float ba = (float) model.background.alpha;
            cr.set_source_rgba (br, bg, bb, ba);
            draw_rounded_rect_path (cr, cx, cy, preview, preview, radius);
            cr.fill ();
        }

        // Constrain all subsequent drawing to the icon surface
        cr.save ();
        draw_rounded_rect_path (cr, cx, cy, preview, preview, radius);
        cr.clip ();

        // Elements
        int ng = (int) model.groups.get_n_items ();
        for (int g = 0; g < ng; g++) {
            var group = (ElementGroup) model.groups.get_item ((uint) g);
            cr.set_operator (IconiUtils.blend_to_operator (group.blend_mode));

            int ne = (int) group.elements.get_n_items ();
            bool combined_effect = (group.effect_scope == GroupEffectScope.COMBINED);

            if (group.use_shadow) {
                render_group_shadow (cr, group, cx, cy, preview, combined_effect);
            }

            // Render elements
            for (int i = 0; i < ne; i++) {
                var el = (IconElement) group.elements.get_item ((uint) i);

                float ex = cx + el.x;
                float ey = cy + el.y;
                float ew = el.width;
                float eh = el.height;

                ex = IconiUtils.clampf (ex, cx, cx + preview);
                ey = IconiUtils.clampf (ey, cy, cy + preview);
                ew = (float) GLib.Math.fmin (ew, (cx + preview) - ex);
                eh = (float) GLib.Math.fmin (eh, (cy + preview) - ey);

                cr.save ();
                if (el.element_angle != 0.0) {
                    double center_x = ex + ew / 2.0;
                    double center_y = ey + eh / 2.0;
                    cr.translate (center_x, center_y);
                    cr.rotate (el.element_angle * (GLib.Math.PI / 180.0));
                    cr.translate (-center_x, -center_y);
                }

                if (el.type == ElementType.RECTANGLE) {
                    append_element_path (cr, el, ex, ey, ew, eh);
                    if (el.use_gradient) {
                        double angle_rad = el.gradient_angle * (GLib.Math.PI / 180.0);
                        double dx = GLib.Math.cos (angle_rad) * (double) ew;
                        double dy = GLib.Math.sin (angle_rad) * (double) eh;
                        var pattern = new Cairo.Pattern.linear (ex, ey, ex + dx, ey + dy);
                        pattern.add_color_stop_rgba (0.0, el.fill.red, el.fill.green, el.fill.blue, el.fill.alpha);
                        pattern.add_color_stop_rgba (1.0, el.gradient_secondary.red, el.gradient_secondary.green, el.gradient_secondary.blue, el.gradient_secondary.alpha);
                        cr.set_source (pattern);
                        cr.fill_preserve ();
                    } else {
                        float fr = (float) el.fill.red;
                        float fg = (float) el.fill.green;
                        float fb = (float) el.fill.blue;
                        float fa = (float) el.fill.alpha;
                        cr.set_source_rgba (fr, fg, fb, fa);
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
                } else if (el.type == ElementType.SVG) {
                    try {
                        var svg_handle = new Rsvg.Handle.from_data (el.svg_data.data);
                        var viewport = Rsvg.Rectangle ();
                        viewport.x = ex;
                        viewport.y = ey;
                        viewport.width = ew;
                        viewport.height = eh;
                        svg_handle.render_document (cr, viewport);
                    } catch (Error e) {
                        warning ("Failed to render SVG: %s", e.message);
                    }
                }

                cr.restore ();
            }

            if (group.use_raised_effect) {
                render_group_raised_effect (cr, group, cx, cy, preview, combined_effect);
            }

            cr.set_operator (Cairo.Operator.OVER);
        }

        if (model.use_frame_overlay) {
            render_canvas_overlay (cr, frame_handle, preview_ratio, (double) cx, (double) cy);
        }
        if (model.show_dev_badge) {
            render_dev_badge (cr, preview_ratio);
        }
        if (model.use_raised_effect) {
            render_canvas_overlay (cr, effects_handle, preview_ratio, (double) cx, (double) cy);
        }
        if (model.show_grid_overlay) {
            Rsvg.Handle? grid_handle = model.grid_overlay_variant == GridOverlayVariant.DARK ? grid_dark_handle : grid_light_handle;
            render_grid_overlay (cr, grid_handle, cx, cy, preview);
        }

        cr.restore ();
    }

    private void render_canvas_overlay (Cairo.Context cr, Rsvg.Handle? handle, double scale, double offset_x, double offset_y) {
        if (handle == null)return;
        cr.save ();
        cr.translate (offset_x, offset_y);
        if (scale != 1.0) {
            cr.scale (scale, scale);
        }
        render_svg_document (handle, cr, "overlay");
        cr.restore ();
    }

    private void render_dev_badge (Cairo.Context cr, double preview_ratio) {
        if (dev_handle == null)return;
        double scale = preview_ratio;
        double target_x = 5.0;
        double target_y = 68.0;
        double logical_x = dev_bounds_ready ? dev_bounds_x : 0.0;
        double logical_y = dev_bounds_ready ? dev_bounds_y : 0.0;

        cr.save ();
        if (scale != 1.0) {
            cr.scale (scale, scale);
        }

        double inv_scale = (scale != 0.0) ? 1.0 / scale : 1.0;
        double scaled_target_x = target_x * inv_scale;
        double scaled_target_y = target_y * inv_scale;
        cr.translate (scaled_target_x - logical_x, scaled_target_y - logical_y);
        render_svg_document (dev_handle, cr, "dev overlay");
        cr.restore ();
    }

    private void render_grid_overlay (Cairo.Context cr, Rsvg.Handle? handle, float cx, float cy, float preview) {
        if (handle == null)return;
        double scale = preview / SAFE_VIEW_SIZE;
        cr.save ();
        cr.translate ((double) cx, (double) cy);
        if (scale != 1.0) {
            cr.scale (scale, scale);
        }
        render_svg_document (handle, cr, "grid overlay");
        cr.restore ();
    }

    private void render_svg_document (Rsvg.Handle handle, Cairo.Context cr, string label) {
        double width = SAFE_VIEW_SIZE;
        double height = SAFE_VIEW_SIZE;
        Rsvg.Rectangle ink_rect;
        Rsvg.Rectangle logical_rect;

        try {
            if (handle.get_geometry_for_element (null, out ink_rect, out logical_rect)) {
                if (logical_rect.width > 0.0 && logical_rect.height > 0.0) {
                    width = logical_rect.width;
                    height = logical_rect.height;
                }
            }
        } catch (GLib.Error geom_err) {
            GLib.debug ("Failed to read %s geometry: %s", label, geom_err.message);
        }

        try {
            Rsvg.Rectangle viewport = {};
            viewport.x = 0.0;
            viewport.y = 0.0;
            viewport.width = width;
            viewport.height = height;
            handle.render_document (cr, viewport);
        } catch (GLib.Error render_err) {
            GLib.warning ("Failed to render %s SVG: %s", label, render_err.message);
        }
    }
}
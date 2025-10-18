namespace IconiUtils {
    public float clampf (float v, float min, float max) {
        if (v < min)return min;
        if (v > max)return max;
        return v;
    }

    public double clamp01 (double value) {
        return GLib.Math.fmax (0.0, GLib.Math.fmin (value, 1.0));
    }

    public Cairo.Operator blend_to_operator (string blend) {
        switch (blend) {
        case "normal": return Cairo.Operator.OVER;
        case "multiply": return Cairo.Operator.MULTIPLY;
        case "screen": return Cairo.Operator.SCREEN;
        case "overlay": return Cairo.Operator.OVERLAY;
        case "darken": return Cairo.Operator.DARKEN;
        case "lighten": return Cairo.Operator.LIGHTEN;
        case "color-dodge": return Cairo.Operator.COLOR_DODGE;
        case "color-burn": return Cairo.Operator.COLOR_BURN;
        case "hard-light": return Cairo.Operator.HARD_LIGHT;
        case "soft-light": return Cairo.Operator.SOFT_LIGHT;
        case "difference": return Cairo.Operator.DIFFERENCE;
        case "exclusion": return Cairo.Operator.EXCLUSION;
        case "hue": return Cairo.Operator.HSL_HUE;
        case "saturation": return Cairo.Operator.HSL_SATURATION;
        case "color": return Cairo.Operator.HSL_COLOR;
        case "luminosity": return Cairo.Operator.HSL_LUMINOSITY;
        }
        return Cairo.Operator.OVER;
    }

    public Gdk.RGBA parse_hex_color (string hex) {
        Gdk.RGBA color = { 0 };
        color.parse (hex);
        return color;
    }

    public Gdk.RGBA mix_with_white (Gdk.RGBA base_color, double factor) {
        double t = clamp01 (factor);
        Gdk.RGBA result = base_color;
        result.red = (float) clamp01 (base_color.red + (1.0 - base_color.red) * t);
        result.green = (float) clamp01 (base_color.green + (1.0 - base_color.green) * t);
        result.blue = (float) clamp01 (base_color.blue + (1.0 - base_color.blue) * t);
        result.alpha = base_color.alpha;
        return result;
    }

    public Gdk.RGBA mix_with_black (Gdk.RGBA base_color, double factor) {
        double t = clamp01 (factor);
        Gdk.RGBA result = base_color;
        result.red = (float) clamp01 (base_color.red + (0.0 - base_color.red) * t);
        result.green = (float) clamp01 (base_color.green + (0.0 - base_color.green) * t);
        result.blue = (float) clamp01 (base_color.blue + (0.0 - base_color.blue) * t);
        result.alpha = base_color.alpha;
        return result;
    }

    public double compute_relative_luminance (Gdk.RGBA color) {
        double alpha = GLib.Math.fmax (0.0, GLib.Math.fmin (color.alpha, 1.0));
        double based = 1.0;
        double r = blend_channel (color.red, alpha, based);
        double g = blend_channel (color.green, alpha, based);
        double b = blend_channel (color.blue, alpha, based);
        double rl = srgb_to_linear (r);
        double gl = srgb_to_linear (g);
        double bl = srgb_to_linear (b);
        return 0.2126 * rl + 0.7152 * gl + 0.0722 * bl;
    }

    public double blend_channel (double value, double alpha, double based) {
        return value * alpha + based * (1.0 - alpha);
    }

    public double srgb_to_linear (double component) {
        if (component <= 0.04045)return component / 12.92;
        double adjusted = (component + 0.055) / 1.055;
        return GLib.Math.pow (adjusted, 2.4);
    }

    public double contrast_ratio (double luminance_a, double luminance_b) {
        double lighter = GLib.Math.fmax (luminance_a, luminance_b);
        double darker = GLib.Math.fmin (luminance_a, luminance_b);
        return (lighter + 0.05) / (darker + 0.05);
    }

    public string escape_css_url (string uri) {
        string escaped = uri.replace ("\\", "\\\\");
        escaped = escaped.replace ("\"", "\\\"");
        return escaped;
    }

    public string ? normalize_wallpaper_entry (string value) {
        if (value.length == 0)return null;
        if (value == "none")return null;
        if (value == "solid-color")return null;
        if (value == "color-shading")return null;
        return value;
    }

    public string rgba_to_hex (Gdk.RGBA color) {
        int r = (int) Math.floor (color.red * 255.0);
        int g = (int) Math.floor (color.green * 255.0);
        int b = (int) Math.floor (color.blue * 255.0);
        return "#%02x%02x%02x".printf (r, g, b);
    }

    private void adjust_corner_pair (ref double first, ref double second, double limit) {
        if (limit <= 0.0) {
            first = 0.0;
            second = 0.0;
            return;
        }
        double sum = first + second;
        if (sum > limit && sum > 0.0) {
            double scale = limit / sum;
            first *= scale;
            second *= scale;
        }
    }

    public void normalize_corner_radii (ref double top_left, ref double top_right, ref double bottom_right, ref double bottom_left, double width, double height) {
        if (width <= 0.0 || height <= 0.0) {
            top_left = 0.0;
            top_right = 0.0;
            bottom_right = 0.0;
            bottom_left = 0.0;
            return;
        }

        top_left = GLib.Math.fmax (top_left, 0.0);
        top_right = GLib.Math.fmax (top_right, 0.0);
        bottom_right = GLib.Math.fmax (bottom_right, 0.0);
        bottom_left = GLib.Math.fmax (bottom_left, 0.0);

        double max_corner = GLib.Math.fmin (width, height);
        top_left = GLib.Math.fmin (top_left, max_corner);
        top_right = GLib.Math.fmin (top_right, max_corner);
        bottom_right = GLib.Math.fmin (bottom_right, max_corner);
        bottom_left = GLib.Math.fmin (bottom_left, max_corner);

        adjust_corner_pair (ref top_left, ref top_right, width);
        adjust_corner_pair (ref bottom_left, ref bottom_right, width);
        adjust_corner_pair (ref top_left, ref bottom_left, height);
        adjust_corner_pair (ref top_right, ref bottom_right, height);
    }

    public bool corner_radii_are_uniform (double top_left, double top_right, double bottom_right, double bottom_left, double epsilon = 0.01) {
        return GLib.Math.fabs (top_left - top_right) <= epsilon &&
               GLib.Math.fabs (top_left - bottom_right) <= epsilon &&
               GLib.Math.fabs (top_left - bottom_left) <= epsilon;
    }

    public void append_rounded_rect (Cairo.Context cr, double x, double y, double width, double height, double top_left, double top_right, double bottom_right, double bottom_left) {
        double tl = GLib.Math.fmax (top_left, 0.0);
        double tr = GLib.Math.fmax (top_right, 0.0);
        double br = GLib.Math.fmax (bottom_right, 0.0);
        double bl = GLib.Math.fmax (bottom_left, 0.0);

        normalize_corner_radii (ref tl, ref tr, ref br, ref bl, width, height);

        double right = x + width;
        double bottom = y + height;
        double pi = GLib.Math.PI;

        cr.new_sub_path ();
        cr.move_to (x + tl, y);
        cr.line_to (right - tr, y);
        if (tr > 0.0) {
            cr.arc (right - tr, y + tr, tr, -pi / 2.0, 0.0);
        } else {
            cr.line_to (right, y);
        }
        cr.line_to (right, bottom - br);
        if (br > 0.0) {
            cr.arc (right - br, bottom - br, br, 0.0, pi / 2.0);
        } else {
            cr.line_to (right, bottom);
        }
        cr.line_to (x + bl, bottom);
        if (bl > 0.0) {
            cr.arc (x + bl, bottom - bl, bl, pi / 2.0, pi);
        } else {
            cr.line_to (x, bottom);
        }
        cr.line_to (x, y + tl);
        if (tl > 0.0) {
            cr.arc (x + tl, y + tl, tl, pi, 3.0 * pi / 2.0);
        } else {
            cr.line_to (x, y);
        }
        cr.close_path ();
    }

    public string rounded_rect_path_d (double x, double y, double width, double height, double top_left, double top_right, double bottom_right, double bottom_left) {
        if (width <= 0.0 || height <= 0.0) {
            return "";
        }

        double tl = GLib.Math.fmax (top_left, 0.0);
        double tr = GLib.Math.fmax (top_right, 0.0);
        double br = GLib.Math.fmax (bottom_right, 0.0);
        double bl = GLib.Math.fmax (bottom_left, 0.0);

        normalize_corner_radii (ref tl, ref tr, ref br, ref bl, width, height);

        double right = x + width;
        double bottom = y + height;

        var builder = new GLib.StringBuilder ();
        builder.append ("M %g %g ".printf (x + tl, y));
        builder.append ("H %g ".printf (right - tr));
        if (tr > 0.0) {
            builder.append ("A %g %g 0 0 1 %g %g ".printf (tr, tr, right, y + tr));
        } else {
            builder.append ("L %g %g ".printf (right, y));
        }
        builder.append ("V %g ".printf (bottom - br));
        if (br > 0.0) {
            builder.append ("A %g %g 0 0 1 %g %g ".printf (br, br, right - br, bottom));
        } else {
            builder.append ("L %g %g ".printf (right, bottom));
        }
        builder.append ("H %g ".printf (x + bl));
        if (bl > 0.0) {
            builder.append ("A %g %g 0 0 1 %g %g ".printf (bl, bl, x, bottom - bl));
        } else {
            builder.append ("L %g %g ".printf (x, bottom));
        }
        builder.append ("V %g ".printf (y + tl));
        if (tl > 0.0) {
            builder.append ("A %g %g 0 0 1 %g %g ".printf (tl, tl, x + tl, y));
        } else {
            builder.append ("L %g %g ".printf (x, y));
        }
        builder.append ("Z");
        return builder.str;
    }

    private GLib.Regex ? compile_regex (string pattern, GLib.RegexCompileFlags flags = (GLib.RegexCompileFlags) 0) {
        try {
            return new GLib.Regex (pattern, flags, 0);
        } catch (GLib.Error regex_err) {
            GLib.warning ("Failed to compile regex '%s': %s", pattern, regex_err.message);
            return null;
        }
    }

    private bool parse_svg_paint_value (string value, out Gdk.RGBA color) {
        color = { 0 };
        string trimmed = value.strip ();
        if (trimmed.length == 0)return false;
        string lowered = trimmed.down ();
        if (lowered == "none") {
            color = { 0 };
            color.alpha = 0.0f;
            return true;
        }
        Gdk.RGBA parsed = { 0 };
        if (parsed.parse (trimmed)) {
            color = parsed;
            return true;
        }
        return false;
    }

    private bool parse_svg_numeric_value (string source, out double value) {
        value = 0.0;
        var number_regex = compile_regex ("[+-]?[0-9]*\\.?[0-9]+", (GLib.RegexCompileFlags) 0);
        if (number_regex == null)return false;
        GLib.MatchInfo match;
        if (!number_regex.match (source, 0, out match))return false;
        string numeric = match.fetch (0);
        numeric = numeric.replace (",", ".");
        value = double.parse (numeric);
        return true;
    }

    private string inject_svg_attribute (string svg, string attribute, string value) {
        int svg_tag = svg.index_of ("<svg");
        if (svg_tag < 0)return svg;
        int insert_at = svg.index_of (">", svg_tag);
        if (insert_at < 0)return svg;
        string insertion = " %s=\"%s\"".printf (attribute, value);
        return svg.substring (0, insert_at) + insertion + svg.substring (insert_at);
    }

    private string trim_decimal_suffix (string raw) {
        int idx = raw.length - 1;
        while (idx > 0 && raw[idx] == '0') {
            idx--;
        }
        if (idx > 0 && raw[idx] == '.')idx--;
        return raw.substring (0, idx + 1);
    }

    private void apply_svg_opacity_from_source (string svg, string attribute, ref Gdk.RGBA color) {
        double opacity;
        if (try_extract_svg_numeric (svg, attribute + "-opacity", out opacity)) {
            double combined = IconiUtils.clamp01 (opacity) * IconiUtils.clamp01 (color.alpha);
            color.alpha = (float) combined;
        }
    }

    private string set_svg_attribute_or_style (string svg, string attribute, string value) {
        string attr_pattern = "(?i)" + GLib.Regex.escape_string (attribute) + "\\s*=\\s\"([^\"]*)\"";
        var attr_regex = compile_regex (attr_pattern, GLib.RegexCompileFlags.MULTILINE);
        try {
            if (attr_regex != null && attr_regex.match (svg, 0)) {
                return attr_regex.replace (svg, -1, 0, "%s=\"%s\"".printf (attribute, value));
            }
        } catch (GLib.Error replace_err) {
            GLib.warning ("Failed to update SVG attribute %s: %s", attribute, replace_err.message);
        }
        string style_pattern = "(?i)" + GLib.Regex.escape_string (attribute) + "\\s*:\\s*[^;\"']+";
        var style_regex = compile_regex (style_pattern, GLib.RegexCompileFlags.MULTILINE);
        try {
            if (style_regex != null && style_regex.match (svg, 0)) {
                return style_regex.replace (svg, -1, 0, "%s:%s".printf (attribute, value));
            }
        } catch (GLib.Error style_err) {
            GLib.warning ("Failed to update SVG style %s: %s", attribute, style_err.message);
        }
        return inject_svg_attribute (svg, attribute, value);
    }

    public bool try_extract_svg_color (string svg, string attribute, out Gdk.RGBA color) {
        color = { 0 };
        string attr_pattern = "(?i)" + GLib.Regex.escape_string (attribute) + "\\s*=\\s\"([^\"]+)\"";
        var attr_regex = compile_regex (attr_pattern, GLib.RegexCompileFlags.MULTILINE);
        if (attr_regex != null) {
            GLib.MatchInfo match;
            if (attr_regex.match (svg, 0, out match)) {
                string raw = match.fetch (1);
                if (parse_svg_paint_value (raw, out color)) {
                    apply_svg_opacity_from_source (svg, attribute, ref color);
                    return true;
                }
            }
        }
        string style_pattern = "(?i)" + GLib.Regex.escape_string (attribute) + "\\s*:\\s*([^;\"']+)";
        var style_regex = compile_regex (style_pattern, GLib.RegexCompileFlags.MULTILINE);
        if (style_regex != null) {
            GLib.MatchInfo match;
            if (style_regex.match (svg, 0, out match)) {
                string raw = match.fetch (1);
                if (parse_svg_paint_value (raw, out color)) {
                    apply_svg_opacity_from_source (svg, attribute, ref color);
                    return true;
                }
            }
        }
        color = { 0 };
        return false;
    }

    public bool try_extract_svg_numeric (string svg, string attribute, out double value) {
        value = 0.0;
        string attr_pattern = "(?i)" + GLib.Regex.escape_string (attribute) + "\\s*=\\s\"([^\"]+)\"";
        var attr_regex = compile_regex (attr_pattern, GLib.RegexCompileFlags.MULTILINE);
        if (attr_regex != null) {
            GLib.MatchInfo match;
            if (attr_regex.match (svg, 0, out match)) {
                string raw = match.fetch (1);
                if (parse_svg_numeric_value (raw, out value))return true;
            }
        }
        string style_pattern = "(?i)" + GLib.Regex.escape_string (attribute) + "\\s*:\\s*([^;\"']+)";
        var style_regex = compile_regex (style_pattern, GLib.RegexCompileFlags.MULTILINE);
        if (style_regex != null) {
            GLib.MatchInfo match;
            if (style_regex.match (svg, 0, out match)) {
                string raw = match.fetch (1);
                if (parse_svg_numeric_value (raw, out value))return true;
            }
        }
        return false;
    }

    public string set_svg_paint (string svg, string attribute, Gdk.RGBA color) {
        double alpha = IconiUtils.clamp01 (color.alpha);
        if (alpha <= 0.0005) {
            string updated = set_svg_attribute_or_style (svg, attribute, "none");
            return set_svg_attribute_or_style (updated, attribute + "-opacity", "0");
        }
        string hex = IconiUtils.rgba_to_hex (color);
        string updated_svg = set_svg_attribute_or_style (svg, attribute, hex);
        string opacity_value = IconiUtils.format_decimal_string (alpha);
        return set_svg_attribute_or_style (updated_svg, attribute + "-opacity", opacity_value);
    }

    public string set_svg_numeric (string svg, string attribute, double value) {
        string formatted = IconiUtils.format_decimal_string_unbounded (value);
        return set_svg_attribute_or_style (svg, attribute, formatted);
    }

    public string format_decimal_string (double value) {
        double clamped = IconiUtils.clamp01 (value);
        double scaled = GLib.Math.floor (clamped * 1000.0 + 0.5);
        int scaled_int = (int) scaled;
        int integer_part = scaled_int / 1000;
        int fractional_part = scaled_int % 1000;
        string raw = "%d.%03d".printf (integer_part, fractional_part);
        return trim_decimal_suffix (raw);
    }

    public string format_decimal_string_unbounded (double value) {
        double scaled = GLib.Math.floor (value * 1000.0 + 0.5);
        int scaled_int = (int) scaled;
        int integer_part = scaled_int / 1000;
        int fractional_part = scaled_int % 1000;
        string raw = "%d.%03d".printf (integer_part, fractional_part);
        return trim_decimal_suffix (raw);
    }

    public bool should_use_light_foreground (Gdk.RGBA background) {
        double bg_luminance = IconiUtils.compute_relative_luminance (background);
        double contrast_white = IconiUtils.contrast_ratio (bg_luminance, 1.0);
        double contrast_black = IconiUtils.contrast_ratio (bg_luminance, 0.0);
        return contrast_white >= contrast_black;
    }

    public string sanitize_numeric_text (string input, uint max_digits) {
        string digits = "";
        for (int i = 0; i < input.length; i++) {
            char c = input[i];
            if (c >= '0' && c <= '9') {
                if (digits.length >= (int) max_digits) {
                    break;
                }
                digits += "%c".printf (c);
            }
        }
        return digits;
    }

    public string ? load_resource_text (string resource_path) {
        try {
            var stream = GLib.resources_open_stream (resource_path, GLib.ResourceLookupFlags.NONE);
            var data_stream = new GLib.DataInputStream (stream);
            var builder = new GLib.StringBuilder ();
            string? line;
            bool first = true;
            while ((line = data_stream.read_line_utf8 (null)) != null) {
                if (!first) {
                    builder.append ("\n");
                }
                builder.append (line);
                first = false;
            }
            data_stream.close ();
            return builder.str;
        } catch (GLib.Error e) {
            GLib.warning ("Failed to load resource %s: %s", resource_path, e.message);
            return null;
        }
    }

    public string normalize_svg_snippet (string raw) {
        var builder = new GLib.StringBuilder ();
        var lines = raw.split ("\n");
        for (int i = 0; i < lines.length; i++) {
            string line = lines[i];
            string trimmed = line.strip ();
            if (trimmed.length == 0 && i == lines.length - 1) {
                continue;
            }
            if (trimmed.has_prefix ("<?xml")) {
                continue;
            }
            builder.append (line);
            if (i < lines.length - 1) {
                builder.append ("\n");
            }
        }
        return builder.str;
    }

    public string normalize_overlay_svg (string raw) {
        var builder = new GLib.StringBuilder ();
        var lines = raw.split ("\n");
        for (int i = 0; i < lines.length; i++) {
            string line = lines[i];
            string trimmed = line.strip ();
            if (trimmed.length == 0 && i == lines.length - 1) {
                continue;
            }
            if (trimmed.has_prefix ("<?xml")) {
                continue;
            }
            builder.append (line);
            if (i < lines.length - 1) {
                builder.append ("\n");
            }
        }
        return builder.str;
    }

    public void write_overlay_svg (GLib.DataOutputStream stream, string overlay_id, string resource_path, double scale, double offset_x, double offset_y) {
        string? raw = load_resource_text (resource_path);
        if (raw == null || raw.length == 0) {
            return;
        }
        string normalized = normalize_overlay_svg (raw);
        if (normalized.strip ().length == 0) {
            return;
        }

        try {
            bool translate_needed = (offset_x != 0.0 || offset_y != 0.0);
            double scale_diff = GLib.Math.fabs (scale - 1.0);
            bool scale_needed = scale_diff > 0.00001;
            string transform = "";
            if (translate_needed && scale_needed) {
                transform = " transform=\"translate(%g,%g) scale(%g)\"".printf (offset_x, offset_y, scale);
            } else if (translate_needed) {
                transform = " transform=\"translate(%g,%g)\"".printf (offset_x, offset_y);
            } else if (scale_needed) {
                transform = " transform=\"scale(%g)\"".printf (scale);
            }
            stream.put_string ("    <g id=\"overlay-%s\"%s>\n".printf (overlay_id, transform));
            var lines = normalized.split ("\n");
            for (int i = 0; i < lines.length; i++) {
                string line = lines[i];
                stream.put_string ("        ");
                stream.put_string (line);
                stream.put_string ("\n");
            }
            stream.put_string ("    </g>\n");
        } catch (GLib.Error e) {
            GLib.warning ("Failed to write overlay %s: %s", overlay_id, e.message);
        }
    }

    public void write_dev_badge_svg (GLib.DataOutputStream stream) {
        string resource_path = "/com/fyralabs/Iconi/dev.svg";
        string? raw = load_resource_text (resource_path);
        if (raw == null || raw.length == 0) {
            return;
        }
        string normalized = normalize_overlay_svg (raw);
        if (normalized.strip ().length == 0) {
            return;
        }

        double ink_x = 0.0;
        double ink_y = 0.0;
        try {
            var res_stream = GLib.resources_open_stream (resource_path, GLib.ResourceLookupFlags.NONE);
            var handle = new Rsvg.Handle.from_stream_sync (res_stream, null, Rsvg.HandleFlags.FLAGS_NONE, null);
            Rsvg.Rectangle ink_rect;
            Rsvg.Rectangle logical_rect;
            if (handle.get_geometry_for_element (null, out ink_rect, out logical_rect)) {
                ink_x = ink_rect.x;
                ink_y = ink_rect.y;
            }
            res_stream.close (null);
        } catch (GLib.Error geo_err) {
            GLib.warning ("Failed to read dev badge geometry: %s", geo_err.message);
        }

        double target_x = 12.0;
        double target_y = 67.0;
        double translate_x = target_x - ink_x;
        double translate_y = target_y - ink_y;

        try {
            stream.put_string ("    <g id=\"overlay-dev\" transform=\"translate(%g,%g)\">\n".printf (translate_x, translate_y));
            var lines = normalized.split ("\n");
            for (int i = 0; i < lines.length; i++) {
                string line = lines[i];
                stream.put_string ("        ");
                stream.put_string (line);
                stream.put_string ("\n");
            }
            stream.put_string ("    </g>\n");
        } catch (GLib.Error write_err) {
            GLib.warning ("Failed to write dev badge overlay: %s", write_err.message);
        }
    }

    public static void export_icon_to_svg (IconModel model, string filename) {
        try {
            var file = GLib.File.new_for_path (filename);
            var stream = file.replace (null, false, GLib.FileCreateFlags.NONE);
            var data_stream = new GLib.DataOutputStream (stream);

            double svg_size = 109.0;
            double offset = (128.0 - svg_size) / 2.0;
            double radius = 24.0;

            data_stream.put_string ("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
            data_stream.put_string ("<svg xmlns=\"http://www.w3.org/2000/svg\" ");
            data_stream.put_string ("width=\"128\" height=\"128\" viewBox=\"0 0 128 128\">\n");
            data_stream.put_string ("  <defs>\n");

            int gradient_id = 0;
            if (model.use_gradient) {
                gradient_id++;
                string bg_grad_id = "gradient-bg";
                double angle_rad = model.gradient_angle * (GLib.Math.PI / 180.0);
                double cx = 64.0;
                double cy = 64.0;
                double max_distance = GLib.Math.sqrt (cx * cx + cy * cy);
                double x2 = cx + GLib.Math.cos (angle_rad) * max_distance;
                double y2 = cy + GLib.Math.sin (angle_rad) * max_distance;
                double x1 = cx - GLib.Math.cos (angle_rad) * max_distance;
                double y1 = cy - GLib.Math.sin (angle_rad) * max_distance;
                string start_color = rgba_to_hex (model.background);
                string end_color = rgba_to_hex (model.gradient_secondary);
                data_stream.put_string ("    <linearGradient id=\"%s\" x1=\"%g\" y1=\"%g\" x2=\"%g\" y2=\"%g\" gradientUnits=\"userSpaceOnUse\">\n".printf (bg_grad_id, x1, y1, x2, y2));
                data_stream.put_string ("      <stop offset=\"0%%\" style=\"stop-color:%s;stop-opacity:1.0\" />\n".printf (start_color));
                data_stream.put_string ("      <stop offset=\"100%%\" style=\"stop-color:%s;stop-opacity:1.0\" />\n".printf (end_color));
                data_stream.put_string ("    </linearGradient>\n");
            }

            for (int g = 0; g < (int) model.groups.get_n_items (); g++) {
                var group = (ElementGroup) model.groups.get_item ((uint) g);
                int element_count = (int) group.elements.get_n_items ();
                for (int i = 0; i < element_count; i++) {
                    var el = (IconElement) group.elements.get_item ((uint) i);
                    if (el.use_gradient) {
                        gradient_id++;
                        string grad_id = "gradient-%d".printf (gradient_id);
                        double angle_rad = el.gradient_angle * (GLib.Math.PI / 180.0);
                        double cx = el.x + el.width / 2.0;
                        double cy = el.y + el.height / 2.0;
                        double max_distance = GLib.Math.sqrt ((el.width / 2.0) * (el.width / 2.0) + (el.height / 2.0) * (el.height / 2.0));
                        double x2 = cx + GLib.Math.cos (angle_rad) * max_distance;
                        double y2 = cy + GLib.Math.sin (angle_rad) * max_distance;
                        double x1 = cx - GLib.Math.cos (angle_rad) * max_distance;
                        double y1 = cy - GLib.Math.sin (angle_rad) * max_distance;
                        string start_color = rgba_to_hex (el.fill);
                        string end_color = rgba_to_hex (el.gradient_secondary);
                        data_stream.put_string ("    <linearGradient id=\"%s\" x1=\"%g\" y1=\"%g\" x2=\"%g\" y2=\"%g\" gradientUnits=\"userSpaceOnUse\">\n".printf (grad_id, x1 + offset, y1 + offset, x2 + offset, y2 + offset));
                        data_stream.put_string ("      <stop offset=\"0%%\" style=\"stop-color:%s;stop-opacity:1.0\" />\n".printf (start_color));
                        data_stream.put_string ("      <stop offset=\"100%%\" style=\"stop-color:%s;stop-opacity:1.0\" />\n".printf (end_color));
                        data_stream.put_string ("    </linearGradient>\n");
                    }
                }
            }

            data_stream.put_string ("  </defs>\n");

            if (model.use_gradient) {
                data_stream.put_string ("  <rect id=\"background\" x=\"%g\" y=\"%g\" width=\"%g\" height=\"%g\" rx=\"%g\" ry=\"%g\" fill=\"url(#gradient-bg)\" />\n".printf (offset, offset, svg_size, svg_size, radius, radius));
            } else {
                string bg_color = rgba_to_hex (model.background);
                data_stream.put_string ("  <rect id=\"background\" x=\"%g\" y=\"%g\" width=\"%g\" height=\"%g\" rx=\"%g\" ry=\"%g\" fill=\"%s\" />\n".printf (offset, offset, svg_size, svg_size, radius, radius, bg_color));
            }

            data_stream.put_string ("  <g id=\"content\">\n");

            gradient_id = 0;
            if (model.use_gradient) {
                gradient_id++;
            }

            for (int g = 0; g < (int) model.groups.get_n_items (); g++) {
                var group = (ElementGroup) model.groups.get_item ((uint) g);
                string group_id = "group-%d".printf (g);
                string blend_mode = group.blend_mode;
                data_stream.put_string ("    <g id=\"%s\" style=\"mix-blend-mode:%s;\">\n".printf (group_id, blend_mode));

                int element_count = (int) group.elements.get_n_items ();
                for (int i = 0; i < element_count; i++) {
                    var el = (IconElement) group.elements.get_item ((uint) i);
                    string element_id = "element-%d-%d".printf (g, i);
                    string transform_str = "";
                    if (el.element_angle != 0.0) {
                        double center_x = offset + el.x + el.width / 2.0;
                        double center_y = offset + el.y + el.height / 2.0;
                        transform_str = " transform=\"rotate(%g %g %g)\"".printf (el.element_angle, center_x, center_y);
                    }

                    if (el.type == ElementType.RECTANGLE) {
                        string fill_value = "";
                        float fill_opacity = 1.0f;
                        if (el.use_gradient) {
                            gradient_id++;
                            fill_value = "url(#gradient-%d)".printf (gradient_id);
                            fill_opacity = 1.0f;
                        } else {
                            fill_value = rgba_to_hex (el.fill);
                            fill_opacity = el.fill.alpha;
                        }
                        string stroke_value = rgba_to_hex (el.stroke);
                        float stroke_opacity = el.stroke.alpha;
                        data_stream.put_string ("      <rect id=\"%s\" x=\"%g\" y=\"%g\" width=\"%g\" height=\"%g\" ".printf (element_id, offset + el.x, offset + el.y, el.width, el.height));
                        data_stream.put_string ("rx=\"%g\" ry=\"%g\" ".printf (el.corner_radius_top_left, el.corner_radius_top_left));
                        data_stream.put_string ("fill=\"%s\" fill-opacity=\"%.3f\" ".printf (fill_value, fill_opacity));
                        data_stream.put_string ("stroke=\"%s\" stroke-opacity=\"%.3f\" stroke-width=\"%g\"%s/>\n".printf (stroke_value, stroke_opacity, el.stroke_width, transform_str));
                    } else if (el.type == ElementType.CIRCLE) {
                        double cx = offset + el.x + el.width / 2.0;
                        double cy = offset + el.y + el.height / 2.0;
                        double rx = el.width / 2.0;
                        double ry = el.height / 2.0;
                        string fill_value = "";
                        float fill_opacity = 1.0f;
                        if (el.use_gradient) {
                            gradient_id++;
                            fill_value = "url(#gradient-%d)".printf (gradient_id);
                            fill_opacity = 1.0f;
                        } else {
                            fill_value = rgba_to_hex (el.fill);
                            fill_opacity = el.fill.alpha;
                        }
                        string stroke_value = rgba_to_hex (el.stroke);
                        float stroke_opacity = el.stroke.alpha;
                        data_stream.put_string ("      <ellipse id=\"%s\" cx=\"%g\" cy=\"%g\" rx=\"%g\" ry=\"%g\" ".printf (element_id, cx, cy, rx, ry));
                        data_stream.put_string ("fill=\"%s\" fill-opacity=\"%.3f\" ".printf (fill_value, fill_opacity));
                        data_stream.put_string ("stroke=\"%s\" stroke-opacity=\"%.3f\" stroke-width=\"%g\"%s/>\n".printf (stroke_value, stroke_opacity, el.stroke_width, transform_str));
                    } else if (el.type == ElementType.LINE) {
                        double x2 = el.x + el.width;
                        double y2 = el.y + el.height;
                        string stroke_value = rgba_to_hex (el.stroke);
                        float stroke_opacity = el.stroke.alpha;
                        if (el.use_gradient) {
                            gradient_id++;
                            string line_grad_id = "gradient-%d".printf (gradient_id);
                            data_stream.put_string ("      <line id=\"%s\" x1=\"%g\" y1=\"%g\" x2=\"%g\" y2=\"%g\" ".printf (element_id, offset + el.x, offset + el.y, offset + x2, offset + y2));
                            data_stream.put_string ("stroke=\"url(#%s)\" stroke-opacity=\"1.0\" stroke-width=\"%g\"%s/>\n".printf (line_grad_id, el.stroke_width, transform_str));
                        } else {
                            data_stream.put_string ("      <line id=\"%s\" x1=\"%g\" y1=\"%g\" x2=\"%g\" y2=\"%g\" ".printf (element_id, offset + el.x, offset + el.y, offset + x2, offset + y2));
                            data_stream.put_string ("stroke=\"%s\" stroke-opacity=\"%.3f\" stroke-width=\"%g\"%s/>\n".printf (stroke_value, stroke_opacity, el.stroke_width, transform_str));
                        }
                    } else if (el.type == ElementType.SVG) {
                        double svg_logical_width = el.width;
                        double svg_logical_height = el.height;
                        double scale_x = 1.0;
                        double scale_y = 1.0;
                        try {
                            var svg_handle = new Rsvg.Handle.from_data (el.svg_data.data);
                            Rsvg.Rectangle ink_rect;
                            Rsvg.Rectangle logical_rect;
                            if (svg_handle.get_geometry_for_element (null, out ink_rect, out logical_rect)) {
                                double logical_w = logical_rect.width;
                                double logical_h = logical_rect.height;
                                if (logical_w > 0.0 && logical_h > 0.0) {
                                    svg_logical_width = logical_w;
                                    svg_logical_height = logical_h;
                                    scale_x = ((double) el.width) / logical_w;
                                    scale_y = ((double) el.height) / logical_h;
                                }
                            }
                        } catch (Error geo_err) {
                            GLib.warning ("Failed to read embedded SVG geometry: %s", geo_err.message);
                        }
                        bool scale_needed = (GLib.Math.fabs (scale_x - 1.0) > 0.00001) || (GLib.Math.fabs (scale_y - 1.0) > 0.00001);
                        data_stream.put_string ("      <g id=\"%s\"%s>\n".printf (element_id, transform_str));
                        data_stream.put_string ("        <g transform=\"translate(%g,%g)\">\n".printf (offset + el.x, offset + el.y));
                        if (scale_needed) {
                            data_stream.put_string ("          <g transform=\"scale(%g,%g)\">\n".printf (scale_x, scale_y));
                        }
                        string normalized_svg = normalize_overlay_svg (el.svg_data);
                        if (normalized_svg.strip ().length > 0) {
                            var svg_lines = normalized_svg.split ("\n");
                            for (int line_index = 0; line_index < svg_lines.length; line_index++) {
                                string inline_line = svg_lines[line_index];
                                string indent = scale_needed ? "            " : "          ";
                                data_stream.put_string (indent);
                                data_stream.put_string (inline_line);
                                data_stream.put_string ("\n");
                            }
                        }
                        if (scale_needed) {
                            data_stream.put_string ("          </g>\n");
                        }
                        data_stream.put_string ("        </g>\n");
                        data_stream.put_string ("      </g>\n");
                    }
                }
                data_stream.put_string ("    </g>\n");
            }

            data_stream.put_string ("  </g>\n");

            if (model.use_raised_effect) {
                write_overlay_svg (data_stream, "effects", "/com/fyralabs/Iconi/effects.svg", 1.0, offset, offset);
            }
            if (model.use_frame_overlay) {
                write_overlay_svg (data_stream, "frame", "/com/fyralabs/Iconi/frame.svg", 1.0, offset, offset);
            }
            if (model.show_dev_badge) {
                write_dev_badge_svg (data_stream);
            }

            data_stream.put_string ("</svg>\n");

            data_stream.close ();
        } catch (GLib.Error e) {
            GLib.warning ("Failed to export SVG: %s", e.message);
        }
    }
}
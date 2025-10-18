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
}
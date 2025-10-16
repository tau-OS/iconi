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
}
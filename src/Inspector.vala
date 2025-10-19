public class Inspector : Object {
    private const string ICON_ALIGN_TOP = "align-top-symbolic";
    private const string ICON_ALIGN_LEFT = "align-left-symbolic";
    private const string ICON_ALIGN_CENTER = "align-center-symbolic";
    private const string ICON_ALIGN_RIGHT = "align-right-symbolic";
    private const string ICON_ALIGN_BOTTOM = "align-bottom-symbolic";
    private const string ICON_LOCKED = "lock-closed-symbolic";
    private const string ICON_UNLOCKED = "lock-open-symbolic";
    private const string ICON_GRID_DARK_MINI = "grid-dark-symbolic";

    private enum CornerHandle {
        TOP_LEFT,
        TOP_RIGHT,
        BOTTOM_RIGHT,
        BOTTOM_LEFT
    }

    private delegate void ColorPickerCallback (Gdk.RGBA color);

    private weak IconMakerWindow owner;
    private IconModel model;
    private Gtk.DrawingArea canvas;
    private He.AppBar main_appbar;
    private Gtk.Box container;

    private Gtk.Box props_area;
    private Gtk.Box fill_box;
    private Gtk.Box stroke_box;
    private Gtk.Box bg_props_area;
    private Gtk.Box group_props_area;
    private Gtk.Box bg_variant_row;
    private Gtk.Box bg_gradient_container;
    private Gtk.Box bg_canvas_bg_row;
    private Gtk.Box bg_fill_mode_row;
    private Gtk.Box bg_effects_row;
    private Gtk.Box bg_frame_row;
    private Gtk.Box bg_dev_row;

    private Gtk.Box pos_box;
    private Gtk.Box size_box;
    private Gtk.Box corner_box;
    private Gtk.Grid corner_grid;
    private Gtk.Box corner_entries_container;
    private Gtk.Box corner_unified_row;

    private Gtk.Entry corner_radius_unified_entry;
    private Gtk.Entry corner_radius_tl_entry;
    private Gtk.Entry corner_radius_tr_entry;
    private Gtk.Entry corner_radius_br_entry;
    private Gtk.Entry corner_radius_bl_entry;
    private Gtk.ToggleButton corner_radius_lock_toggle;
    private Gtk.Image corner_radius_lock_picture;

    private Gtk.Box align_box;
    private Gtk.Grid align_grid;
    private Gtk.Button align_left_btn;
    private Gtk.Button align_center_btn;
    private Gtk.Button align_right_btn;
    private Gtk.Button align_top_btn;
    private Gtk.Button align_bottom_btn;

    private Gtk.Button fill_btn;
    private Gtk.Button stroke_btn;
    private Gtk.Entry fill_opacity_entry;
    private Gtk.Entry stroke_opacity_entry;
    private Gtk.SpinButton stroke_width_spin;
    private Gtk.DropDown fill_mode_drop;
    private Gtk.Button fill_gradient_btn;
    private Gtk.SpinButton fill_gradient_angle_spin;
    private Gtk.Box fill_gradient_color_row;
    private Gtk.Box fill_gradient_angle_row;

    private Gtk.SpinButton line_length_spin;
    private Gtk.SpinButton line_angle_spin;
    private Gtk.Box line_controls_box;

    private Gtk.SpinButton element_angle_spin;
    private Gtk.Box element_angle_box;

    private Gtk.SpinButton x_entry;
    private Gtk.SpinButton y_entry;
    private Gtk.SpinButton w_entry;
    private Gtk.SpinButton h_entry;
    private Gtk.ToggleButton size_lock_toggle;
    private Gtk.Image size_lock_picture;

    private Gtk.DropDown bg_variant_drop;
    private Gtk.Button bg_side_color_btn;
    private Gtk.Switch bg_side_wall_switch;
    private Gtk.DropDown bg_fill_mode_drop;
    private Gtk.Button bg_gradient_end_btn;
    private Gtk.SpinButton bg_gradient_angle_spin;
    private Gtk.Switch bg_effects_switch;
    private Gtk.Switch bg_frame_switch;
    private Gtk.Switch bg_dev_switch;

    private Gtk.Switch grid_overlay_switch;
    private Gtk.DropDown grid_variant_drop;
    private Gtk.Image grid_preview_picture;

    private Gtk.Box group_blend_box;
    private Gtk.DropDown group_blend_drop;
    private Gtk.Switch group_sheen_layer_toggle;
    private Gtk.Switch group_shadow_toggle;
    private Gtk.DropDown group_shadow_mode_drop;
    private Gtk.DropDown group_effect_scope_drop;

    private Gtk.Label fill_label;
    private Gtk.Label stroke_label;
    private Gtk.Label fill_mode_label;
    private Gtk.Label fill_gradient_angle_label;

    private Gtk.Label zoom_label;
    private Gtk.Scale zoom_scale;

    private bool updating = false;

    private string[] blend_labels = { "Normal", "Multiply", "Screen", "Overlay", "Darken", "Lighten", "Color Dodge", "Color Burn", "Hard Light", "Soft Light", "Difference", "Exclusion", "Hue", "Saturation", "Color", "Luminosity" };
    private string[] blend_values = { "normal", "multiply", "screen", "overlay", "darken", "lighten", "color-dodge", "color-burn", "hard-light", "soft-light", "difference", "exclusion", "hue", "saturation", "color", "luminosity" };
    private string[] bg_fill_modes = { "Solid", "Gradient" };
    private string[] effect_scope_labels = { "Individual", "Combined" };
    private string[] bg_variant_labels = { "Custom", "System Light", "System Dark" };
    private IconBackgroundVariant[] bg_variant_values = { IconBackgroundVariant.NONE, IconBackgroundVariant.SYSTEM_LIGHT, IconBackgroundVariant.SYSTEM_DARK };

    public Inspector (IconMakerWindow owner, IconModel model, Gtk.DrawingArea canvas, He.AppBar main_appbar) {
        this.owner = owner;
        this.model = model;
        this.canvas = canvas;
        this.main_appbar = main_appbar;
        build_ui ();
        sync_background_variant_controls ();
        apply_wallpaper_state (model.use_wallpaper);
        props_area.set_visible (false);
        bg_props_area.set_visible (false);
        container.set_visible (false);
        update_sidebar_visibility (false);
    }

    public Gtk.Widget get_widget () {
        return container;
    }

    public void sync_wallpaper_toggle (bool state) {
        bool prev = updating;
        updating = true;
        bg_side_wall_switch.set_active (state);
        updating = prev;
    }

    public void refresh_line_deltas (IconElement el) {
        if (el.type != ElementType.LINE)return;
        double angle_rad = el.line_angle * (GLib.Math.PI / 180.0);
        double length = el.line_length;
        double dx = GLib.Math.cos (angle_rad) * length;
        double dy = GLib.Math.sin (angle_rad) * length;
        el.width = (float) dx;
        el.height = (float) dy;
    }

    public void update_for_selection () {
        if (updating)return;
        updating = true;
        try {
            bool show_bg = model.background_selected;
            bool show_group = model.group_selected;
            bool show_element = (!model.background_selected && !model.group_selected && model.selected_group_index >= 0 && model.selected_element_index >= 0);

            bg_props_area.set_visible (show_bg);
            group_props_area.set_visible (show_group);
            props_area.set_visible (show_element);

            update_sidebar_visibility (show_bg || show_group || show_element);

            if (show_bg) {
                update_color_button (bg_side_color_btn, model.background);
                bg_side_wall_switch.set_active (model.use_wallpaper);
                bg_effects_switch.set_active (model.use_raised_effect);
                bg_frame_switch.set_active (model.use_frame_overlay);
                bg_dev_switch.set_active (model.show_dev_badge);
                bg_fill_mode_drop.set_selected (model.use_gradient ? 1u : 0u);
                update_color_button (bg_gradient_end_btn, model.gradient_secondary);
                bg_gradient_angle_spin.set_value (model.gradient_angle);
            }

            if (show_group) {
                var group = (ElementGroup?) model.groups.get_item ((uint) model.selected_group_index);
                if (group != null) {
                    int blend_index = 0;
                    for (int i = 0; i < blend_values.length; i++) {
                        if (blend_values[i] == group.blend_mode) {
                            blend_index = i;
                            break;
                        }
                    }
                    group_blend_drop.set_selected ((uint) blend_index);
                    group_sheen_layer_toggle.set_active (group.use_sheen_layer);
                    group_shadow_toggle.set_active (group.use_shadow);
                    group_shadow_mode_drop.set_selected (group.shadow_chromatic ? 1u : 0u);
                    group_effect_scope_drop.set_selected (group.effect_scope == GroupEffectScope.COMBINED ? 1u : 0u);
                }
            }

            if (show_element) {
                var element = owner.get_selected_element ();
                if (element != null) {
                    x_entry.set_value ((double) element.x);
                    y_entry.set_value ((double) element.y);
                    w_entry.set_value ((double) element.width);
                    h_entry.set_value ((double) element.height);
                    stroke_width_spin.set_value ((double) element.stroke_width);
                    update_color_button (fill_btn, element.fill);
                    update_color_button (stroke_btn, element.stroke);

                    bool is_line = (element.type == ElementType.LINE);
                    bool show_fill = !is_line;
                    fill_box.set_visible (show_fill);

                    size_box.set_visible (!is_line);
                    line_controls_box.set_visible (is_line);

                    bool is_circle = (element.type == ElementType.CIRCLE);
                    bool circle_same_dimensions = is_circle && (size_lock_toggle.get_active () || GLib.Math.fabs (element.width - element.height) < 0.01);
                    element_angle_box.set_visible (!is_line && !circle_same_dimensions);

                    corner_box.set_visible (element.type == ElementType.RECTANGLE);
                    if (element.type == ElementType.RECTANGLE) {
                        apply_corner_radius_constraints (element);
                    }

                    if (is_line) {
                        line_length_spin.set_value ((double) element.line_length);
                        line_angle_spin.set_value (element.line_angle);
                    }

                    element_angle_spin.set_value (element.element_angle);

                    int fill_opacity_value = (int) GLib.Math.round ((float) element.fill.alpha * 100.0f);
                    fill_opacity_entry.set_text (fill_opacity_value.to_string ());
                    int stroke_opacity_value = (int) GLib.Math.round ((float) element.stroke.alpha * 100.0f);
                    stroke_opacity_entry.set_text (stroke_opacity_value.to_string ());

                    fill_mode_drop.set_selected (element.use_gradient ? 1u : 0u);
                    update_color_button (fill_gradient_btn, element.gradient_secondary);
                    fill_gradient_angle_spin.set_value (element.gradient_angle);
                    fill_gradient_color_row.set_visible (element.use_gradient);
                    fill_gradient_angle_row.set_visible (element.use_gradient);
                }
            }

            sync_background_variant_controls ();
        } finally {
            updating = false;
        }
    }

    private void redraw () {
        canvas.queue_draw ();
        owner.refresh_sidebar ();
    }

    private void build_ui () {
        container = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        container.set_vexpand (true);
        container.set_hexpand_set (true);
        container.set_halign (Gtk.Align.END);
        container.add_css_class ("inspector-view");

        var inspector_appbar = new He.AppBar ();
        inspector_appbar.set_size_request (324, -1);
        inspector_appbar.show_left_title_buttons = false;
        inspector_appbar.show_right_title_buttons = true;
        container.append (inspector_appbar);

        var prop_header = new Gtk.Label ("Properties");
        prop_header.add_css_class ("view-title");
        prop_header.set_halign (Gtk.Align.START);
        inspector_appbar.viewtitle_widget = prop_header;

        var main_props_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        main_props_box.set_vexpand (true);
        main_props_box.set_hexpand (true);

        props_area = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        props_area.set_size_request (324, -1);
        props_area.margin_start = 18;
        props_area.margin_bottom = 18;
        props_area.margin_end = 18;
        main_props_box.append (props_area);

        bg_props_area = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        bg_props_area.set_size_request (324, -1);
        bg_props_area.margin_start = 18;
        bg_props_area.margin_bottom = 18;
        bg_props_area.margin_end = 18;
        main_props_box.append (bg_props_area);

        group_props_area = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        group_props_area.set_size_request (324, -1);
        group_props_area.margin_start = 18;
        group_props_area.margin_bottom = 18;
        group_props_area.margin_end = 18;
        main_props_box.append (group_props_area);

        var scrolled = new Gtk.ScrolledWindow ();
        scrolled.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scrolled.set_child (main_props_box);
        container.append (scrolled);

        build_background_section ();
        build_group_section ();
        build_element_section ();
        build_signals ();
    }

    private void build_background_section () {
        // Compositing section
        var compositing_heading = new Gtk.Label ("Compositing") { xalign = 0.0f };
        compositing_heading.add_css_class ("caption-heading");
        bg_props_area.append (compositing_heading);

        bg_effects_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        bg_effects_row.add_css_class ("mini-content-block");
        var effects_label = new Gtk.Label ("Raised Effect");
        effects_label.set_xalign (0.0f);
        effects_label.set_hexpand (true);
        effects_label.add_css_class ("caption");
        bg_effects_row.append (effects_label);
        bg_effects_switch = new Gtk.Switch ();
        bg_effects_switch.set_active (model.use_raised_effect);
        bg_effects_row.append (bg_effects_switch);
        bg_props_area.append (bg_effects_row);

        bg_frame_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        bg_frame_row.add_css_class ("mini-content-block");
        var frame_label = new Gtk.Label ("Toolbox App Frame");
        frame_label.set_xalign (0.0f);
        frame_label.set_hexpand (true);
        frame_label.add_css_class ("caption");
        bg_frame_row.append (frame_label);
        bg_frame_switch = new Gtk.Switch ();
        bg_frame_switch.set_active (model.use_frame_overlay);
        bg_frame_row.append (bg_frame_switch);
        bg_props_area.append (bg_frame_row);

        bg_dev_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        bg_dev_row.add_css_class ("mini-content-block");
        var dev_label = new Gtk.Label ("Developer Badge");
        dev_label.set_xalign (0.0f);
        dev_label.set_hexpand (true);
        dev_label.add_css_class ("caption");
        bg_dev_row.append (dev_label);
        bg_dev_switch = new Gtk.Switch ();
        bg_dev_switch.set_active (model.show_dev_badge);
        bg_dev_row.append (bg_dev_switch);
        bg_props_area.append (bg_dev_row);

        // Color section
        var color_heading = new Gtk.Label ("Color") { xalign = 0.0f, margin_top = 18 };
        color_heading.add_css_class ("caption-heading");
        bg_props_area.append (color_heading);

        bg_variant_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        bg_variant_row.add_css_class ("mini-content-block");
        var bg_variant_label = new Gtk.Label ("Background Preset");
        bg_variant_label.set_xalign (0.0f);
        bg_variant_label.set_hexpand (true);
        bg_variant_label.add_css_class ("caption");
        bg_variant_row.append (bg_variant_label);
        bg_variant_drop = new Gtk.DropDown.from_strings (bg_variant_labels);
        uint initial_index = get_variant_index (model.icon_background_variant);
        bg_variant_drop.set_selected (initial_index);
        bg_variant_row.append (bg_variant_drop);
        bg_props_area.append (bg_variant_row);

        bg_canvas_bg_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        bg_canvas_bg_row.add_css_class ("mini-content-block");
        bg_side_color_btn = create_color_button (model.background);
        bg_side_wall_switch = new Gtk.Switch ();
        bg_side_wall_switch.set_active (model.use_wallpaper);
        var bg_color_label = new Gtk.Label ("Background Color") { xalign = 0.0f, hexpand = true };
        bg_color_label.add_css_class ("caption");
        bg_canvas_bg_row.append (bg_color_label);
        bg_canvas_bg_row.append (bg_side_color_btn);
        bg_props_area.append (bg_canvas_bg_row);

        bg_fill_mode_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        bg_fill_mode_row.add_css_class ("mini-content-block");
        fill_mode_label = new Gtk.Label ("Fill Type");
        fill_mode_label.set_xalign (0.0f);
        fill_mode_label.set_hexpand (true);
        fill_mode_label.add_css_class ("caption");
        bg_fill_mode_row.append (fill_mode_label);
        bg_fill_mode_drop = new Gtk.DropDown.from_strings (bg_fill_modes);
        bg_fill_mode_drop.set_selected (model.use_gradient ? 1u : 0u);
        bg_fill_mode_row.append (bg_fill_mode_drop);
        bg_props_area.append (bg_fill_mode_row);

        bg_gradient_container = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        bg_gradient_container.add_css_class ("mini-content-block");
        var gradient_color_label = new Gtk.Label ("Gradient End Color");
        gradient_color_label.set_xalign (0.0f);
        gradient_color_label.set_hexpand (true);
        gradient_color_label.add_css_class ("caption");
        bg_gradient_end_btn = create_color_button (model.gradient_secondary);
        bg_gradient_end_btn.set_halign (Gtk.Align.END);
        var gradient_color_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        gradient_color_row.append (gradient_color_label);
        gradient_color_row.append (bg_gradient_end_btn);
        bg_gradient_container.append (gradient_color_row);
        var gradient_angle_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        var gradient_angle_label = new Gtk.Label ("Gradient Angle");
        gradient_angle_label.set_xalign (0.0f);
        gradient_angle_label.set_hexpand (true);
        gradient_angle_label.add_css_class ("caption");
        gradient_angle_row.append (gradient_angle_label);
        bg_gradient_angle_spin = new Gtk.SpinButton.with_range (0, 324, 1);
        bg_gradient_angle_spin.set_value (model.gradient_angle);
        gradient_angle_row.append (bg_gradient_angle_spin);
        bg_gradient_container.append (gradient_angle_row);
        bg_props_area.append (bg_gradient_container);

        var grid_menu_btn = new Gtk.MenuButton ();
        grid_preview_picture = new Gtk.Image ();
        grid_preview_picture.icon_name = ICON_GRID_DARK_MINI;
        grid_menu_btn.set_tooltip_text ("Grid overlay options");
        grid_menu_btn.set_child (grid_preview_picture);
        var grid_pop = new Gtk.Popover ();
        var grid_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        grid_box.set_margin_start (12);
        grid_box.set_margin_end (12);
        grid_box.set_margin_top (12);
        grid_box.set_margin_bottom (12);
        var grid_switch_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        var grid_switch_label = new Gtk.Label ("Show Grid");
        grid_switch_label.set_xalign (0.0f);
        grid_switch_label.set_hexpand (true);
        grid_switch_label.add_css_class ("caption");
        grid_overlay_switch = new Gtk.Switch ();
        grid_switch_row.append (grid_switch_label);
        grid_switch_row.append (grid_overlay_switch);
        grid_box.append (grid_switch_row);
        var grid_variant_group = new Gtk.Box (Gtk.Orientation.VERTICAL, 3);
        var grid_variant_label = new Gtk.Label ("Appearance");
        grid_variant_label.set_xalign (0.0f);
        grid_variant_label.add_css_class ("caption");
        grid_variant_drop = new Gtk.DropDown.from_strings (new string[] { "Dark Grid", "Light Grid" });
        grid_variant_drop.set_hexpand (true);
        grid_variant_group.append (grid_variant_label);
        grid_variant_group.append (grid_variant_drop);
        grid_box.append (grid_variant_group);
        grid_pop.set_child (grid_box);
        grid_menu_btn.set_popover (grid_pop);
        inspector_toolbar_append_menu (grid_menu_btn);

        zoom_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0.25, 4.0, 0.25);
        zoom_scale.set_value (model.zoom);
        zoom_scale.set_valign (Gtk.Align.CENTER);
        zoom_scale.set_vexpand (true);
        zoom_scale.set_margin_top (18);
        zoom_scale.set_margin_bottom (18);
        zoom_scale.set_margin_start (12);
        zoom_scale.set_margin_end (12);
        zoom_label = new Gtk.Label ("---%");
        zoom_label.set_halign (Gtk.Align.CENTER);
        double initial_zoom_percent = GLib.Math.floor (zoom_scale.get_value () * 100.0);
        zoom_label.set_label (((int) initial_zoom_percent).to_string () + "%");
        zoom_label.set_max_width_chars (4);
        zoom_label.add_css_class ("numeric");
        var zoom_btn = new Gtk.MenuButton ();
        zoom_btn.set_tooltip_text ("Zoom level");
        zoom_btn.set_size_request (80, -1);
        var zoom_pop = new Gtk.Popover ();
        var pop_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        pop_box.set_size_request (324, 64);
        pop_box.append (zoom_scale);
        zoom_pop.set_child (pop_box);
        zoom_btn.set_popover (zoom_pop);
        var zoom_button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        var zoom_image = new Gtk.Image.from_icon_name ("zoom-fit-best-symbolic");
        zoom_image.margin_start = 6;
        zoom_button_box.append (zoom_image);
        zoom_button_box.append (zoom_label);
        zoom_btn.set_child (zoom_button_box);
        inspector_toolbar_append_menu (zoom_btn);

        set_grid_initial_state ();
    }

    private void inspector_toolbar_append_menu (Gtk.Widget widget) {
        if (main_appbar == null)return;
        main_appbar.append_menu (widget);
    }

    private void set_grid_initial_state () {
        bool prev = updating;
        updating = true;
        grid_overlay_switch.set_active (model.show_grid_overlay);
        grid_variant_drop.set_selected (model.grid_overlay_variant == GridOverlayVariant.DARK ? 0u : 1u);
        updating = prev;
        update_grid_preview_icon ();
        update_grid_controls_sensitivity ();
    }

    private void build_group_section () {
        // Compositing section
        var compositing_heading = new Gtk.Label ("Compositing") { xalign = 0.0f };
        compositing_heading.add_css_class ("caption-heading");
        group_props_area.append (compositing_heading);

        group_blend_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        group_blend_box.add_css_class ("mini-content-block");
        var group_blend_label = new Gtk.Label ("Blend Mode") { xalign = 0.0f, hexpand = true };
        group_blend_label.add_css_class ("caption");
        group_blend_box.append (group_blend_label);
        group_blend_drop = new Gtk.DropDown.from_strings (blend_labels);
        group_blend_box.append (group_blend_drop);
        group_props_area.append (group_blend_box);

        // Effects section
        var effects_heading = new Gtk.Label ("Effects") { xalign = 0.0f, margin_top = 18 };
        effects_heading.add_css_class ("caption-heading");
        group_props_area.append (effects_heading);

        var group_sheen_layer_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        group_sheen_layer_box.add_css_class ("mini-content-block");
        var group_sheen_layer_label = new Gtk.Label ("Sheen Layer") { xalign = 0.0f, hexpand = true };
        group_sheen_layer_label.add_css_class ("caption");
        group_sheen_layer_box.append (group_sheen_layer_label);
        group_sheen_layer_toggle = new Gtk.Switch ();
        group_sheen_layer_toggle.set_valign (Gtk.Align.CENTER);
        group_sheen_layer_box.append (group_sheen_layer_toggle);
        group_props_area.append (group_sheen_layer_box);

        var group_shadow_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        group_shadow_box.add_css_class ("mini-content-block");
        var group_shadow_label = new Gtk.Label ("Shadow") { xalign = 0.0f, hexpand = true };
        group_shadow_label.add_css_class ("caption");
        group_shadow_box.append (group_shadow_label);
        group_shadow_toggle = new Gtk.Switch ();
        group_shadow_toggle.set_valign (Gtk.Align.CENTER);
        group_shadow_box.append (group_shadow_toggle);
        group_props_area.append (group_shadow_box);

        var group_shadow_mode_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        group_shadow_mode_box.add_css_class ("mini-content-block");
        var group_shadow_mode_label = new Gtk.Label ("Shadow Mode") { xalign = 0.0f, hexpand = true };
        group_shadow_mode_label.add_css_class ("caption");
        group_shadow_mode_box.append (group_shadow_mode_label);
        group_shadow_mode_drop = new Gtk.DropDown.from_strings (new string[] { "Mono", "Chromatic" });
        group_shadow_mode_box.append (group_shadow_mode_drop);
        group_props_area.append (group_shadow_mode_box);

        var group_effect_scope_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        group_effect_scope_box.add_css_class ("mini-content-block");
        var group_effect_scope_label = new Gtk.Label ("Effect Scope") { xalign = 0.0f, hexpand = true };
        group_effect_scope_label.add_css_class ("caption");
        group_effect_scope_box.append (group_effect_scope_label);
        group_effect_scope_drop = new Gtk.DropDown.from_strings (effect_scope_labels);
        group_effect_scope_box.append (group_effect_scope_drop);
        group_props_area.append (group_effect_scope_box);
    }

    private void build_element_section () {
        // Compositing section
        var compositing_heading = new Gtk.Label ("Compositing") { xalign = 0.0f };
        compositing_heading.add_css_class ("caption-heading");
        props_area.append (compositing_heading);

        // Combined Position and Alignment box
        pos_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 12);
        pos_box.add_css_class ("mini-content-block");

        // Position controls (left side)
        var pos_controls = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        pos_controls.set_hexpand (true);

        x_entry = new Gtk.SpinButton.with_range (0, 109, 1);
        y_entry = new Gtk.SpinButton.with_range (0, 109, 1);
        var x_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        var x_label = new Gtk.Label ("X") { xalign = 0.0f, hexpand = true };
        x_label.add_css_class ("caption");
        x_box.append (x_label);
        x_box.append (x_entry);
        pos_controls.append (x_box);

        var y_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        var y_label = new Gtk.Label ("Y") { xalign = 0.0f, hexpand = true };
        y_label.add_css_class ("caption");
        y_box.append (y_label);
        y_box.append (y_entry);
        pos_controls.append (y_box);

        pos_box.append (pos_controls);

        // Alignment controls (right side)
        align_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        align_box.set_hexpand (false);

        align_grid = new Gtk.Grid ();
        align_grid.set_column_homogeneous (true);
        align_grid.set_row_homogeneous (true);
        align_grid.set_halign (Gtk.Align.END);
        align_grid.set_valign (Gtk.Align.CENTER);
        align_grid.set_hexpand (false);

        align_left_btn = create_align_icon_button (ICON_ALIGN_LEFT, "Align left");
        align_center_btn = create_align_icon_button (ICON_ALIGN_CENTER, "Center both");
        align_right_btn = create_align_icon_button (ICON_ALIGN_RIGHT, "Align right");
        align_top_btn = create_align_icon_button (ICON_ALIGN_TOP, "Align top");
        align_bottom_btn = create_align_icon_button (ICON_ALIGN_BOTTOM, "Align bottom");

        align_grid.attach (align_top_btn, 1, 0, 1, 1);
        align_grid.attach (align_left_btn, 0, 1, 1, 1);
        align_grid.attach (align_center_btn, 1, 1, 1, 1);
        align_grid.attach (align_right_btn, 2, 1, 1, 1);
        align_grid.attach (align_bottom_btn, 1, 2, 1, 1);

        align_box.append (align_grid);
        pos_box.append (align_box);

        props_area.append (pos_box);

        size_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        size_box.add_css_class ("mini-content-block");
        var size_label_header = new Gtk.Label ("Size") { xalign = 0.0f, hexpand = true };
        size_label_header.add_css_class ("caption");
        size_box.append (size_label_header);

        var size_grid = new Gtk.Grid ();
        size_grid.set_column_spacing (6);
        size_grid.set_row_spacing (6);
        size_grid.set_halign (Gtk.Align.FILL);
        size_grid.set_hexpand (true);

        w_entry = new Gtk.SpinButton.with_range (1, 109, 1);
        w_entry.set_hexpand (true);
        h_entry = new Gtk.SpinButton.with_range (1, 109, 1);
        h_entry.set_hexpand (true);

        var width_label = new Gtk.Label ("W") { xalign = 0.0f };
        width_label.add_css_class ("caption");
        var height_label = new Gtk.Label ("H") { xalign = 0.0f };
        height_label.add_css_class ("caption");

        size_lock_toggle = new Gtk.ToggleButton ();
        size_lock_toggle.add_css_class ("flat");
        size_lock_toggle.add_css_class ("circular");
        size_lock_toggle.set_focus_on_click (false);
        size_lock_toggle.set_tooltip_text ("Lock proportions");
        size_lock_toggle.set_halign (Gtk.Align.CENTER);
        size_lock_toggle.set_valign (Gtk.Align.CENTER);
        size_lock_picture = create_icon_picture (ICON_UNLOCKED);
        size_lock_toggle.set_child (size_lock_picture);

        size_grid.attach (width_label, 0, 0, 1, 1);
        size_grid.attach (w_entry, 1, 0, 1, 1);
        size_grid.attach (size_lock_toggle, 2, 0, 1, 2);
        size_grid.attach (height_label, 0, 1, 1, 1);
        size_grid.attach (h_entry, 1, 1, 1, 1);

        size_box.append (size_grid);
        props_area.append (size_box);

        corner_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        corner_box.add_css_class ("mini-content-block");

        var corner_header_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        var corner_radius_label = new Gtk.Label ("Corner Radius") { xalign = 0.0f, hexpand = true };
        corner_radius_label.add_css_class ("caption");

        corner_radius_lock_toggle = new Gtk.ToggleButton ();
        corner_radius_lock_toggle.add_css_class ("flat");
        corner_radius_lock_toggle.add_css_class ("circular");
        corner_radius_lock_toggle.set_focus_on_click (false);
        corner_radius_lock_toggle.set_tooltip_text ("Lock corner radii");
        corner_radius_lock_toggle.set_halign (Gtk.Align.END);
        corner_radius_lock_toggle.set_valign (Gtk.Align.CENTER);
        corner_radius_lock_picture = create_icon_picture (ICON_LOCKED);
        corner_radius_lock_toggle.set_child (corner_radius_lock_picture);
        corner_radius_lock_toggle.set_active (true);

        corner_header_row.append (corner_radius_label);
        corner_box.append (corner_header_row);

        corner_entries_container = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        corner_entries_container.set_halign (Gtk.Align.END);
        corner_entries_container.set_valign (Gtk.Align.CENTER);
        corner_entries_container.set_hexpand (true);

        // Unified entry for locked state
        corner_unified_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        corner_radius_unified_entry = create_corner_entry ();
        corner_radius_unified_entry.set_tooltip_text ("All corners");
        corner_radius_unified_entry.set_hexpand (true);
        corner_unified_row.append (corner_radius_unified_entry);

        // Grid for unlocked state (2x2)
        corner_grid = new Gtk.Grid ();
        corner_grid.set_column_spacing (6);
        corner_grid.set_row_spacing (6);
        corner_grid.set_column_homogeneous (true);
        corner_grid.set_row_homogeneous (true);
        corner_grid.set_halign (Gtk.Align.CENTER);
        corner_grid.set_valign (Gtk.Align.CENTER);
        corner_grid.set_hexpand (false);

        corner_radius_tl_entry = create_corner_entry ();
        corner_radius_tl_entry.set_tooltip_text ("Top-left corner radius");
        corner_radius_tr_entry = create_corner_entry ();
        corner_radius_tr_entry.set_tooltip_text ("Top-right corner radius");
        corner_radius_br_entry = create_corner_entry ();
        corner_radius_br_entry.set_tooltip_text ("Bottom-right corner radius");
        corner_radius_bl_entry = create_corner_entry ();
        corner_radius_bl_entry.set_tooltip_text ("Bottom-left corner radius");

        corner_grid.attach (corner_radius_tl_entry, 0, 0, 1, 1);
        corner_grid.attach (corner_radius_tr_entry, 1, 0, 1, 1);
        corner_grid.attach (corner_radius_bl_entry, 0, 1, 1, 1);
        corner_grid.attach (corner_radius_br_entry, 1, 1, 1, 1);
        corner_grid.set_visible (false);

        corner_entries_container.append (corner_unified_row);
        corner_entries_container.append (corner_grid);
        corner_header_row.append (corner_entries_container);
        corner_header_row.append (corner_radius_lock_toggle);
        corner_box.set_visible (false);
        props_area.append (corner_box);

        line_controls_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        line_controls_box.add_css_class ("mini-content-block");
        line_length_spin = new Gtk.SpinButton.with_range (1, 155, 1);
        line_angle_spin = new Gtk.SpinButton.with_range (0, 359, 1);
        var line_length_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        var line_length_label = new Gtk.Label ("Length") { xalign = 0.0f, hexpand = true };
        line_length_label.add_css_class ("caption");
        line_length_row.append (line_length_label);
        line_length_row.append (line_length_spin);
        line_controls_box.append (line_length_row);
        var line_angle_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        var line_angle_label = new Gtk.Label ("Angle") { xalign = 0.0f, hexpand = true };
        line_angle_label.add_css_class ("caption");
        line_angle_row.append (line_angle_label);
        line_angle_row.append (line_angle_spin);
        line_controls_box.append (line_angle_row);
        line_controls_box.set_visible (false);
        props_area.append (line_controls_box);

        element_angle_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        element_angle_box.add_css_class ("mini-content-block");
        element_angle_spin = new Gtk.SpinButton.with_range (0, 359, 1);
        var rotation_label = new Gtk.Label ("Rotation") { xalign = 0.0f, hexpand = true };
        rotation_label.add_css_class ("caption");
        element_angle_box.append (rotation_label);
        element_angle_box.append (element_angle_spin);
        props_area.append (element_angle_box);

        // Color section
        var color_heading = new Gtk.Label ("Color") { xalign = 0.0f, margin_top = 18 };
        color_heading.add_css_class ("caption-heading");
        props_area.append (color_heading);

        fill_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        fill_box.add_css_class ("mini-content-block");
        fill_label = new Gtk.Label ("Fill Color");
        fill_label.set_xalign (0.0f);
        fill_label.set_hexpand (true);
        fill_label.add_css_class ("caption");
        Gdk.RGBA default_fill = { 0 };
        default_fill.parse ("#ffffff");
        fill_btn = create_color_button (default_fill);
        fill_opacity_entry = create_opacity_entry ();
        fill_opacity_entry.set_tooltip_text ("Fill opacity (0-100)");
        var fill_color_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        fill_color_row.append (fill_label);
        fill_color_row.append (fill_btn);
        fill_color_row.append (fill_opacity_entry);
        fill_box.append (fill_color_row);

        fill_mode_label = new Gtk.Label ("Fill Mode");
        fill_mode_label.set_xalign (0.0f);
        fill_mode_label.set_hexpand (true);
        fill_mode_label.add_css_class ("caption");
        fill_mode_drop = new Gtk.DropDown.from_strings (new string[] { "Solid", "Gradient" });
        var fill_mode_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        fill_mode_row.append (fill_mode_label);
        fill_mode_row.append (fill_mode_drop);
        fill_box.append (fill_mode_row);

        fill_gradient_btn = create_color_button ({ 0.533f, 0.533f, 0.533f, 1.0f });
        fill_gradient_angle_label = new Gtk.Label ("Gradient End");
        fill_gradient_angle_label.set_xalign (0.0f);
        fill_gradient_angle_label.set_hexpand (true);
        fill_gradient_angle_label.add_css_class ("caption");
        fill_gradient_color_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        fill_gradient_color_row.append (fill_gradient_angle_label);
        fill_gradient_color_row.append (fill_gradient_btn);
        fill_gradient_color_row.set_visible (false);
        fill_box.append (fill_gradient_color_row);

        fill_gradient_angle_spin = new Gtk.SpinButton.with_range (0, 324, 1);
        fill_gradient_angle_spin.set_value (0.0);
        fill_gradient_angle_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        var gradient_angle_label2 = new Gtk.Label ("Gradient Angle") { xalign = 0.0f, hexpand = true };
        gradient_angle_label2.add_css_class ("caption");
        fill_gradient_angle_row.append (gradient_angle_label2);
        fill_gradient_angle_row.append (fill_gradient_angle_spin);
        fill_gradient_angle_row.set_visible (false);
        fill_box.append (fill_gradient_angle_row);

        props_area.append (fill_box);

        stroke_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
        stroke_box.add_css_class ("mini-content-block");
        stroke_label = new Gtk.Label ("Stroke Color");
        stroke_label.set_xalign (0.0f);
        stroke_label.set_hexpand (true);
        stroke_label.add_css_class ("caption");
        Gdk.RGBA default_stroke = { 0 };
        default_stroke.parse ("#000000");
        stroke_btn = create_color_button (default_stroke);
        stroke_opacity_entry = create_opacity_entry ();
        stroke_opacity_entry.set_tooltip_text ("Stroke opacity (0-100)");
        var stroke_color_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        stroke_color_row.append (stroke_label);
        stroke_color_row.append (stroke_btn);
        stroke_color_row.append (stroke_opacity_entry);
        stroke_box.append (stroke_color_row);

        stroke_width_spin = new Gtk.SpinButton.with_range (0, 20, 0.5);
        stroke_width_spin.set_digits (1);
        var stroke_width_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        var stroke_width_label = new Gtk.Label ("Stroke Width") { xalign = 0.0f, hexpand = true };
        stroke_width_label.add_css_class ("caption");
        stroke_width_row.append (stroke_width_label);
        stroke_width_row.append (stroke_width_spin);
        stroke_box.append (stroke_width_row);

        props_area.append (stroke_box);
    }

    private void build_signals () {
        bg_variant_drop.notify["selected"].connect (() => {
            if (updating)return;
            uint idx = bg_variant_drop.get_selected ();
            if (idx >= bg_variant_values.length)return;
            IconBackgroundVariant variant = bg_variant_values[idx];
            model.icon_background_variant = variant;
            if (variant != IconBackgroundVariant.NONE) {
                model.use_gradient = true;
            }
            sync_background_variant_controls ();
            owner.apply_view_background_css ();
            canvas.queue_draw ();
        });

        bg_side_color_btn.clicked.connect (() => {
            var current = get_color_button_color (bg_side_color_btn);
            show_color_picker_popover (bg_side_color_btn, current, (color) => {
                update_bg_color (color);
            });
        });

        bg_side_wall_switch.notify["active"].connect (() => {
            if (updating)return;
            apply_wallpaper_state (bg_side_wall_switch.get_active ());
        });

        bg_fill_mode_drop.notify["selected"].connect (() => {
            if (updating)return;
            uint selected = bg_fill_mode_drop.get_selected ();
            model.use_gradient = (selected == 1u);
            sync_gradient_controls_visibility ();
            owner.apply_view_background_css ();
            canvas.queue_draw ();
        });

        bg_gradient_end_btn.clicked.connect (() => {
            var current = get_color_button_color (bg_gradient_end_btn);
            show_color_picker_popover (bg_gradient_end_btn, current, (color) => {
                update_gradient_secondary_color (color);
            });
        });

        bg_gradient_angle_spin.value_changed.connect (() => {
            if (updating)return;
            model.gradient_angle = bg_gradient_angle_spin.get_value ();
            if (model.use_gradient) {
                owner.apply_view_background_css ();
                canvas.queue_draw ();
            }
        });

        bg_effects_switch.notify["active"].connect (() => {
            if (updating)return;
            model.use_raised_effect = bg_effects_switch.get_active ();
            canvas.queue_draw ();
        });

        bg_frame_switch.notify["active"].connect (() => {
            if (updating)return;
            model.use_frame_overlay = bg_frame_switch.get_active ();
            canvas.queue_draw ();
        });

        bg_dev_switch.notify["active"].connect (() => {
            if (updating)return;
            model.show_dev_badge = bg_dev_switch.get_active ();
            canvas.queue_draw ();
        });

        grid_overlay_switch.notify["active"].connect (() => {
            if (updating)return;
            model.show_grid_overlay = grid_overlay_switch.get_active ();
            update_grid_controls_sensitivity ();
            canvas.queue_draw ();
        });

        grid_variant_drop.notify["selected"].connect (() => {
            if (updating)return;
            uint idx = grid_variant_drop.get_selected ();
            model.grid_overlay_variant = (idx == 0u) ? GridOverlayVariant.DARK : GridOverlayVariant.LIGHT;
            update_grid_preview_icon ();
            if (model.show_grid_overlay) {
                canvas.queue_draw ();
            }
        });

        zoom_scale.value_changed.connect ((s) => {
            model.zoom = (float) zoom_scale.get_value ();
            double zoom_percent = GLib.Math.floor (zoom_scale.get_value () * 100.0);
            zoom_label.set_label (((int) zoom_percent).to_string () + "%");
            canvas.set_size_request ((int) (128 * model.zoom), (int) (128 * model.zoom));
            canvas.queue_draw ();
        });

        x_entry.value_changed.connect (() => {
            if (updating)return;
            var element = owner.get_selected_element ();
            if (element == null)return;
            double bounded_x = GLib.Math.fmax (0.0, GLib.Math.fmin (x_entry.get_value (), 109.0));
            element.x = (float) bounded_x;
            redraw ();
        });

        y_entry.value_changed.connect (() => {
            if (updating)return;
            var element = owner.get_selected_element ();
            if (element == null)return;
            double bounded_y = GLib.Math.fmax (0.0, GLib.Math.fmin (y_entry.get_value (), 109.0));
            element.y = (float) bounded_y;
            redraw ();
        });

        w_entry.value_changed.connect (() => {
            if (updating)return;
            var element = owner.get_selected_element ();
            if (element == null)return;
            if (element.type == ElementType.LINE)return;
            double bounded_w = GLib.Math.fmax (1.0, GLib.Math.fmin (w_entry.get_value (), 109.0));

            if (size_lock_toggle.get_active () && element.height > 0.0f) {
                double ratio = element.height / element.width;
                double new_h = bounded_w * ratio;
                new_h = GLib.Math.fmax (1.0, GLib.Math.fmin (new_h, 109.0));
                element.height = (float) new_h;
                updating = true;
                h_entry.set_value (new_h);
                updating = false;
            }

            element.width = (float) bounded_w;
            apply_corner_radius_constraints (element);
            update_rotation_visibility ();
            redraw ();
        });

        h_entry.value_changed.connect (() => {
            if (updating)return;
            var element = owner.get_selected_element ();
            if (element == null)return;
            if (element.type == ElementType.LINE)return;
            double bounded_h = GLib.Math.fmax (1.0, GLib.Math.fmin (h_entry.get_value (), 109.0));

            if (size_lock_toggle.get_active () && element.width > 0.0f) {
                double ratio = element.width / element.height;
                double new_w = bounded_h * ratio;
                new_w = GLib.Math.fmax (1.0, GLib.Math.fmin (new_w, 109.0));
                element.width = (float) new_w;
                updating = true;
                w_entry.set_value (new_w);
                updating = false;
            }

            element.height = (float) bounded_h;
            apply_corner_radius_constraints (element);
            update_rotation_visibility ();
            redraw ();
        });

        stroke_width_spin.value_changed.connect (() => {
            if (updating)return;
            var element = owner.get_selected_element ();
            if (element == null)return;
            element.stroke_width = (float) stroke_width_spin.get_value ();
            apply_svg_stroke_width_to_element (element);
            redraw ();
        });

        line_length_spin.value_changed.connect (() => {
            if (updating)return;
            var element = owner.get_selected_element ();
            if (element == null)return;
            if (element.type != ElementType.LINE)return;
            float value = (float) GLib.Math.fmax (line_length_spin.get_value (), 1.0);
            element.line_length = value;
            refresh_line_deltas (element);
            redraw ();
        });

        line_angle_spin.value_changed.connect (() => {
            if (updating)return;
            var element = owner.get_selected_element ();
            if (element == null)return;
            if (element.type != ElementType.LINE)return;
            element.line_angle = line_angle_spin.get_value ();
            refresh_line_deltas (element);
            redraw ();
        });

        element_angle_spin.value_changed.connect (() => {
            if (updating)return;
            var element = owner.get_selected_element ();
            if (element == null)return;
            element.element_angle = element_angle_spin.get_value ();
            redraw ();
        });

        fill_btn.clicked.connect (() => {
            var current = get_color_button_color (fill_btn);
            show_color_picker_popover (fill_btn, current, (color) => {
                var element = owner.get_selected_element ();
                if (element == null)return;
                element.fill = color;
                update_color_button (fill_btn, color);
                apply_svg_fill_to_element (element);
                if (element.use_gradient) {
                    fill_gradient_btn.set_data<Gdk.RGBA?> ("current_color", element.gradient_secondary);
                }
                redraw ();
            });
        });

        stroke_btn.clicked.connect (() => {
            var current = get_color_button_color (stroke_btn);
            show_color_picker_popover (stroke_btn, current, (color) => {
                var element = owner.get_selected_element ();
                if (element == null)return;
                element.stroke = color;
                update_color_button (stroke_btn, color);
                apply_svg_stroke_to_element (element);
                redraw ();
            });
        });

        fill_opacity_entry.changed.connect (() => {
            if (updating)return;
            var element = owner.get_selected_element ();
            if (element == null)return;
            string raw = fill_opacity_entry.get_text ();
            string sanitized = IconiUtils.sanitize_numeric_text (raw, 3u);
            if (sanitized != raw) {
                fill_opacity_entry.set_text (sanitized.length > 0 ? sanitized : "100");
                fill_opacity_entry.set_position (fill_opacity_entry.get_text ().length);
                return;
            }
            if (sanitized.length == 0) {
                fill_opacity_entry.set_text ("100");
                fill_opacity_entry.set_position (3);
                return;
            }
            int value = int.parse (sanitized);
            if (value > 100) {
                fill_opacity_entry.set_text ("100");
                fill_opacity_entry.set_position (3);
                return;
            }
            element.fill.alpha = (float) (value / 100.0);
            apply_svg_fill_to_element (element);
            redraw ();
        });

        stroke_opacity_entry.changed.connect (() => {
            if (updating)return;
            var element = owner.get_selected_element ();
            if (element == null)return;
            string raw = stroke_opacity_entry.get_text ();
            string sanitized = IconiUtils.sanitize_numeric_text (raw, 3u);
            if (sanitized != raw) {
                stroke_opacity_entry.set_text (sanitized.length > 0 ? sanitized : "100");
                stroke_opacity_entry.set_position (stroke_opacity_entry.get_text ().length);
                return;
            }
            if (sanitized.length == 0) {
                stroke_opacity_entry.set_text ("100");
                stroke_opacity_entry.set_position (3);
                return;
            }
            int value = int.parse (sanitized);
            if (value > 100) {
                stroke_opacity_entry.set_text ("100");
                stroke_opacity_entry.set_position (3);
                return;
            }
            element.stroke.alpha = (float) (value / 100.0);
            apply_svg_stroke_to_element (element);
            redraw ();
        });

        fill_mode_drop.notify["selected"].connect (() => {
            if (updating)return;
            var element = owner.get_selected_element ();
            if (element == null)return;
            element.use_gradient = (fill_mode_drop.get_selected () == 1u);
            fill_gradient_color_row.set_visible (element.use_gradient);
            fill_gradient_angle_row.set_visible (element.use_gradient);
            redraw ();
        });

        fill_gradient_btn.clicked.connect (() => {
            var current = get_color_button_color (fill_gradient_btn);
            show_color_picker_popover (fill_gradient_btn, current, (color) => {
                var element = owner.get_selected_element ();
                if (element == null)return;
                element.gradient_secondary = color;
                if (element.use_gradient) {
                    update_color_button (fill_gradient_btn, color);
                    redraw ();
                }
            });
        });

        fill_gradient_angle_spin.value_changed.connect (() => {
            if (updating)return;
            var element = owner.get_selected_element ();
            if (element == null)return;
            element.gradient_angle = fill_gradient_angle_spin.get_value ();
            if (element.use_gradient) {
                redraw ();
            }
        });

        corner_radius_unified_entry.changed.connect (() => {
            if (updating)return;
            var element = owner.get_selected_element ();
            if (element == null)return;
            if (element.type != ElementType.RECTANGLE)return;
            string raw = corner_radius_unified_entry.get_text ();
            string sanitized = IconiUtils.sanitize_numeric_text (raw, 3u);
            if (sanitized != raw) {
                corner_radius_unified_entry.set_text (sanitized.length > 0 ? sanitized : "0");
                corner_radius_unified_entry.set_position (corner_radius_unified_entry.get_text ().length);
                return;
            }
            if (sanitized.length == 0) {
                corner_radius_unified_entry.set_text ("0");
                corner_radius_unified_entry.set_position (1);
                return;
            }
            int value = int.parse (sanitized);
            if (value > 999) {
                corner_radius_unified_entry.set_text ("999");
                corner_radius_unified_entry.set_position (3);
                return;
            }
            float radius = (float) value;
            element.corner_radius_top_left = radius;
            element.corner_radius_top_right = radius;
            element.corner_radius_bottom_right = radius;
            element.corner_radius_bottom_left = radius;
            apply_corner_radius_constraints (element);
            redraw ();
        });

        corner_radius_tl_entry.changed.connect (() => {
            handle_corner_radius_entry (CornerHandle.TOP_LEFT, corner_radius_tl_entry);
        });
        corner_radius_tr_entry.changed.connect (() => {
            handle_corner_radius_entry (CornerHandle.TOP_RIGHT, corner_radius_tr_entry);
        });
        corner_radius_br_entry.changed.connect (() => {
            handle_corner_radius_entry (CornerHandle.BOTTOM_RIGHT, corner_radius_br_entry);
        });
        corner_radius_bl_entry.changed.connect (() => {
            handle_corner_radius_entry (CornerHandle.BOTTOM_LEFT, corner_radius_bl_entry);
        });

        corner_radius_lock_toggle.toggled.connect (() => {
            update_corner_lock_icon ();
            update_corner_radius_visibility ();
            var element = owner.get_selected_element ();
            if (element != null) {
                element.corner_radius_locked = corner_radius_lock_toggle.get_active ();
                apply_corner_radius_constraints (element);
                canvas.queue_draw ();
            }
        });

        size_lock_toggle.toggled.connect (() => {
            update_size_lock_icon ();
            update_rotation_visibility ();
        });

        align_left_btn.clicked.connect (() => { align_selected_element_horizontal (0); });
        align_center_btn.clicked.connect (() => {
            align_selected_element_horizontal (1);
            align_selected_element_vertical (1);
        });
        align_right_btn.clicked.connect (() => { align_selected_element_horizontal (2); });
        align_top_btn.clicked.connect (() => { align_selected_element_vertical (0); });
        align_bottom_btn.clicked.connect (() => { align_selected_element_vertical (2); });

        group_blend_drop.notify["selected"].connect (() => {
            if (updating)return;
            var group = owner.get_selected_group ();
            if (group == null)return;
            group.blend_mode = blend_values[group_blend_drop.get_selected ()];
            canvas.queue_draw ();
        });

        group_sheen_layer_toggle.notify["active"].connect (() => {
            if (updating)return;
            var group = owner.get_selected_group ();
            if (group == null)return;
            group.use_sheen_layer = group_sheen_layer_toggle.get_active ();
            canvas.queue_draw ();
        });

        group_shadow_toggle.notify["active"].connect (() => {
            if (updating)return;
            var group = owner.get_selected_group ();
            if (group == null)return;
            group.use_shadow = group_shadow_toggle.get_active ();
            canvas.queue_draw ();
        });

        group_shadow_mode_drop.notify["selected"].connect (() => {
            if (updating)return;
            var group = owner.get_selected_group ();
            if (group == null)return;
            group.shadow_chromatic = (group_shadow_mode_drop.get_selected () == 1u);
            canvas.queue_draw ();
        });

        group_effect_scope_drop.notify["selected"].connect (() => {
            if (updating)return;
            var group = owner.get_selected_group ();
            if (group == null)return;
            group.effect_scope = (group_effect_scope_drop.get_selected () == 1u) ? GroupEffectScope.COMBINED : GroupEffectScope.INDIVIDUAL;
            canvas.queue_draw ();
        });
    }

    private void update_bg_color (Gdk.RGBA rgba) {
        model.background = rgba;
        bool prev = updating;
        updating = true;
        update_color_button (bg_side_color_btn, rgba);
        updating = prev;
        sync_gradient_controls_visibility ();
        owner.apply_view_background_css ();
        canvas.queue_draw ();
    }

    private void update_gradient_secondary_color (Gdk.RGBA rgba) {
        model.gradient_secondary = rgba;
        bool prev = updating;
        updating = true;
        update_color_button (bg_gradient_end_btn, rgba);
        updating = prev;
        if (model.use_gradient) {
            owner.apply_view_background_css ();
            canvas.queue_draw ();
        }
    }

    private uint get_variant_index (IconBackgroundVariant variant) {
        for (int i = 0; i < bg_variant_values.length; i++) {
            if (bg_variant_values[i] == variant) {
                return (uint) i;
            }
        }
        return 0u;
    }

    private void apply_wallpaper_state (bool state) {
        model.use_wallpaper = state;
        bool prev = updating;
        updating = true;
        bg_side_wall_switch.set_active (state);
        updating = prev;
        owner.apply_view_background_css ();
    }

    private void sync_gradient_controls_visibility () {
        bool custom_variant = (model.icon_background_variant == IconBackgroundVariant.NONE);
        bool show = model.use_gradient && custom_variant;
        bg_gradient_container.set_visible (show);
    }

    private void sync_background_variant_controls () {
        bool prev = updating;
        updating = true;
        uint variant_index = get_variant_index (model.icon_background_variant);
        bg_variant_drop.set_selected (variant_index);
        if (bg_fill_mode_drop != null) {
            uint fill_index = model.use_gradient ? 1u : 0u;
            if (model.icon_background_variant != IconBackgroundVariant.NONE) {
                fill_index = 1u;
            }
            bg_fill_mode_drop.set_selected (fill_index);
        }
        updating = prev;

        bool custom = (model.icon_background_variant == IconBackgroundVariant.NONE);
        bg_canvas_bg_row.set_visible (custom);
        bg_fill_mode_row.set_visible (custom);

        sync_gradient_controls_visibility ();
    }

    private void update_sidebar_visibility (bool show) {
        container.set_visible (show);
        if (show) {
            main_appbar.set_margin_end (owner.INSPECTOR_WIDTH + 12);
            canvas.set_margin_end (owner.INSPECTOR_WIDTH + 12);
            main_appbar.show_right_title_buttons = false;
        } else {
            main_appbar.set_margin_end (0);
            canvas.set_margin_end (0);
            main_appbar.show_right_title_buttons = true;
        }
    }

    private Gtk.Button create_color_button (Gdk.RGBA initial_color) {
        var btn = new He.Button ("", "");
        btn.add_css_class ("flat");
        btn.set_tooltip_text ("Click to choose color");
        var area = new Gtk.DrawingArea ();
        area.set_content_width (48);
        area.set_content_height (32);
        btn.set_data<Gdk.RGBA?> ("current_color", initial_color);
        area.set_draw_func ((da, cr, w, h) => {
            Gdk.RGBA? stored = btn.get_data<Gdk.RGBA?> ("current_color");
            Gdk.RGBA use = stored ?? initial_color;
            cr.set_source_rgba (use.red, use.green, use.blue, use.alpha);
            cr.rectangle (0.0, 0.0, w, h);
            cr.fill ();
            cr.set_source_rgba (0.0, 0.0, 0.0, 0.25);
            cr.set_line_width (1.0);
            cr.rectangle (0.5, 0.5, w - 1.0, h - 1.0);
            cr.stroke ();
        });
        btn.set_child (area);
        btn.set_data ("color_area", area);
        return btn;
    }

    private Gtk.Entry create_corner_entry () {
        var entry = new Gtk.Entry ();
        entry.set_max_length (3);
        entry.set_max_width_chars (3);
        entry.set_input_purpose (Gtk.InputPurpose.NUMBER);
        entry.set_hexpand (false);
        entry.set_halign (Gtk.Align.CENTER);
        entry.set_valign (Gtk.Align.CENTER);
        entry.set_alignment (0.5f);
        entry.set_text ("0");
        return entry;
    }

    private Gtk.Image create_icon_picture (string resource_path) {
        var picture = new Gtk.Image ();
        picture.icon_name = resource_path;
        picture.set_pixel_size (24);
        return picture;
    }

    private Gtk.Button create_align_icon_button (string resource_path, string tooltip) {
        var btn = new Gtk.Button ();
        btn.add_css_class ("flat");
        btn.add_css_class ("circular");
        btn.set_focus_on_click (false);
        var picture = create_icon_picture (resource_path);
        btn.set_child (picture);
        btn.set_tooltip_text (tooltip);
        return btn;
    }

    private Gtk.Entry create_opacity_entry () {
        var entry = new Gtk.Entry ();
        entry.set_max_length (3);
        entry.set_max_width_chars (3);
        entry.set_input_purpose (Gtk.InputPurpose.NUMBER);
        entry.set_hexpand (false);
        entry.set_halign (Gtk.Align.END);
        entry.set_valign (Gtk.Align.CENTER);
        entry.set_alignment (0.5f);
        entry.set_text ("100");
        return entry;
    }

    private void set_corner_entry_value (Gtk.Entry entry, double value) {
        double rounded = GLib.Math.round (value);
        double clamped = GLib.Math.fmax (0.0, GLib.Math.fmin (rounded, 999.0));
        string text = "%d".printf ((int) clamped);
        bool prev = updating;
        updating = true;
        entry.set_text (text);
        entry.set_position (text.length);
        updating = prev;
    }

    private void update_corner_lock_icon () {
        if (corner_radius_lock_toggle == null)return;
        bool locked = corner_radius_lock_toggle.get_active ();
        string resource = locked ? ICON_LOCKED : ICON_UNLOCKED;
        string tooltip = locked ? "Unlock corner radii" : "Lock corner radii";
        if (corner_radius_lock_picture != null) {
            corner_radius_lock_picture.icon_name = resource;
        }
        corner_radius_lock_toggle.set_tooltip_text (tooltip);
    }

    private void update_size_lock_icon () {
        if (size_lock_toggle == null)return;
        bool locked = size_lock_toggle.get_active ();
        string resource = locked ? ICON_LOCKED : ICON_UNLOCKED;
        string tooltip = locked ? "Unlock proportions" : "Lock proportions";
        if (size_lock_picture != null) {
            size_lock_picture.icon_name = resource;
        }
        size_lock_toggle.set_tooltip_text (tooltip);
    }

    private void update_corner_radius_visibility () {
        if (corner_radius_lock_toggle == null)return;
        bool locked = corner_radius_lock_toggle.get_active ();
        if (corner_unified_row != null) {
            corner_unified_row.set_visible (locked);
        }
        if (corner_grid != null) {
            corner_grid.set_visible (!locked);
        }
    }

    private void update_rotation_visibility () {
        if (element_angle_box == null)return;
        var element = owner.get_selected_element ();
        if (element == null)return;

        bool is_line = (element.type == ElementType.LINE);
        bool is_circle = (element.type == ElementType.CIRCLE);
        bool circle_same_dimensions = is_circle && (size_lock_toggle.get_active () || GLib.Math.fabs (element.width - element.height) < 0.01);

        element_angle_box.set_visible (!is_line && !circle_same_dimensions);
    }

    private void update_grid_preview_icon () {
        if (grid_preview_picture == null)return;
        string icon = ICON_GRID_DARK_MINI;
        grid_preview_picture.icon_name = icon;
    }

    private void update_grid_controls_sensitivity () {
        if (grid_variant_drop != null) {
            grid_variant_drop.set_sensitive (model.show_grid_overlay);
        }
    }

    private void update_color_button (Gtk.Button btn, Gdk.RGBA color) {
        btn.set_data<Gdk.RGBA?> ("current_color", color);
        var area = btn.get_data<Gtk.DrawingArea> ("color_area");
        if (area != null) {
            area.queue_draw ();
        }
    }

    private Gdk.RGBA get_color_button_color (Gtk.Button btn) {
        Gdk.RGBA? color = btn.get_data<Gdk.RGBA?> ("current_color");
        if (color != null) {
            return color;
        }
        Gdk.RGBA fallback = { 0 };
        fallback.parse ("#000000");
        return fallback;
    }

    private void show_color_picker_popover (Gtk.Widget parent, Gdk.RGBA current_color, owned ColorPickerCallback callback) {
        var popover = new Gtk.Popover ();
        popover.set_autohide (true);
        popover.set_has_arrow (false);
        popover.set_position (Gtk.PositionType.BOTTOM);

        var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
        content_box.set_margin_top (12);
        content_box.set_margin_bottom (12);
        content_box.set_margin_start (16);
        content_box.set_margin_end (16);
        popover.set_child (content_box);

        var grid = new Gtk.Grid ();
        grid.set_column_spacing (4);
        grid.set_row_spacing (4);
        content_box.append (grid);

        string[] ramp_hex = {
            "#E25480",
            "#F99E5C",
            "#FECB49",
            "#72DA82",
            "#6AC9FF",
            "#5A41FF",
            "#A57BCD",
            "#BEBEC7"
        };
        double[] steps = { -0.75, -0.5, -0.25, 0.0, 0.25, 0.50, 0.75 };
        int ramp_count = ramp_hex.length;
        int shade_count = steps.length;

        Gdk.RGBA selected_color = current_color;

        var hex_entry = new Gtk.Entry ();
        hex_entry.set_hexpand (true);
        hex_entry.set_max_length (7);
        hex_entry.set_placeholder_text ("#RRGGBB");
        hex_entry.set_text (IconiUtils.rgba_to_hex (current_color));
        hex_entry.add_css_class ("caption");

        hex_entry.changed.connect (() => {
            string text = hex_entry.get_text ().strip ();
            if (text.length == 0)return;
            if (!text.has_prefix ("#")) {
                text = "#" + text;
            }
            Gdk.RGBA test_color = { 0 };
            if (test_color.parse (text)) {
                selected_color = test_color;
                callback (selected_color);
                update_color_button (parent as Gtk.Button, selected_color);
            }
        });

        for (int row = 0; row < ramp_count; row++) {
            Gdk.RGBA base_color = IconiUtils.parse_hex_color (ramp_hex[row]);
            for (int col = 0; col < shade_count; col++) {
                Gdk.RGBA shade;
                if (steps[col] > 0.0) {
                    shade = IconiUtils.mix_with_white (base_color, steps[col]);
                } else if (steps[col] < 0.0) {
                    double amount = GLib.Math.fabs (steps[col]);
                    shade = IconiUtils.mix_with_black (base_color, amount);
                } else {
                    shade = base_color;
                }

                var swatch_btn = new Gtk.Button ();
                swatch_btn.add_css_class ("swatch_button");
                swatch_btn.set_focus_on_click (false);
                swatch_btn.set_size_request (42, 42);
                swatch_btn.set_halign (Gtk.Align.CENTER);
                swatch_btn.set_valign (Gtk.Align.CENTER);
                swatch_btn.set_tooltip_text (IconiUtils.rgba_to_hex (shade));

                var area = new Gtk.DrawingArea ();
                area.set_content_width (42);
                area.set_content_height (42);
                Gdk.RGBA copy = shade;
                area.set_draw_func ((da, cr, w, h) => {
                    cr.set_source_rgba (copy.red, copy.green, copy.blue, copy.alpha);
                    cr.rectangle (0.0, 0.0, w, h);
                    cr.fill ();
                    cr.set_source_rgba (0.0, 0.0, 0.0, 0.12);
                    cr.set_line_width (1.0);
                    cr.rectangle (0.5, 0.5, w - 1.0, h - 1.0);
                    cr.stroke ();
                });
                swatch_btn.set_child (area);
                swatch_btn.clicked.connect (() => {
                    selected_color = copy;
                    callback (selected_color);
                    update_color_button (parent as Gtk.Button, selected_color);
                    hex_entry.set_text (IconiUtils.rgba_to_hex (copy));
                });
                grid.attach (swatch_btn, col, row, 1, 1);
            }
        }

        var neutral_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
        neutral_box.set_halign (Gtk.Align.CENTER);
        neutral_box.set_margin_top (4);
        content_box.append (neutral_box);

        string[] neutral_colors = { "#000000", "#888888", "#FFFFFF" };
        string[] neutral_labels = { "Black", "Mid-Gray", "White" };

        for (int i = 0; i < neutral_colors.length; i++) {
            Gdk.RGBA neutral_color = IconiUtils.parse_hex_color (neutral_colors[i]);

            var neutral_btn = new Gtk.Button ();
            neutral_btn.add_css_class ("swatch_button");
            neutral_btn.set_focus_on_click (false);
            neutral_btn.set_size_request (42, 42);
            neutral_btn.set_tooltip_text (neutral_labels[i]);

            var area = new Gtk.DrawingArea ();
            area.set_content_width (42);
            area.set_content_height (42);
            Gdk.RGBA copy = neutral_color;
            area.set_draw_func ((da, cr, w, h) => {
                cr.set_source_rgba (copy.red, copy.green, copy.blue, copy.alpha);
                cr.rectangle (0.0, 0.0, w, h);
                cr.fill ();
                cr.set_source_rgba (0.0, 0.0, 0.0, 0.12);
                cr.set_line_width (1.0);
                cr.rectangle (0.5, 0.5, w - 1.0, h - 1.0);
                cr.stroke ();
            });
            neutral_btn.set_child (area);
            neutral_btn.clicked.connect (() => {
                selected_color = copy;
                callback (selected_color);
                update_color_button (parent as Gtk.Button, selected_color);
                hex_entry.set_text (IconiUtils.rgba_to_hex (copy));
            });
            neutral_box.append (neutral_btn);
        }

        var custom_hex_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        custom_hex_box.set_margin_top (8);
        content_box.append (custom_hex_box);

        var hex_label = new Gtk.Label ("Hex:");
        hex_label.set_xalign (0.0f);
        hex_label.add_css_class ("caption");
        custom_hex_box.append (hex_label);
        custom_hex_box.append (hex_entry);

        var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        button_box.set_halign (Gtk.Align.END);
        button_box.set_margin_top (6);
        content_box.append (button_box);

        var cancel_btn = new Gtk.Button.with_label ("Close");
        cancel_btn.clicked.connect (() => {
            popover.popdown ();
        });
        button_box.append (cancel_btn);

        var triggering_widget = parent;
        if (triggering_widget != null) {
            popover.set_parent (triggering_widget);
        } else if (owner != null) {
            popover.set_parent (owner);
        }
        popover.popup ();
    }

    private void update_position_entries (IconElement element) {
        bool prev = updating;
        updating = true;
        x_entry.set_value ((double) element.x);
        y_entry.set_value ((double) element.y);
        updating = prev;
    }

    private void update_corner_radius_controls (IconElement element) {
        if (corner_radius_tl_entry == null)return;
        set_corner_entry_value (corner_radius_tl_entry, element.corner_radius_top_left);
        set_corner_entry_value (corner_radius_tr_entry, element.corner_radius_top_right);
        set_corner_entry_value (corner_radius_br_entry, element.corner_radius_bottom_right);
        set_corner_entry_value (corner_radius_bl_entry, element.corner_radius_bottom_left);
        if (corner_radius_unified_entry != null) {
            set_corner_entry_value (corner_radius_unified_entry, element.corner_radius_top_left);
        }
        bool prev = updating;
        updating = true;
        corner_radius_lock_toggle.set_active (element.corner_radius_locked);
        updating = prev;
        update_corner_lock_icon ();
        update_corner_radius_visibility ();
    }

    private void handle_corner_radius_entry (CornerHandle handle, Gtk.Entry entry) {
        if (updating)return;
        var element = owner.get_selected_element ();
        if (element == null)return;
        if (element.type != ElementType.RECTANGLE)return;
        string raw = entry.get_text ();
        string sanitized = IconiUtils.sanitize_numeric_text (raw, 3u);
        if (sanitized != raw) {
            entry.set_text (sanitized.length > 0 ? sanitized : "0");
            entry.set_position (entry.get_text ().length);
            return;
        }
        if (sanitized.length == 0) {
            entry.set_text ("0");
            entry.set_position (1);
            return;
        }
        int value = int.parse (sanitized);
        if (value > 999) {
            entry.set_text ("999");
            entry.set_position (3);
            return;
        }
        float radius = (float) value;
        if (element.corner_radius_locked) {
            element.corner_radius_top_left = radius;
            element.corner_radius_top_right = radius;
            element.corner_radius_bottom_right = radius;
            element.corner_radius_bottom_left = radius;
        } else {
            switch (handle) {
            case CornerHandle.TOP_LEFT :
                element.corner_radius_top_left = radius;
                break;
            case CornerHandle.TOP_RIGHT :
                element.corner_radius_top_right = radius;
                break;
            case CornerHandle.BOTTOM_RIGHT :
                element.corner_radius_bottom_right = radius;
                break;
            case CornerHandle.BOTTOM_LEFT:
                element.corner_radius_bottom_left = radius;
                break;
            }
        }
        apply_corner_radius_constraints (element);
        redraw ();
    }

    private void apply_corner_radius_constraints (IconElement element) {
        if (element.type != ElementType.RECTANGLE)return;
        if (element.corner_radius_locked) {
            double uniform = element.corner_radius_top_left;
            uniform = GLib.Math.fmax (0.0, GLib.Math.fmin (uniform, 999.0));
            float uniformf = (float) uniform;
            element.corner_radius_top_left = uniformf;
            element.corner_radius_top_right = uniformf;
            element.corner_radius_bottom_right = uniformf;
            element.corner_radius_bottom_left = uniformf;
        }

        double width = element.width;
        double height = element.height;
        double tl = element.corner_radius_top_left;
        double tr = element.corner_radius_top_right;
        double br = element.corner_radius_bottom_right;
        double bl = element.corner_radius_bottom_left;

        IconiUtils.normalize_corner_radii (ref tl, ref tr, ref br, ref bl, width, height);

        tl = GLib.Math.fmax (0.0, GLib.Math.fmin (GLib.Math.floor (tl), 999.0));
        tr = GLib.Math.fmax (0.0, GLib.Math.fmin (GLib.Math.floor (tr), 999.0));
        br = GLib.Math.fmax (0.0, GLib.Math.fmin (GLib.Math.floor (br), 999.0));
        bl = GLib.Math.fmax (0.0, GLib.Math.fmin (GLib.Math.floor (bl), 999.0));

        element.corner_radius_top_left = (float) tl;
        element.corner_radius_top_right = (float) tr;
        element.corner_radius_bottom_right = (float) br;
        element.corner_radius_bottom_left = (float) bl;

        update_corner_radius_controls (element);
    }

    private void align_selected_element_horizontal (int mode) {
        var element = owner.get_selected_element ();
        if (element == null)return;
        double canvas_size = 109.0;
        if (element.type == ElementType.LINE) {
            double x1 = element.x;
            double x2 = element.x + element.width;
            double min_x = GLib.Math.fmin (x1, x2);
            double max_x = GLib.Math.fmax (x1, x2);
            double span = max_x - min_x;
            double target = 0.0;
            double max_target = GLib.Math.fmax (canvas_size - span, 0.0);
            switch (mode) {
            case 0: target = 0.0; break;
            case 1: target = (canvas_size - span) / 2.0; break;
            case 2: target = canvas_size - span; break;
            default: target = 0.0; break;
            }
            target = GLib.Math.fmax (0.0, GLib.Math.fmin (target, max_target));
            double delta = target - min_x;
            element.x = (float) (element.x + delta);
        } else {
            double width = element.width;
            double target = 0.0;
            double max_target = GLib.Math.fmax (canvas_size - width, 0.0);
            switch (mode) {
            case 0: target = 0.0; break;
            case 1: target = (canvas_size - width) / 2.0; break;
            case 2: target = canvas_size - width; break;
            default: target = 0.0; break;
            }
            target = GLib.Math.fmax (0.0, GLib.Math.fmin (target, max_target));
            element.x = IconiUtils.clampf ((float) target, 0.0f, (float) canvas_size);
        }
        update_position_entries (element);
        redraw ();
    }

    private void align_selected_element_vertical (int mode) {
        var element = owner.get_selected_element ();
        if (element == null)return;
        double canvas_size = 109.0;
        if (element.type == ElementType.LINE) {
            double y1 = element.y;
            double y2 = element.y + element.height;
            double min_y = GLib.Math.fmin (y1, y2);
            double max_y = GLib.Math.fmax (y1, y2);
            double span = max_y - min_y;
            double target = 0.0;
            double max_target = GLib.Math.fmax (canvas_size - span, 0.0);
            switch (mode) {
            case 0: target = 0.0; break;
            case 1: target = (canvas_size - span) / 2.0; break;
            case 2: target = canvas_size - span; break;
            default: target = 0.0; break;
            }
            target = GLib.Math.fmax (0.0, GLib.Math.fmin (target, max_target));
            double delta = target - min_y;
            element.y = (float) (element.y + delta);
        } else {
            double height = element.height;
            double target = 0.0;
            double max_target = GLib.Math.fmax (canvas_size - height, 0.0);
            switch (mode) {
            case 0: target = 0.0; break;
            case 1: target = (canvas_size - height) / 2.0; break;
            case 2: target = canvas_size - height; break;
            default: target = 0.0; break;
            }
            target = GLib.Math.fmax (0.0, GLib.Math.fmin (target, max_target));
            element.y = IconiUtils.clampf ((float) target, 0.0f, (float) canvas_size);
        }
        update_position_entries (element);
        redraw ();
    }

    private void apply_svg_fill_to_element (IconElement element) {
        if (element.type != ElementType.SVG)return;
        element.svg_data = IconiUtils.set_svg_paint (element.svg_data, "fill", element.fill);
    }

    private void apply_svg_stroke_to_element (IconElement element) {
        if (element.type != ElementType.SVG)return;
        element.svg_data = IconiUtils.set_svg_paint (element.svg_data, "stroke", element.stroke);
        element.svg_data = IconiUtils.set_svg_numeric (element.svg_data, "stroke-width", element.stroke_width);
    }

    private void apply_svg_stroke_width_to_element (IconElement element) {
        if (element.type != ElementType.SVG)return;
        element.svg_data = IconiUtils.set_svg_numeric (element.svg_data, "stroke-width", element.stroke_width);
    }
}
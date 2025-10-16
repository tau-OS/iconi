public class IconMakerWindow : He.ApplicationWindow {
	private IconModel model;
	private IconRenderer renderer;

	// UI fields
	private Gtk.ListBox listbox;
	private Gtk.DrawingArea canvas;

	private Gtk.Box props_area;
	private Gtk.Box bg_props_area;
	private Gtk.Box center_box;

	private Gtk.SpinButton x_entry;
	private Gtk.SpinButton y_entry;
	private Gtk.SpinButton w_entry;
	private Gtk.SpinButton h_entry;
	private Gtk.Box size_box;

	private Gtk.ColorDialogButton fill_btn;
	private Gtk.ColorDialogButton stroke_btn;
	private Gtk.SpinButton fill_opacity_spin;
	private Gtk.SpinButton stroke_opacity_spin;
	private Gtk.SpinButton stroke_width_spin;
	private Gtk.Label fill_label;
	private Gtk.Box fill_opacity_box;
	private Gtk.Label stroke_label;
	private Gtk.Box stroke_color_box;
	private Gtk.Box stroke_opacity_box;
	private Gtk.Box stroke_width_box;
	private Gtk.DropDown fill_mode_drop;
	private Gtk.Label fill_mode_label;
	private Gtk.Box fill_gradient_box;
	private Gtk.Box fill_gradient_angle_box;
	private Gtk.ColorDialogButton fill_gradient_btn;
	private Gtk.SpinButton fill_gradient_angle_spin;
	private Gtk.Label fill_gradient_angle_label;
	private Gtk.Box line_controls_box;
	private Gtk.SpinButton line_length_spin;
	private Gtk.SpinButton line_angle_spin;

	private Gtk.Box blend_drop_box;
	private Gtk.DropDown blend_drop;
	private string[] blends = { "normal", "multiply", "screen", "overlay", "darken", "lighten", "color-dodge", "color-burn", "hard-light", "soft-light", "difference", "exclusion", "hue", "saturation", "color", "luminosity" };
	private string[] bg_fill_modes = { "Solid", "Gradient" };

	private Gtk.ColorDialogButton bg_side_color_btn;
	private Gtk.Switch bg_side_wall_switch;
	private Gtk.DropDown bg_fill_mode_drop;
	private Gtk.ColorDialogButton bg_gradient_end_btn;
	private Gtk.SpinButton bg_gradient_angle_spin;
	private Gtk.Box bg_gradient_container;

	private Gtk.Scale zoom_scale;
	private Gtk.Label zoom_label;
	private Gtk.Switch bg_effects_switch;
	private Gtk.Switch bg_frame_switch;
	private Gtk.Switch bg_dev_switch;
	private Gtk.ToggleButton view_wall_toggle;
	private Gtk.Button view_color_button;
	private Gtk.DrawingArea view_color_preview;
	private Gtk.Popover view_color_popover;

	private bool updating_properties = false;
	private Gtk.CssProvider? view_bg_css;
	private static GLib.Settings? wallpaper_settings;
	private string wallpaper_uri_cache = "";

	private const int SVG_VIEWPORT_SIZE = 128;

	static construct {
		wallpaper_settings = new GLib.Settings ("org.gnome.desktop.background");
	}

	public IconMakerWindow (IconMakerApplication app) {
		Object (application : app);
		set_title ("Icon Maker");
		set_default_size (1240, 800);
		model = new IconModel ();
		renderer = new IconRenderer (model);
		setup_wallpaper_settings ();
		setup_ui ();
	}

	private void setup_ui () {
		var main_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);
		set_child (main_box);

		// Global key controller on main_box
		var key_controller = new Gtk.EventControllerKey ();
		main_box.add_controller (key_controller);
		key_controller.key_pressed.connect ((controller, keyval, keycode, state) => {
			if (keyval == Gdk.Key.Delete || keyval == Gdk.Key.BackSpace) {
				if (!model.background_selected && model.selected_index >= 0) {
					remove_element_at (model.selected_index);
				}
				return true;
			}
			return false;
		});

		// LEFT SIDEBAR
		var left_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		left_box.set_size_request (260, -1);
		left_box.set_vexpand (true);
		left_box.set_hexpand_set (true);
		main_box.append (left_box);

		var appbar = new He.AppBar ();
		appbar.show_left_title_buttons = true;
		appbar.show_right_title_buttons = false;
		left_box.append (appbar);

		var left_header = new Gtk.Label (null);
		left_header.add_css_class ("view-title");
		left_header.set_markup ("Elements");
		left_header.set_halign (Gtk.Align.START);
		left_header.set_hexpand (true);

		var reorder_toggle = new Gtk.ToggleButton ();
		reorder_toggle.icon_name = "document-edit-symbolic";

		var add_menu_btn = new Gtk.MenuButton ();
		add_menu_btn.set_tooltip_text ("Add element");
		var add_pop = new Gtk.Popover ();
		var add_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		var add_rect_btn = new Gtk.Button.with_label ("Rectangle");
		var add_circle_btn = new Gtk.Button.with_label ("Circle");
		var add_line_btn = new Gtk.Button.with_label ("Line");
		add_box.append (add_rect_btn);
		add_box.append (add_circle_btn);
		add_box.append (add_line_btn);
		add_pop.set_child (add_box);
		add_menu_btn.set_popover (add_pop);
		add_menu_btn.set_child (new Gtk.Image.from_icon_name ("list-add-symbolic"));

		appbar.viewtitle_widget = left_header;
		appbar.append_toggle (reorder_toggle);
		appbar.append_menu (add_menu_btn);

		listbox = new Gtk.ListBox ();
		listbox.margin_start = 18;
		listbox.margin_end = 18;
		listbox.set_vexpand (true);
		listbox.add_css_class ("content-list");
		left_box.append (listbox);

		// CENTER
		center_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		center_box.set_hexpand (true);
		center_box.set_vexpand (true);
		center_box.set_name ("center-bg");
		main_box.append (center_box);

		var mappbar = new He.AppBar ();
		mappbar.show_left_title_buttons = false;
		mappbar.show_right_title_buttons = false;
		center_box.append (mappbar);

		// Name label <-> entry via stack
		var name_label = new Gtk.Label (model.name);
		name_label.add_css_class ("view-title");
		name_label.set_halign (Gtk.Align.START);
		name_label.set_valign (Gtk.Align.CENTER);

		var name_entry = new Gtk.Entry ();
		name_entry.set_text (model.name);
		name_entry.set_halign (Gtk.Align.START);
		name_entry.set_size_request (300, -1);

		var name_stack = new Gtk.Stack ();
		name_stack.add_named (name_label, "label");
		name_stack.add_named (name_entry, "entry");
		name_stack.set_visible_child_name ("label");

		var name_click = new Gtk.GestureClick ();
		name_label.add_controller (name_click);
		name_click.released.connect ((g, n_press, x, y) => {
			name_stack.set_visible_child_name ("entry");
			name_entry.grab_focus ();
			name_entry.select_region (0, -1);
		});
		var focus_ctl = new Gtk.EventControllerFocus ();
		name_entry.add_controller (focus_ctl);
		focus_ctl.leave.connect (() => { commit_name (name_entry, name_label, name_stack); });
		name_entry.activate.connect (() => { commit_name (name_entry, name_label, name_stack); });

		mappbar.viewtitle_widget = name_stack;

		view_wall_toggle = new Gtk.ToggleButton ();
		view_wall_toggle.set_valign (Gtk.Align.CENTER);
		view_wall_toggle.set_tooltip_text ("Show system wallpaper behind preview");
		var wall_toggle_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 4);
		wall_toggle_box.set_margin_start (10);
		wall_toggle_box.set_margin_end (10);
		wall_toggle_box.set_valign (Gtk.Align.CENTER);
		wall_toggle_box.append (new Gtk.Image.from_icon_name ("preferences-desktop-wallpaper-symbolic"));
		view_wall_toggle.set_child (wall_toggle_box);

		view_color_button = new Gtk.Button ();
		view_color_button.set_valign (Gtk.Align.CENTER);
		view_color_button.set_tooltip_text ("Choose preview background color");
		var color_toggle_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		color_toggle_box.set_margin_start (12);
		color_toggle_box.set_margin_end (10);
		color_toggle_box.set_valign (Gtk.Align.CENTER);
		view_color_preview = new Gtk.DrawingArea ();
		view_color_preview.set_content_width (32);
		view_color_preview.set_content_height (18);
		view_color_preview.set_valign (Gtk.Align.CENTER);
		view_color_preview.set_draw_func ((area, cr, width, height) => {
			double w = width;
			double h = height;
			if (w <= 0.0 || h <= 0.0)return;
			var color = model.view_background;
			cr.set_source_rgba (color.red, color.green, color.blue, color.alpha);
			cr.rectangle (0.0, 0.0, w, h);
			cr.fill ();
			cr.set_source_rgba (0.0, 0.0, 0.0, 0.35);
			cr.set_line_width (1.0);
			cr.rectangle (0.5, 0.5, w - 1.0, h - 1.0);
			cr.stroke ();
		});
		color_toggle_box.append (view_color_preview);
		view_color_button.set_child (color_toggle_box);

		mappbar.append_toggle (view_wall_toggle);
		mappbar.append (view_color_button);

		view_color_popover = create_view_color_popover ();
		view_color_popover.set_parent (view_color_button);

		view_wall_toggle.toggled.connect (() => {
			if (updating_properties)return;
			bool state = view_wall_toggle.get_active ();
			apply_wallpaper_state (state);
		});

		view_color_button.clicked.connect (() => {
			if (updating_properties)return;
			apply_wallpaper_state (false);
			toggle_view_color_popover ();
		});

		bool toggle_prev = updating_properties;
		updating_properties = true;
		view_wall_toggle.set_active (model.use_wallpaper);
		updating_properties = toggle_prev;
		update_view_color_preview ();

		// Zoom
		zoom_scale = new Gtk.Scale.with_range (Gtk.Orientation.HORIZONTAL, 0.25, 3.0, 0.25);
		zoom_scale.set_value (model.zoom);
		zoom_scale.set_valign (Gtk.Align.CENTER);
		zoom_scale.set_vexpand (true);
		zoom_scale.set_margin_top (18);
		zoom_scale.set_margin_bottom (6);
		zoom_scale.set_margin_start (12);
		zoom_scale.set_margin_end (12);
		zoom_label = new Gtk.Label ("---%");
		zoom_label.set_halign (Gtk.Align.START);
		zoom_label.set_label (Math.floor (zoom_scale.get_value () * 100).to_string () + "%");
		zoom_label.set_margin_start (18);
		zoom_label.set_margin_top (18);
		zoom_label.set_margin_end (18);
		zoom_label.set_margin_bottom (18);
		var zoom_btn = new Gtk.MenuButton ();
		var zoom_pop = new Gtk.Popover ();
		var pop_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		pop_box.set_size_request (300, -1);
		pop_box.append (zoom_scale);
		pop_box.append (zoom_label);
		zoom_pop.set_child (pop_box);
		zoom_btn.set_popover (zoom_pop);
		zoom_btn.set_child (new Gtk.Image.from_icon_name ("zoom-fit-best-symbolic"));
		mappbar.append_menu (zoom_btn);

		// Canvas
		canvas = new Gtk.DrawingArea ();
		canvas.set_content_width (SVG_VIEWPORT_SIZE);
		canvas.set_content_height (SVG_VIEWPORT_SIZE);
		canvas.set_hexpand (true);
		canvas.set_vexpand (true);
		canvas.set_halign (Gtk.Align.CENTER);
		canvas.set_valign (Gtk.Align.CENTER);
		canvas.set_size_request ((int) (SVG_VIEWPORT_SIZE * model.zoom), (int) (SVG_VIEWPORT_SIZE * model.zoom));
		canvas.set_margin_top (6);
		center_box.append (canvas);
		canvas.set_draw_func ((area, cr, width, height) => {
			cr.set_source_rgba (0, 0, 0, 0);
			cr.paint ();
			float z = IconiUtils.clampf (model.zoom, 0.25f, 4.0f);
			cr.save ();
			cr.scale (z, z);
			renderer.render_icon (cr, SVG_VIEWPORT_SIZE);
			cr.restore ();
		});

		// RIGHT SIDEBAR
		var right_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		right_box.set_size_request (300, -1);
		right_box.set_vexpand (true);
		right_box.set_hexpand_set (true);
		main_box.append (right_box);

		var rappbar = new He.AppBar ();
		rappbar.show_left_title_buttons = false;
		rappbar.show_right_title_buttons = true;
		right_box.append (rappbar);

		var prop_header = new Gtk.Label ("Properties");
		prop_header.add_css_class ("view-title");
		prop_header.set_halign (Gtk.Align.START);
		rappbar.viewtitle_widget = prop_header;

		// Export
		var export_btn = new Gtk.Button ();
		export_btn.set_icon_name ("document-export-symbolic");
		rappbar.append (export_btn);

		props_area = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		props_area.margin_start = 18;
		props_area.margin_bottom = 18;
		props_area.margin_end = 18;
		right_box.append (props_area);

		bg_props_area = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		bg_props_area.margin_start = 18;
		bg_props_area.margin_bottom = 18;
		bg_props_area.margin_end = 18;
		right_box.append (bg_props_area);

		// Background properties (right)
		var canvas_bg_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		canvas_bg_row.add_css_class ("mini-content-block");
		var bg_side_dialog = new Gtk.ColorDialog ();
		bg_side_dialog.set_with_alpha (true);
		bg_side_color_btn = new Gtk.ColorDialogButton (bg_side_dialog);
		bg_side_color_btn.set_rgba (model.background);
		bg_side_wall_switch = new Gtk.Switch ();
		bg_side_wall_switch.set_active (model.use_wallpaper);
		canvas_bg_row.append (new Gtk.Label ("Background Color") { xalign = 0.0f, hexpand = true });
		canvas_bg_row.append (bg_side_color_btn);
		bg_props_area.append (canvas_bg_row);
		var fill_mode_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		fill_mode_row.add_css_class ("mini-content-block");
		fill_mode_label = new Gtk.Label ("Fill Type");
		fill_mode_label.set_xalign (0.0f);
		fill_mode_label.set_hexpand (true);
		fill_mode_row.append (fill_mode_label);
		bg_fill_mode_drop = new Gtk.DropDown.from_strings (bg_fill_modes);
		bg_fill_mode_drop.set_selected (model.use_gradient ? 1u : 0u);
		fill_mode_row.append (bg_fill_mode_drop);
		bg_props_area.append (fill_mode_row);
		bg_gradient_container = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		bg_gradient_container.add_css_class ("mini-content-block");
		var gradient_color_label = new Gtk.Label ("Gradient End Color");
		gradient_color_label.set_xalign (0.0f);
		gradient_color_label.set_hexpand (true);
		var gradient_dialog = new Gtk.ColorDialog ();
		gradient_dialog.set_with_alpha (true);
		bg_gradient_end_btn = new Gtk.ColorDialogButton (gradient_dialog);
		bg_gradient_end_btn.set_halign (Gtk.Align.END);
		bg_gradient_end_btn.set_rgba (model.gradient_secondary);
		var gradient_color_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		gradient_color_row.append (gradient_color_label);
		gradient_color_row.append (bg_gradient_end_btn);
		bg_gradient_container.append (gradient_color_row);
		var gradient_angle_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		var gradient_angle_label = new Gtk.Label ("Gradient Angle");
		gradient_angle_label.set_xalign (0.0f);
		gradient_angle_label.set_hexpand (true);
		gradient_angle_row.append (gradient_angle_label);
		bg_gradient_angle_spin = new Gtk.SpinButton.with_range (0, 360, 1);
		bg_gradient_angle_spin.set_value (model.gradient_angle);
		gradient_angle_row.append (bg_gradient_angle_spin);
		bg_gradient_container.append (gradient_angle_row);
		bg_props_area.append (bg_gradient_container);
		var effects_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		effects_row.add_css_class ("mini-content-block");
		var effects_label = new Gtk.Label ("Raised Effect");
		effects_label.set_xalign (0.0f);
		effects_label.set_hexpand (true);
		effects_row.append (effects_label);
		bg_effects_switch = new Gtk.Switch ();
		bg_effects_switch.set_active (model.use_raised_effect);
		effects_row.append (bg_effects_switch);
		bg_props_area.append (effects_row);
		var frame_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		frame_row.add_css_class ("mini-content-block");
		var frame_label = new Gtk.Label ("Toolbox App Frame");
		frame_label.set_xalign (0.0f);
		frame_label.set_hexpand (true);
		frame_row.append (frame_label);
		bg_frame_switch = new Gtk.Switch ();
		bg_frame_switch.set_active (model.use_frame_overlay);
		frame_row.append (bg_frame_switch);
		bg_props_area.append (frame_row);
		var dev_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		dev_row.add_css_class ("mini-content-block");
		var dev_label = new Gtk.Label ("Developer Badge");
		dev_label.set_xalign (0.0f);
		dev_label.set_hexpand (true);
		dev_row.append (dev_label);
		bg_dev_switch = new Gtk.Switch ();
		bg_dev_switch.set_active (model.show_dev_badge);
		dev_row.append (bg_dev_switch);
		bg_props_area.append (dev_row);

		// Element properties
		var pos_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		pos_box.add_css_class ("mini-content-block");
		x_entry = new Gtk.SpinButton.with_range (0, 109, 1);
		y_entry = new Gtk.SpinButton.with_range (0, 109, 1);
		var x_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		x_box.append (new Gtk.Label ("X") { xalign = 0.0f, hexpand = true });
		x_box.append (x_entry);
		pos_box.append (x_box);
		var y_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		y_box.append (new Gtk.Label ("Y") { xalign = 0.0f, hexpand = true });
		y_box.append (y_entry);
		pos_box.append (y_box);
		props_area.append (pos_box);

		size_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		size_box.add_css_class ("mini-content-block");
		w_entry = new Gtk.SpinButton.with_range (1, 109, 1);
		h_entry = new Gtk.SpinButton.with_range (1, 109, 1);
		var width_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		width_box.append (new Gtk.Label ("Width") { xalign = 0.0f, hexpand = true });
		width_box.append (w_entry);
		size_box.append (width_box);
		var height_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		height_box.append (new Gtk.Label ("Height") { xalign = 0.0f, hexpand = true });
		height_box.append (h_entry);
		size_box.append (height_box);
		props_area.append (size_box);

		line_controls_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		line_controls_box.add_css_class ("mini-content-block");
		line_length_spin = new Gtk.SpinButton.with_range (1, 156, 1);
		line_angle_spin = new Gtk.SpinButton.with_range (0, 360, 1);
		line_controls_box.append (new Gtk.Label ("Length") { xalign = 0.0f, hexpand = true });
		line_controls_box.append (line_length_spin);
		line_controls_box.append (new Gtk.Label ("Angle") { xalign = 0.0f, hexpand = true });
		line_controls_box.append (line_angle_spin);
		line_controls_box.set_visible (false);
		props_area.append (line_controls_box);

		// Fill (hidden for Line)
		var fill_color_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		fill_color_box.add_css_class ("mini-content-block");
		fill_label = new Gtk.Label ("Fill Color");
		fill_label.set_xalign (0.0f);
		fill_label.set_hexpand (true);
		var fill_dialog = new Gtk.ColorDialog ();
		fill_dialog.set_with_alpha (false);
		fill_btn = new Gtk.ColorDialogButton (fill_dialog);
		fill_color_box.append (fill_label);
		fill_color_box.append (fill_btn);
		props_area.append (fill_color_box);

		// Fill mode
		var fill_color_mode_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		fill_color_mode_row.add_css_class ("mini-content-block");
		fill_mode_label = new Gtk.Label ("Fill Color Mode");
		fill_mode_label.set_xalign (0.0f);
		fill_mode_label.set_hexpand (true);
		fill_mode_drop = new Gtk.DropDown.from_strings (new string[] { "Solid", "Gradient" });
		fill_color_mode_row.append (fill_mode_label);
		fill_color_mode_row.append (fill_mode_drop);
		props_area.append (fill_color_mode_row);

		fill_gradient_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		fill_gradient_box.add_css_class ("mini-content-block");
		fill_gradient_box.set_visible (false);
		var fill_gradient_color_label = new Gtk.Label ("Gradient End Color");
		fill_gradient_color_label.set_xalign (0.0f);
		fill_gradient_color_label.set_hexpand (true);
		var fill_gradient_dialog = new Gtk.ColorDialog ();
		fill_gradient_dialog.set_with_alpha (false);
		fill_gradient_btn = new Gtk.ColorDialogButton (fill_gradient_dialog);
		fill_gradient_angle_label = new Gtk.Label ("Gradient Angle");
		fill_gradient_angle_label.set_xalign (0.0f);
		fill_gradient_angle_label.set_hexpand (true);
		fill_gradient_angle_spin = new Gtk.SpinButton.with_range (0, 360, 1);
		fill_gradient_angle_spin.set_value (0.0);
		fill_gradient_box.append (fill_gradient_color_label);
		fill_gradient_box.append (fill_gradient_btn);
		fill_gradient_angle_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		fill_gradient_angle_box.add_css_class ("mini-content-block");
		fill_gradient_angle_box.set_visible (false);
		fill_gradient_angle_box.append (fill_gradient_angle_label);
		fill_gradient_angle_box.append (fill_gradient_angle_spin);
		props_area.append (fill_gradient_box);
		props_area.append (fill_gradient_angle_box);

		fill_opacity_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		fill_opacity_box.add_css_class ("mini-content-block");
		fill_opacity_spin = new Gtk.SpinButton.with_range (0, 100, 1);
		fill_opacity_box.append (new Gtk.Label ("Fill Opacity (%)") { xalign = 0.0f, hexpand = true });
		fill_opacity_box.append (fill_opacity_spin);
		props_area.append (fill_opacity_box);

		// Stroke
		stroke_color_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		stroke_color_box.add_css_class ("mini-content-block");
		stroke_label = new Gtk.Label ("Stroke");
		stroke_label.set_xalign (0.0f);
		stroke_label.set_hexpand (true);
		var stroke_dialog = new Gtk.ColorDialog ();
		stroke_dialog.set_with_alpha (false);
		stroke_btn = new Gtk.ColorDialogButton (stroke_dialog);
		stroke_color_box.append (stroke_label);
		stroke_color_box.append (stroke_btn);
		props_area.append (stroke_color_box);

		stroke_opacity_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		stroke_opacity_box.add_css_class ("mini-content-block");
		stroke_opacity_spin = new Gtk.SpinButton.with_range (0, 100, 1);
		stroke_opacity_box.append (new Gtk.Label ("Stroke Opacity (%)") { xalign = 0.0f, hexpand = true });
		stroke_opacity_box.append (stroke_opacity_spin);
		props_area.append (stroke_opacity_box);

		stroke_width_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		stroke_width_box.add_css_class ("mini-content-block");
		stroke_width_spin = new Gtk.SpinButton.with_range (0, 20, 0.5);
		stroke_width_spin.set_digits (1);
		stroke_width_box.append (new Gtk.Label ("Stroke Width") { xalign = 0.0f, hexpand = true });
		stroke_width_box.append (stroke_width_spin);
		props_area.append (stroke_width_box);

		blend_drop_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		blend_drop_box.add_css_class ("mini-content-block");
		blend_drop_box.append (new Gtk.Label ("Blend Mode") { xalign = 0.0f, hexpand = true });
		blend_drop = new Gtk.DropDown.from_strings (blends);
		blend_drop_box.append (blend_drop);
		props_area.append (blend_drop_box);

		// Signals

		listbox.row_selected.connect ((lb, row) => {
			if (row == null) {
				model.background_selected = false;
				model.selected_index = -1;
			} else {
				int ridx = row.get_index ();
				if (ridx == 0) {
					model.background_selected = true;
					model.selected_index = -1;
				} else {
					model.background_selected = false;
					model.selected_index = ridx - 1;
				}
			}
			update_properties_visibility ();
			canvas.queue_draw ();
		});

		add_rect_btn.clicked.connect (() => {
			model.elements.append (new IconElement (ElementType.RECTANGLE));
			refresh_listbox ();
			canvas.queue_draw ();
		});
		add_circle_btn.clicked.connect (() => {
			model.elements.append (new IconElement (ElementType.CIRCLE));
			refresh_listbox ();
			canvas.queue_draw ();
		});
		add_line_btn.clicked.connect (() => {
			var e = new IconElement (ElementType.LINE);
			e.line_length = 56.0f;
			e.line_angle = 0.0;
			e.gradient_secondary = e.stroke;
			refresh_line_deltas (e);
			model.elements.append (e);
			refresh_listbox ();
			canvas.queue_draw ();
		});

		reorder_toggle.toggled.connect (() => {
			model.reorder_mode = reorder_toggle.get_active ();
			refresh_listbox ();
		});

		// Canvas selection hit test
		var clickc = new Gtk.GestureClick ();
		canvas.add_controller (clickc);
		clickc.released.connect ((g, n_press, px, py) => {
			float z = IconiUtils.clampf (model.zoom, 0.25f, 4.0f);
			float x = (float) (px / z);
			float y = (float) (py / z);
			float preview = 109.0f;
			float ox = (128.0f - preview) / 2.0f;
			float oy = (128.0f - preview) / 2.0f;
			float relx = x - ox;
			float rely = y - oy;

			model.selected_index = -1;
			model.background_selected = false;
			int n = (int) model.elements.get_n_items ();
			for (int i = n - 1; i >= 0; i--) {
				var el = (IconElement) model.elements.get_item ((uint) i);
				if (relx >= el.x && relx <= el.x + el.width && rely >= el.y && rely <= el.y + el.height) {
					model.selected_index = i;
					break;
				}
			}
			if (model.selected_index >= 0) {
				var row2 = listbox.get_row_at_index (model.selected_index + 1);
				if (row2 != null)listbox.select_row (row2);
			} else {
				listbox.unselect_all ();
			}
			update_properties_visibility ();
			canvas.queue_draw ();
		});

		// Element property handlers
		x_entry.value_changed.connect (() => {
			if (updating_properties)return;
			if (model.selected_index < 0)return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			el.x = (float) GLib.Math.fmin (GLib.Math.fmax ((float) x_entry.get_value (), 0.0f), 109.0f);
			canvas.queue_draw ();
		});
		y_entry.value_changed.connect (() => {
			if (updating_properties)return;
			if (model.selected_index < 0)return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			el.y = (float) GLib.Math.fmin (GLib.Math.fmax ((float) y_entry.get_value (), 0.0f), 109.0f);
			canvas.queue_draw ();
		});
		w_entry.value_changed.connect (() => {
			if (updating_properties)return;
			if (model.selected_index < 0)return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			if (el.type == ElementType.LINE)return;
			el.width = (float) GLib.Math.fmin (GLib.Math.fmax ((float) w_entry.get_value (), 1.0f), 109.0f);
			canvas.queue_draw ();
		});
		h_entry.value_changed.connect (() => {
			if (updating_properties)return;
			if (model.selected_index < 0)return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			if (el.type == ElementType.LINE)return;
			el.height = (float) GLib.Math.fmin (GLib.Math.fmax ((float) h_entry.get_value (), 1.0f), 109.0f);
			canvas.queue_draw ();
		});
		stroke_width_spin.value_changed.connect (() => {
			if (updating_properties)return;
			if (model.selected_index < 0)return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			el.stroke_width = (float) stroke_width_spin.get_value ();
			canvas.queue_draw ();
		});

		line_length_spin.value_changed.connect (() => {
			if (updating_properties)return;
			if (model.selected_index < 0)return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			if (el.type != ElementType.LINE)return;
			float value = (float) GLib.Math.fmax (line_length_spin.get_value (), 1.0);
			el.line_length = value;
			refresh_line_deltas (el);
			canvas.queue_draw ();
		});

		line_angle_spin.value_changed.connect (() => {
			if (updating_properties)return;
			if (model.selected_index < 0)return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			if (el.type != ElementType.LINE)return;
			el.line_angle = line_angle_spin.get_value ();
			refresh_line_deltas (el);
			canvas.queue_draw ();
		});

		fill_btn.notify.connect ((pspec) => {
			if (updating_properties)return;
			if (pspec.name != "rgba")return;
			if (model.selected_index < 0)return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			if (el.type == ElementType.LINE)return;
			var rgba = fill_btn.get_rgba ();
			float a = (float) (fill_opacity_spin.get_value () / 100.0);
			a = IconiUtils.clampf (a, 0.0f, 1.0f);
			rgba.alpha = a;
			el.fill = rgba;
			var grad = el.gradient_secondary;
			grad.alpha = rgba.alpha;
			el.gradient_secondary = grad;
			canvas.queue_draw ();
		});
		stroke_btn.notify.connect ((pspec) => {
			if (updating_properties)return;
			if (pspec.name != "rgba")return;
			if (model.selected_index < 0)return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			var rgba = stroke_btn.get_rgba ();
			float a = (float) (stroke_opacity_spin.get_value () / 100.0);
			a = IconiUtils.clampf (a, 0.0f, 1.0f);
			rgba.alpha = a;
			el.stroke = rgba;
			if (el.type == ElementType.LINE) {
				var grad = el.gradient_secondary;
				grad.alpha = rgba.alpha;
				el.gradient_secondary = grad;
			}
			canvas.queue_draw ();
		});

		fill_mode_drop.notify.connect ((pspec) => {
			if (updating_properties)return;
			if (pspec.name != "selected")return;
			if (model.selected_index < 0)return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			el.use_gradient = (fill_mode_drop.get_selected () == 1u);
			fill_gradient_box.set_visible (el.use_gradient);
			fill_gradient_angle_box.set_visible (el.use_gradient);
			canvas.queue_draw ();
		});

		fill_gradient_btn.notify.connect ((pspec) => {
			if (updating_properties)return;
			if (pspec.name != "rgba")return;
			if (model.selected_index < 0)return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			var rgba = fill_gradient_btn.get_rgba ();
			if (el.type == ElementType.LINE) {
				rgba.alpha = el.stroke.alpha;
			} else {
				rgba.alpha = el.fill.alpha;
			}
			el.gradient_secondary = rgba;
			canvas.queue_draw ();
		});

		fill_gradient_angle_spin.value_changed.connect (() => {
			if (updating_properties)return;
			if (model.selected_index < 0)return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			el.gradient_angle = fill_gradient_angle_spin.get_value ();
			canvas.queue_draw ();
		});

		fill_opacity_spin.value_changed.connect (() => {
			if (updating_properties)return;
			if (model.selected_index < 0)return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			if (el.type == ElementType.LINE)return;
			float a = (float) (fill_opacity_spin.get_value () / 100.0);
			a = IconiUtils.clampf (a, 0.0f, 1.0f);
			var rgba = el.fill;
			rgba.alpha = a;
			el.fill = rgba;
			var grad = el.gradient_secondary;
			grad.alpha = rgba.alpha;
			el.gradient_secondary = grad;
			canvas.queue_draw ();
		});
		stroke_opacity_spin.value_changed.connect (() => {
			if (updating_properties)return;
			if (model.selected_index < 0)return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			float a = (float) (stroke_opacity_spin.get_value () / 100.0);
			a = IconiUtils.clampf (a, 0.0f, 1.0f);
			var rgba = el.stroke;
			rgba.alpha = a;
			el.stroke = rgba;
			if (el.type == ElementType.LINE) {
				var grad = el.gradient_secondary;
				grad.alpha = rgba.alpha;
				el.gradient_secondary = grad;
			}
			canvas.queue_draw ();
		});

		blend_drop.notify.connect ((pspec) => {
			if (updating_properties)return;
			if (pspec.name != "selected")return;
			if (model.selected_index < 0)return;
			uint idx = blend_drop.get_selected ();
			if (idx >= blends.length)return;
			var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
			el.blend_mode = blends[(int) idx];
			canvas.queue_draw ();
		});

		// Background property handlers
		bg_fill_mode_drop.notify.connect ((pspec) => {
			if (updating_properties)return;
			if (pspec.name != "selected")return;
			bool gradient = (bg_fill_mode_drop.get_selected () == 1u);
			model.use_gradient = gradient;
			sync_gradient_controls_visibility ();
			canvas.queue_draw ();
		});
		bg_gradient_end_btn.notify.connect ((pspec) => {
			if (updating_properties)return;
			if (pspec.name != "rgba")return;
			update_gradient_secondary_color (bg_gradient_end_btn.get_rgba ());
		});
		bg_gradient_angle_spin.value_changed.connect (() => {
			if (updating_properties)return;
			model.gradient_angle = bg_gradient_angle_spin.get_value ();
			if (model.use_gradient && !model.use_wallpaper) {
				canvas.queue_draw ();
			}
		});
		bg_side_color_btn.notify.connect ((pspec) => {
			if (updating_properties)return;
			if (pspec.name != "rgba")return;
			update_bg_color (bg_side_color_btn.get_rgba ());
		});
		bg_side_wall_switch.state_set.connect ((w, state) => {
			if (updating_properties)return false;
			apply_wallpaper_state (state);
			return false;
		});
		bg_effects_switch.state_set.connect ((w, state) => {
			if (updating_properties)return false;
			model.use_raised_effect = state;
			canvas.queue_draw ();
			return false;
		});
		bg_frame_switch.state_set.connect ((w, state) => {
			if (updating_properties)return false;
			model.use_frame_overlay = state;
			canvas.queue_draw ();
			return false;
		});
		bg_dev_switch.state_set.connect ((w, state) => {
			if (updating_properties)return false;
			model.show_dev_badge = state;
			canvas.queue_draw ();
			return false;
		});

		zoom_scale.value_changed.connect ((s) => {
			model.zoom = (float) zoom_scale.get_value ();
			zoom_label.set_label (Math.floor (zoom_scale.get_value () * 100).to_string () + "%");
			canvas.set_size_request ((int) (128 * model.zoom), (int) (128 * model.zoom));
			canvas.queue_draw ();
		});

		// Export (Gtk.FileDialog)
		export_btn.clicked.connect (() => {
			var file_dialog = new Gtk.FileDialog ();
			file_dialog.set_title ("Export SVG");
			var svg_filter = new Gtk.FileFilter ();
			svg_filter.set_filter_name ("SVG Files");
			svg_filter.add_suffix ("svg");
			var filters = new GLib.ListStore (typeof (Gtk.FileFilter));
			filters.append (svg_filter);
			file_dialog.set_filters (filters);
			file_dialog.set_default_filter (svg_filter);

			file_dialog.save.begin (this, null, (obj, res) => {
				try {
					var file = file_dialog.save.end (res);
					if (file == null)return;
					string? path = file.get_path ();
					if (path == null)return;
					string filename = path;
					if (!filename.has_suffix (".svg"))filename = filename + ".svg";
					export_to_svg (filename);
				} catch (GLib.Error e) {
					GLib.warning ("Export canceled or failed: %s", e.message);
				}
			});
		});

		sync_gradient_controls_visibility ();
		apply_wallpaper_state (model.use_wallpaper);
		update_view_background_color (model.view_background);
		props_area.set_visible (false);
		bg_props_area.set_visible (false);
		refresh_listbox ();
		this.present ();
	}

	// Helpers as private methods

	private void commit_name (Gtk.Entry entry, Gtk.Label label, Gtk.Stack stack) {
		model.name = entry.get_text ();
		label.set_text (model.name);
		stack.set_visible_child_name ("label");
	}

	private void refresh_listbox () {
		while (true) {
			var r = listbox.get_row_at_index (0);
			if (r == null)break;
			listbox.remove (r);
		}
		// Background row
		{
			var row = new Gtk.ListBoxRow ();
			row.set_size_request (-1, 42);
			var h = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
			h.add_css_class ("mini-content-block");
			var lbl = new Gtk.Label ("Background");
			lbl.set_xalign (0.0f);
			lbl.set_hexpand (true);
			h.append (lbl);
			row.set_child (h);
			listbox.append (row);
		}
		// Elements
		int n = (int) model.elements.get_n_items ();
		for (int i = 0; i < n; i++) {
			int idx = i;
			var el = (IconElement) model.elements.get_item ((uint) i);
			var row = new Gtk.ListBoxRow ();
			row.set_size_request (-1, 42);
			var h = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
			h.add_css_class ("mini-content-block");
			var lbl = new Gtk.Label (element_label (el));
			lbl.set_xalign (0.0f);
			lbl.set_hexpand (true);
			h.append (lbl);

			if (model.reorder_mode) {
				var up = new Gtk.Button.from_icon_name ("go-up-symbolic");
				var down = new Gtk.Button.from_icon_name ("go-down-symbolic");
				up.set_tooltip_text ("Move up");
				down.set_tooltip_text ("Move down");
				up.set_sensitive (idx > 0);
				down.set_sensitive (idx < n - 1);
				up.clicked.connect (() => { move_item (idx, idx - 1); });
				down.clicked.connect (() => { move_item (idx, idx + 1); });
				h.append (up);
				h.append (down);
			}

			var rem = new Gtk.Button.from_icon_name ("edit-delete-symbolic");
			rem.set_tooltip_text ("Remove");
			rem.set_valign (Gtk.Align.CENTER);
			rem.clicked.connect (() => { remove_element_at (idx); });
			h.append (rem);

			row.set_child (h);
			listbox.append (row);
		}

		// Restore selection
		if (model.background_selected) {
			var r0 = listbox.get_row_at_index (0);
			if (r0 != null)listbox.select_row (r0);
		} else if (model.selected_index >= 0) {
			var r2 = listbox.get_row_at_index (model.selected_index + 1);
			if (r2 != null)listbox.select_row (r2);
		} else {
			listbox.unselect_all ();
		}
	}

	private string element_label (IconElement e) {
		switch (e.type) {
		case ElementType.RECTANGLE : return "Rectangle";
		case ElementType.CIRCLE: return "Circle";
		case ElementType.LINE: return "Line";
		}
		return "Element";
	}

	private void remove_element_at (int index) {
		uint count = model.elements.get_n_items ();
		if (index < 0 || index >= (int) count)return;
		model.elements.remove ((uint) index);
		int remaining = (int) model.elements.get_n_items ();
		if (remaining == 0) {
			model.selected_index = -1;
			model.background_selected = true;
		} else {
			int next_index = index;
			if (next_index >= remaining)next_index = remaining - 1;
			model.selected_index = next_index;
			model.background_selected = false;
		}
		refresh_listbox ();
		update_properties_visibility ();
		canvas.queue_draw ();
	}

	private void move_item (int from, int to) {
		uint count = model.elements.get_n_items ();
		if (from < 0 || to < 0)return;
		if (from >= (int) count || to >= (int) count)return;
		if (from == to)return;
		var item = model.elements.get_item ((uint) from);
		if (item == null)return;
		model.elements.remove ((uint) from);
		model.elements.insert ((uint) to, item);
		if (model.selected_index == from) {
			model.selected_index = to;
		} else if (model.selected_index > from && model.selected_index <= to) {
			model.selected_index--;
		} else if (model.selected_index < from && model.selected_index >= to) {
			model.selected_index++;
		}
		refresh_listbox ();
		canvas.queue_draw ();
	}

	private Gtk.Popover create_view_color_popover () {
		var popover = new Gtk.Popover ();
		popover.set_autohide (true);
		popover.set_has_arrow (true);
		popover.set_position (Gtk.PositionType.BOTTOM);
		var content_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 8);
		content_box.set_margin_top (12);
		content_box.set_margin_bottom (12);
		content_box.set_margin_start (16);
		content_box.set_margin_end (16);
		popover.set_child (content_box);
		var heading = new Gtk.Label ("Pick a preview background swatch");
		heading.set_halign (Gtk.Align.START);
		content_box.append (heading);
		var grid = new Gtk.Grid ();
		content_box.append (grid);
		string[] ramp_labels = {
			"Red",
			"Orange",
			"Yellow",
			"Green",
			"Blue",
			"Indigo",
			"Violet",
			"Gray"
		};
		string[] ramp_hex = {
			"#E53935",
			"#FB8C00",
			"#FDD835",
			"#43A047",
			"#1E88E5",
			"#3949AB",
			"#8E24AA",
			"#616161"
		};
		double[] steps = { -0.75, -0.5, -0.25, 0.0, 0.25, 0.50, 0.75 };
		int ramp_count = ramp_labels.length;
		int shade_count = steps.length;
		for (int row = 0; row < ramp_count; row++) {
			var row_label = new Gtk.Label (ramp_labels[row]);
			row_label.set_halign (Gtk.Align.END);
			row_label.set_valign (Gtk.Align.CENTER);
			row_label.add_css_class ("dim-label");
			row_label.set_margin_end (12);
			grid.attach (row_label, 0, row, 1, 1);
			Gdk.RGBA base_color = IconiUtils.parse_hex_color (ramp_hex[row]);
			for (int col = 0; col < shade_count; col++) {
				if (steps[col] > 0.0) {
					Gdk.RGBA shade = IconiUtils.mix_with_white (base_color, steps[col]);
					var swatch = create_color_swatch_button (shade, popover);
					grid.attach (swatch, col + 1, row, 1, 1);
				} else if (steps[col] < 0.0) {
					double amount = GLib.Math.fabs (steps[col]);
					Gdk.RGBA dark = IconiUtils.mix_with_black (base_color, amount);
					var swatch = create_color_swatch_button (dark, popover);
					grid.attach (swatch, col + 1, row, 1, 1);
				} else {
					var swatch = create_color_swatch_button (base_color, popover);
					grid.attach (swatch, col + 1, row, 1, 1);
				}
			}
		}
		return popover;
	}

	private void toggle_view_color_popover () {
		if (view_color_popover.get_visible ()) {
			view_color_popover.popdown ();
			return;
		}
		update_view_color_popover_target ();
		view_color_popover.popup ();
	}

	private void update_view_color_popover_target () {
		Graphene.Rect bounds;
		if (!view_color_preview.compute_bounds (view_color_button, out bounds))return;
		Gdk.Rectangle rect = {};
		double origin_x = bounds.origin.x;
		double origin_y = bounds.origin.y;
		double width_d = GLib.Math.fmax (1.0, GLib.Math.ceil (bounds.size.width));
		double height_d = GLib.Math.fmax (1.0, GLib.Math.ceil (bounds.size.height));
		rect.x = (int) GLib.Math.floor (origin_x);
		rect.y = (int) GLib.Math.floor (origin_y);
		rect.width = (int) GLib.Math.floor (width_d);
		rect.height = (int) GLib.Math.floor (height_d);
		view_color_popover.set_pointing_to (rect);
	}

	private Gtk.Button create_color_swatch_button (Gdk.RGBA shade, Gtk.Popover popover) {
		var swatch_btn = new Gtk.Button ();
		swatch_btn.add_css_class ("swatch_button");
		swatch_btn.set_focus_on_click (false);
		swatch_btn.set_size_request (36, 42);
		swatch_btn.set_halign (Gtk.Align.CENTER);
		swatch_btn.set_valign (Gtk.Align.CENTER);
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
			update_view_background_color (copy);
			popover.popdown ();
		});
		return swatch_btn;
	}

	private void apply_view_background_css () {
		if (center_box == null)return;
		if (view_bg_css == null) {
			view_bg_css = new Gtk.CssProvider ();
			var display = center_box.get_display ();
			if (display != null) {
				Gtk.StyleContext.add_provider_for_display (display, view_bg_css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
			}
		}
		string css = build_view_background_css ();
		view_bg_css.load_from_data ((uint8[]) css);
	}

	private void update_view_color_preview () {
		if (view_color_preview != null) {
			view_color_preview.queue_draw ();
		}
	}

	private string build_view_background_css () {
		string color_decl = format_view_background_color ();
		bool needs_light_fg = should_use_light_view_foreground ();
		var builder = new GLib.StringBuilder ();
		if (!model.use_wallpaper) {
			builder.append ("#center-bg { %s".printf (color_decl));
			if (needs_light_fg) {
				builder.append (" color: rgba(255,255,255,1.0);");
			}
			builder.append (" }");
			if (needs_light_fg) {
				append_light_foreground_css (builder);
			}
			return builder.str;
		}
		string? uri = get_preferred_wallpaper_uri ();
		if (uri != null && wallpaper_uri_cache != uri) {
			wallpaper_uri_cache = uri;
		}
		builder.append ("#center-bg { %s".printf (color_decl));
		if (uri != null) {
			string escaped = IconiUtils.escape_css_url (uri);
			builder.append (" background-image: url(\"%s\"); background-size: cover; background-position: center; background-repeat: no-repeat;".printf (escaped));
		}
		builder.append (" color: rgba(255,255,255,1.0); }");
		append_light_foreground_css (builder);
		return builder.str;
	}

	private string format_view_background_color () {
		var vb = model.view_background;
		double rd = GLib.Math.fmax (0.0, GLib.Math.fmin (vb.red * 255.0, 255.0));
		double gd = GLib.Math.fmax (0.0, GLib.Math.fmin (vb.green * 255.0, 255.0));
		double bd = GLib.Math.fmax (0.0, GLib.Math.fmin (vb.blue * 255.0, 255.0));
		int r = (int) (rd + 0.5);
		int g = (int) (gd + 0.5);
		int b = (int) (bd + 0.5);
		return "background: rgba(%d, %d, %d, %.3f);".printf (r, g, b, vb.alpha);
	}

	private bool should_use_light_view_foreground () {
		if (model.use_wallpaper)return true;
		double bg_luminance = IconiUtils.compute_relative_luminance (model.view_background);
		double contrast_white = IconiUtils.contrast_ratio (bg_luminance, 1.0);
		double contrast_black = IconiUtils.contrast_ratio (bg_luminance, 0.0);
		bool white_ok = contrast_white >= 4.5;
		bool black_ok = contrast_black >= 4.5;
		if (white_ok && !black_ok)return true;
		if (!white_ok && black_ok)return false;
		if (white_ok && black_ok)return contrast_white >= contrast_black;
		return contrast_white > contrast_black;
	}

	private void append_light_foreground_css (GLib.StringBuilder builder) {
		builder.append (" #center-bg > label, #center-bg > button { color: rgba(255,255,255,1.0); } #center-bg button { background: rgba(255,255,255,0.32); color: rgba(255,255,255,1.0); } #center-bg entry, #center-bg entry * { background: rgba(255,255,255,0.32); color: rgba(255,255,255,1.0); } #center-bg entry { caret-color: rgba(255,255,255,1.0); } #center-bg button { border-color: rgba(255,255,255,0.55); }");
	}

	private void setup_wallpaper_settings () {
		if (wallpaper_settings != null)return;
		wallpaper_settings = new GLib.Settings ("org.gnome.desktop.background");
		wallpaper_settings.changed.connect ((key) => {
			if (key == "picture-uri" || key == "picture-uri-dark") {
				wallpaper_uri_cache = "";
				if (model.use_wallpaper) {
					apply_view_background_css ();
				}
			}
		});
	}

	private void apply_wallpaper_state (bool state) {
		model.use_wallpaper = state;
		bool previous = updating_properties;
		updating_properties = true;
		if (bg_side_wall_switch != null) {
			bg_side_wall_switch.set_active (state);
		}
		if (view_wall_toggle != null) {
			view_wall_toggle.set_active (state);
		}
		updating_properties = previous;
		apply_view_background_css ();
		update_view_color_preview ();
	}

	private string ? get_preferred_wallpaper_uri () {
		if (wallpaper_settings == null)return null;
		string primary = wallpaper_settings.get_string ("picture-uri");
		string? candidate = IconiUtils.normalize_wallpaper_entry (primary);
		if (candidate != null)return candidate;
		string secondary = wallpaper_settings.get_string ("picture-uri-dark");
		return IconiUtils.normalize_wallpaper_entry (secondary);
	}

	private void sync_gradient_controls_visibility () {
		if (bg_gradient_container == null)return;
		bool show = model.use_gradient;
		bg_gradient_container.set_visible (show);
	}

	private void update_properties_visibility () {
		updating_properties = true;
		try {
			bool show_bg = model.background_selected;
			bool show_el = (!model.background_selected && model.selected_index >= 0);

			bg_props_area.set_visible (show_bg);
			props_area.set_visible (show_el);

			if (show_bg) {
				bg_side_color_btn.set_rgba (model.background);
				bg_side_wall_switch.set_active (model.use_wallpaper);
				bg_effects_switch.set_active (model.use_raised_effect);
				bg_frame_switch.set_active (model.use_frame_overlay);
				bg_dev_switch.set_active (model.show_dev_badge);
				bg_fill_mode_drop.set_selected (model.use_gradient ? 1u : 0u);
				bg_gradient_end_btn.set_rgba (model.gradient_secondary);
				bg_gradient_angle_spin.set_value (model.gradient_angle);
			}
			if (show_el) {
				var el = (IconElement) model.elements.get_item ((uint) model.selected_index);
				x_entry.set_value ((double) el.x);
				y_entry.set_value ((double) el.y);
				w_entry.set_value ((double) el.width);
				h_entry.set_value ((double) el.height);
				stroke_width_spin.set_value ((double) el.stroke_width);
				fill_btn.set_rgba (el.fill);
				stroke_btn.set_rgba (el.stroke);

				int bidx = 0;
				for (int i = 0; i < blends.length; i++) {
					if (blends[i] == el.blend_mode) {
						bidx = i; break;
					}
				}
				blend_drop.set_selected ((uint) bidx);

				bool show_fill = (el.type != ElementType.LINE);
				fill_btn.set_visible (show_fill);
				fill_opacity_spin.set_sensitive (show_fill);

				fill_opacity_spin.set_value ((double) ((float) el.fill.alpha * 100.0f));
				stroke_opacity_spin.set_value ((double) ((float) el.stroke.alpha * 100.0f));
			}
			sync_gradient_controls_visibility ();
		} finally {
			updating_properties = false;
		}
	}

	private void update_bg_color (Gdk.RGBA rgba) {
		model.background = rgba;
		bool previous = updating_properties;
		updating_properties = true;
		bg_side_color_btn.set_rgba (rgba);
		updating_properties = previous;
		sync_gradient_controls_visibility ();
		canvas.queue_draw ();
	}

	private void update_view_background_color (Gdk.RGBA rgba) {
		model.view_background = rgba;
		apply_view_background_css ();
		update_view_color_preview ();
	}

	private void update_gradient_secondary_color (Gdk.RGBA rgba) {
		model.gradient_secondary = rgba;
		bool previous = updating_properties;
		updating_properties = true;
		bg_gradient_end_btn.set_rgba (rgba);
		updating_properties = previous;
		if (model.use_gradient && !model.use_wallpaper) {
			canvas.queue_draw ();
		}
	}

	private void refresh_line_deltas (IconElement el) {
		if (el.type != ElementType.LINE)return;
		double angle_rad = el.line_angle * (GLib.Math.PI / 180.0);
		double length = el.line_length;
		double dx = GLib.Math.cos (angle_rad) * length;
		double dy = GLib.Math.sin (angle_rad) * length;
		el.width = (float) dx;
		el.height = (float) dy;
	}

	private void export_to_svg (string filename) {
		double out_size = 128.0;
		var surface = new Cairo.SvgSurface (filename, out_size, out_size);
		var cr = new Cairo.Context (surface);
		renderer.render_icon (cr, 128);
		cr.show_page ();
		surface.finish ();
	}
}
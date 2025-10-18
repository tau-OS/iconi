public delegate void ColorPickerCallback (Gdk.RGBA color);

public class IconMakerWindow : He.ApplicationWindow {
	private IconModel model;
	private IconRenderer renderer;
	private const string ICON_ALIGN_TOP = "align-top-symbolic";
	private const string ICON_ALIGN_LEFT = "align-left-symbolic";
	private const string ICON_ALIGN_CENTER = "align-center-symbolic";
	private const string ICON_ALIGN_RIGHT = "align-right-symbolic";
	private const string ICON_ALIGN_BOTTOM = "align-bottom-symbolic";
	private const string ICON_LOCKED = "lock-closed-symbolic";
	private const string ICON_UNLOCKED = "lock-open-symbolic";

	// UI fields
	private Gtk.ListBox listbox;
	private Gtk.DrawingArea canvas;

	private Gtk.Box props_area;
	private Gtk.Box bg_props_area;
	private Gtk.Box group_props_area;
	private Gtk.Box center_box;
	private Gtk.Box right_box;
	private He.AppBar mappbar;

	private Gtk.SpinButton x_entry;
	private Gtk.SpinButton y_entry;
	private Gtk.SpinButton w_entry;
	private Gtk.SpinButton h_entry;
	private Gtk.Box size_box;
	private Gtk.Box pos_box;
	private Gtk.Box corner_box;
	private Gtk.Grid corner_grid;
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

	private enum CornerHandle {
		TOP_LEFT,
		TOP_RIGHT,
		BOTTOM_RIGHT,
		BOTTOM_LEFT
	}

	private Gtk.Button fill_btn;
	private Gtk.Button stroke_btn;
	private Gtk.SpinButton fill_opacity_spin;
	private Gtk.SpinButton stroke_opacity_spin;
	private Gtk.SpinButton stroke_width_spin;
	private Gtk.Label fill_label;
	private Gtk.Box fill_box;
	private Gtk.Label stroke_label;
	private Gtk.Box stroke_box;
	private Gtk.DropDown fill_mode_drop;
	private Gtk.Label fill_mode_label;
	private Gtk.Button fill_gradient_btn;
	private Gtk.SpinButton fill_gradient_angle_spin;
	private Gtk.Label fill_gradient_angle_label;
	private Gtk.Box fill_gradient_color_row;
	private Gtk.Box fill_gradient_angle_row;
	private Gtk.Box line_controls_box;
	private Gtk.SpinButton line_length_spin;
	private Gtk.SpinButton line_angle_spin;

	private Gtk.Box element_angle_box;
	private Gtk.SpinButton element_angle_spin;

	private Gtk.Box group_blend_box;
	private Gtk.DropDown group_blend_drop;
	private Gtk.Switch group_raised_toggle;
	private Gtk.Switch group_shadow_toggle;
	private Gtk.DropDown group_shadow_mode_drop;
	private Gtk.DropDown group_effect_scope_drop;

	private string[] blend_labels = { "Normal", "Multiply", "Screen", "Overlay", "Darken", "Lighten", "Color Dodge", "Color Burn", "Hard Light", "Soft Light", "Difference", "Exclusion", "Hue", "Saturation", "Color", "Luminosity" };
	private string[] blend_values = { "normal", "multiply", "screen", "overlay", "darken", "lighten", "color-dodge", "color-burn", "hard-light", "soft-light", "difference", "exclusion", "hue", "saturation", "color", "luminosity" };
	private string[] bg_fill_modes = { "Solid", "Gradient" };
	private string[] effect_scope_labels = { "Individual", "Combined" };

	private Gtk.Button bg_side_color_btn;
	private Gtk.Switch bg_side_wall_switch;
	private Gtk.DropDown bg_fill_mode_drop;
	private Gtk.Button bg_gradient_end_btn;
	private Gtk.SpinButton bg_gradient_angle_spin;
	private Gtk.Box bg_gradient_container;
	private Gtk.Box bg_canvas_bg_row;
	private Gtk.Box bg_fill_mode_row;
	private Gtk.Box bg_effects_row;
	private Gtk.Box bg_frame_row;
	private Gtk.Box bg_dev_row;

	private Gtk.Scale zoom_scale;
	private Gtk.Label zoom_label;
	private Gtk.Switch bg_effects_switch;
	private Gtk.Switch bg_frame_switch;
	private Gtk.Switch bg_dev_switch;

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
		set_size_request (360, 294);
		model = new IconModel ();
		renderer = new IconRenderer (model);
		setup_wallpaper_settings ();
		setup_ui ();
	}

	private IconElement ? get_selected_element () {
		if (model.selected_group_index < 0 || model.selected_element_index < 0)
			return null;
		var group = (ElementGroup) model.groups.get_item ((uint) model.selected_group_index);
		if (group == null)
			return null;
		return (IconElement?) group.elements.get_item ((uint) model.selected_element_index);
	}

	private void add_element_in_new_group (IconElement el) {
		var new_group = new ElementGroup (model.name);
		new_group.elements.append (el);
		model.groups.append (new_group);
		refresh_listbox ();
		canvas.queue_draw ();
	}

	private void load_svg_file (GLib.File file) {
		try {
			uint8[] contents;
			file.load_contents (null, out contents, null);
			var svg_data = (string) contents;
			var e = new IconElement (ElementType.SVG);
			e.svg_data = svg_data;
			add_element_in_new_group (e);
		} catch (Error err) {
			warning ("Failed to load SVG: %s", err.message);
		}
	}

	private void setup_ui () {
		var main_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 8);

		// Global key controller on main_box
		var key_controller = new Gtk.EventControllerKey ();
		main_box.add_controller (key_controller);
		key_controller.key_pressed.connect ((controller, keyval, keycode, state) => {
			if (keyval == Gdk.Key.Delete || keyval == Gdk.Key.BackSpace) {
				if (!model.background_selected && model.selected_group_index >= 0 && model.selected_element_index >= 0) {
					remove_element_at (model.selected_group_index, model.selected_element_index);
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
		left_box.set_halign (Gtk.Align.START);
		left_box.add_css_class ("sidebar-view");

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
		add_box.margin_bottom = 6;
		add_box.margin_top = 6;
		add_box.margin_start = 6;
		add_box.margin_end = 6;
		var add_rect_btn = new He.Button ("", "Rectangle");
		add_rect_btn.is_textual = true;
		var add_circle_btn = new He.Button ("", "Circle");
		add_circle_btn.is_textual = true;
		var add_line_btn = new He.Button ("", "Line");
		add_line_btn.is_textual = true;
		var add_svg_btn = new He.Button ("", "Image (.svg)");
		add_svg_btn.is_textual = true;
		add_box.append (add_rect_btn);
		add_box.append (add_circle_btn);
		add_box.append (add_line_btn);
		add_box.append (add_svg_btn);
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

		// Add drop target for external SVG files
		var drop_target = new Gtk.DropTarget (typeof (Gdk.FileList), Gdk.DragAction.COPY);
		drop_target.drop.connect ((dt, val, x, y) => {
			var file_list = (Gdk.FileList) val;
			var files = file_list.get_files ();
			for (int i = 0; i < files.length (); i++) {
				var file = files.nth_data (i);
				var path = file.get_path ();
				if (path != null && path.down ().has_suffix (".svg")) {
					load_svg_file (file);
				}
			}
			return true;
		});
		listbox.add_controller (drop_target);

		left_box.append (listbox);

		// CENTER
		center_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		center_box.set_hexpand (true);
		center_box.set_vexpand (true);
		center_box.set_name ("center-bg");

		mappbar = new He.AppBar ();
		mappbar.show_left_title_buttons = false;
		mappbar.show_right_title_buttons = false;
		mappbar.set_margin_end (342);
		mappbar.set_margin_start (272);
		mappbar.add_css_class ("main-appbar");
		center_box.append (mappbar);

		// Name label <-> entry via stack
		var name_label = new Gtk.Label (model.name);
		name_label.add_css_class ("view-title");
		name_label.set_halign (Gtk.Align.START);
		name_label.set_valign (Gtk.Align.CENTER);

		var name_entry = new He.TextField ();
		name_entry.is_outline = true;
		name_entry.get_internal_entry ().set_text (model.name);
		name_entry.set_halign (Gtk.Align.START);
		name_entry.set_size_request (180, -1);

		var name_stack = new Gtk.Stack ();
		name_stack.add_named (name_label, "label");
		name_stack.add_named (name_entry, "entry");
		name_stack.set_visible_child_name ("label");

		var name_click = new Gtk.GestureClick ();
		name_label.add_controller (name_click);
		name_click.released.connect ((g, n_press, x, y) => {
			name_stack.set_visible_child_name ("entry");
			name_entry.grab_focus ();
			name_entry.get_internal_entry ().select_region (0, -1);
		});
		var focus_ctl = new Gtk.EventControllerFocus ();
		name_entry.get_internal_entry ().add_controller (focus_ctl);
		focus_ctl.leave.connect (() => { commit_name (name_entry.get_internal_entry (), name_label, name_stack); });
		name_entry.get_internal_entry ().activate.connect (() => { commit_name (name_entry.get_internal_entry (), name_label, name_stack); });

		mappbar.viewtitle_widget = name_stack;

		// View background selector buttons
		var view_bg_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		view_bg_box.set_valign (Gtk.Align.CENTER);
		view_bg_box.add_css_class ("linked");

		// Wallpaper button
		var wallpaper_btn = new Gtk.ToggleButton ();
		wallpaper_btn.add_css_class ("wallpaper-btn");
		wallpaper_btn.set_tooltip_text ("Show system wallpaper behind preview");
		var wallpaper_icon = new Gtk.DrawingArea ();
		wallpaper_icon.set_content_width (32);
		wallpaper_icon.set_content_height (30);
		wallpaper_icon.set_draw_func ((area, cr, width, height) => {
			double w = width - 2;
			double h = height;
			double cx = w / 2.0;
			double cy = h / 2.0;
			double r = GLib.Math.fmin (w, h) / 2.0;

			cr.save ();
			cr.arc (cx + 1, cy, r, 0.0, 2.0 * GLib.Math.PI);
			cr.clip ();

			string? wp_uri = get_preferred_wallpaper_uri ();
			if (wp_uri != null && wp_uri.has_prefix ("file://")) {
				string path = wp_uri.substring (7);
				try {
					var pixbuf = new Gdk.Pixbuf.from_file (path);
					int pw = pixbuf.get_width ();
					int ph = pixbuf.get_height ();

					double scale = GLib.Math.fmax (w / (double) pw, h / (double) ph);
					double sw = pw * scale;
					double sh = ph * scale;
					double ox = (w - sw) / 2.0;
					double oy = (h - sh) / 2.0;

					cr.scale (scale, scale);
					Gdk.cairo_set_source_pixbuf (cr, pixbuf, ox / scale, oy / scale);
					cr.paint ();
				} catch (Error e) {
					cr.set_source_rgba (0.5, 0.5, 0.5, 1.0);
					cr.paint ();
				}
			} else {
				cr.set_source_rgba (0.5, 0.5, 0.5, 1.0);
				cr.paint ();
			}

			cr.restore ();
		});
		wallpaper_btn.set_child (wallpaper_icon);
		view_bg_box.append (wallpaper_btn);

		// Gray button
		var gray_btn = new Gtk.ToggleButton ();
		gray_btn.add_css_class ("gray-btn");
		gray_btn.set_tooltip_text ("Show gray background behind preview");
		var gray_icon = new Gtk.DrawingArea ();
		gray_icon.set_content_width (32);
		gray_icon.set_content_height (30);
		gray_icon.set_draw_func ((area, cr, width, height) => {
			double w = width - 2;
			double h = height;
			double cx = w / 2.0;
			double cy = h / 2.0;
			double r = GLib.Math.fmin (w, h) / 2.0;

			cr.arc (cx + 1, cy, r, 0.0, 2.0 * GLib.Math.PI);
			cr.set_source_rgb (0.533, 0.533, 0.533);
			cr.fill_preserve ();
			cr.stroke ();
		});
		gray_btn.set_child (gray_icon);
		view_bg_box.append (gray_btn);

		mappbar.append (view_bg_box);

		wallpaper_btn.toggled.connect (() => {
			if (updating_properties)return;
			if (wallpaper_btn.get_active ()) {
				updating_properties = true;
				gray_btn.set_active (false);
				updating_properties = false;
				apply_wallpaper_state (true);
				wallpaper_icon.queue_draw ();
				gray_icon.queue_draw ();
			}
		});

		gray_btn.toggled.connect (() => {
			if (updating_properties)return;
			if (gray_btn.get_active ()) {
				updating_properties = true;
				wallpaper_btn.set_active (false);
				updating_properties = false;
				apply_wallpaper_state (false);
				wallpaper_icon.queue_draw ();
				gray_icon.queue_draw ();
			}
		});

		bool toggle_prev = updating_properties;
		updating_properties = true;
		if (model.use_wallpaper) {
			wallpaper_btn.set_active (true);
		} else {
			gray_btn.set_active (true);
		}
		updating_properties = toggle_prev;

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
		canvas.set_margin_end (342);
		canvas.set_margin_start (272);
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
			renderer.render_icon (cr, 109.0f);
			cr.restore ();
		});

		// RIGHT SIDEBAR
		right_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		right_box.set_size_request (300, -1);
		right_box.set_vexpand (true);
		right_box.set_hexpand_set (true);
		right_box.set_halign (Gtk.Align.END);
		right_box.add_css_class ("inspector-view");

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

		// Properties area
		var main_props_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
		main_props_box.set_vexpand (true);
		main_props_box.set_hexpand (true);

		props_area = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		props_area.set_size_request (300, -1);
		props_area.margin_start = 18;
		props_area.margin_bottom = 18;
		props_area.margin_end = 18;
		main_props_box.append (props_area);

		bg_props_area = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		bg_props_area.set_size_request (300, -1);
		bg_props_area.margin_start = 18;
		bg_props_area.margin_bottom = 18;
		bg_props_area.margin_end = 18;
		main_props_box.append (bg_props_area);

		group_props_area = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		group_props_area.set_size_request (300, -1);
		group_props_area.margin_start = 18;
		group_props_area.margin_bottom = 18;
		group_props_area.margin_end = 18;
		main_props_box.append (group_props_area);

		var scrolled = new Gtk.ScrolledWindow ();
		scrolled.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
		scrolled.set_child (main_props_box);
		right_box.append (scrolled);

		// Background properties (right)
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
		bg_gradient_angle_spin = new Gtk.SpinButton.with_range (0, 360, 1);
		bg_gradient_angle_spin.set_value (model.gradient_angle);
		gradient_angle_row.append (bg_gradient_angle_spin);
		bg_gradient_container.append (gradient_angle_row);
		bg_props_area.append (bg_gradient_container);
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

		// Group properties
		group_blend_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		group_blend_box.add_css_class ("mini-content-block");
		var group_blend_label = new Gtk.Label ("Blend Mode") { xalign = 0.0f, hexpand = true };
		group_blend_label.add_css_class ("caption");
		group_blend_box.append (group_blend_label);
		group_blend_drop = new Gtk.DropDown.from_strings (blend_labels);
		group_blend_box.append (group_blend_drop);
		group_props_area.append (group_blend_box);

		var group_raised_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		group_raised_box.add_css_class ("mini-content-block");
		var group_raised_label = new Gtk.Label ("Raised Effect") { xalign = 0.0f, hexpand = true };
		group_raised_label.add_css_class ("caption");
		group_raised_box.append (group_raised_label);
		group_raised_toggle = new Gtk.Switch ();
		group_raised_toggle.set_valign (Gtk.Align.CENTER);
		group_raised_box.append (group_raised_toggle);
		group_props_area.append (group_raised_box);

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
		var shadow_mode_labels = new string[] { "Mono", "Chromatic" };
		group_shadow_mode_drop = new Gtk.DropDown.from_strings (shadow_mode_labels);
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

		// Element properties
		pos_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		pos_box.add_css_class ("mini-content-block");
		x_entry = new Gtk.SpinButton.with_range (0, 109, 1);
		y_entry = new Gtk.SpinButton.with_range (0, 109, 1);
		var x_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		var x_label = new Gtk.Label ("X") { xalign = 0.0f, hexpand = true };
		x_label.add_css_class ("caption");
		x_box.append (x_label);
		x_box.append (x_entry);
		pos_box.append (x_box);
		var y_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		var y_label = new Gtk.Label ("Y") { xalign = 0.0f, hexpand = true };
		y_label.add_css_class ("caption");
		y_box.append (y_label);
		y_box.append (y_entry);
		pos_box.append (y_box);
		props_area.append (pos_box);

		size_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		size_box.add_css_class ("mini-content-block");
		w_entry = new Gtk.SpinButton.with_range (1, 109, 1);
		h_entry = new Gtk.SpinButton.with_range (1, 109, 1);
		var width_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		var width_label = new Gtk.Label ("Width") { xalign = 0.0f, hexpand = true };
		width_label.add_css_class ("caption");
		width_box.append (width_label);
		width_box.append (w_entry);
		size_box.append (width_box);
		var height_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		var height_label = new Gtk.Label ("Height") { xalign = 0.0f, hexpand = true };
		height_label.add_css_class ("caption");
		height_box.append (height_label);
		height_box.append (h_entry);
		size_box.append (height_box);
		props_area.append (size_box);

		corner_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		corner_box.add_css_class ("mini-content-block");
		var corner_radius_label = new Gtk.Label ("Corner Radius") { xalign = 0.0f, hexpand = true };
		corner_radius_label.add_css_class ("caption");
		corner_box.append (corner_radius_label);
		corner_grid = new Gtk.Grid ();
		corner_grid.set_column_spacing (6);
		corner_grid.set_row_spacing (6);
		corner_grid.set_column_homogeneous (true);
		corner_grid.set_row_homogeneous (true);
		corner_grid.set_halign (Gtk.Align.CENTER);
		corner_grid.set_valign (Gtk.Align.CENTER);
		corner_grid.set_hexpand (false);
		corner_radius_tl_entry = create_corner_entry ();
		corner_radius_tr_entry = create_corner_entry ();
		corner_radius_br_entry = create_corner_entry ();
		corner_radius_bl_entry = create_corner_entry ();
		corner_radius_lock_toggle = new Gtk.ToggleButton ();
		corner_radius_lock_toggle.add_css_class ("flat");
		corner_radius_lock_toggle.add_css_class ("circular");
		corner_radius_lock_toggle.set_focus_on_click (false);
		corner_radius_lock_toggle.set_tooltip_text ("Lock corner radii");
		corner_radius_lock_toggle.set_halign (Gtk.Align.CENTER);
		corner_radius_lock_toggle.set_valign (Gtk.Align.CENTER);
		corner_radius_lock_picture = create_icon_picture (ICON_LOCKED);
		corner_radius_lock_toggle.set_child (corner_radius_lock_picture);
		corner_grid.attach (corner_radius_tl_entry, 0, 0, 1, 1);
		corner_grid.attach (corner_radius_tr_entry, 2, 0, 1, 1);
		corner_grid.attach (corner_radius_bl_entry, 0, 2, 1, 1);
		corner_grid.attach (corner_radius_br_entry, 2, 2, 1, 1);
		corner_grid.attach (corner_radius_lock_toggle, 1, 1, 1, 1);
		corner_radius_lock_toggle.set_active (true);
		update_corner_lock_icon ();
		corner_box.append (corner_grid);
		corner_box.set_visible (false);
		props_area.append (corner_box);

		align_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		align_box.add_css_class ("mini-content-block");
		var align_label = new Gtk.Label ("Alignment") { xalign = 0.0f, hexpand = true };
		align_label.add_css_class ("caption");
		align_box.append (align_label);
		align_grid = new Gtk.Grid ();
		align_grid.set_column_homogeneous (true);
		align_grid.set_row_homogeneous (true);
		align_grid.set_halign (Gtk.Align.CENTER);
		align_grid.set_valign (Gtk.Align.CENTER);
		align_grid.set_hexpand (false);
		align_left_btn = create_align_icon_button (ICON_ALIGN_LEFT, "Align left");
		align_center_btn = create_align_icon_button (ICON_ALIGN_CENTER, "Align center");
		align_right_btn = create_align_icon_button (ICON_ALIGN_RIGHT, "Align right");
		align_top_btn = create_align_icon_button (ICON_ALIGN_TOP, "Align top");
		align_bottom_btn = create_align_icon_button (ICON_ALIGN_BOTTOM, "Align bottom");
		align_grid.attach (align_top_btn, 1, 0, 1, 1);
		align_grid.attach (align_left_btn, 0, 1, 1, 1);
		align_grid.attach (align_center_btn, 1, 1, 1, 1);
		align_grid.attach (align_right_btn, 2, 1, 1, 1);
		align_grid.attach (align_bottom_btn, 1, 2, 1, 1);
		align_box.append (align_grid);
		props_area.append (align_box);

		line_controls_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		line_controls_box.add_css_class ("mini-content-block");
		line_length_spin = new Gtk.SpinButton.with_range (1, 155, 1);
		line_angle_spin = new Gtk.SpinButton.with_range (0, 360, 1);
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
		element_angle_spin = new Gtk.SpinButton.with_range (0, 360, 1);
		var rotation_label = new Gtk.Label ("Rotation") { xalign = 0.0f, hexpand = true };
		rotation_label.add_css_class ("caption");
		element_angle_box.append (rotation_label);
		element_angle_box.append (element_angle_spin);
		props_area.append (element_angle_box);

		// Fill controls (grouped)
		fill_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		fill_box.add_css_class ("mini-content-block");

		fill_label = new Gtk.Label ("Fill Color");
		fill_label.set_xalign (0.0f);
		fill_label.set_hexpand (true);
		fill_label.add_css_class ("caption");
		Gdk.RGBA default_fill = { 0 };
		default_fill.parse ("#ffffff");
		fill_btn = create_color_button (default_fill);
		var fill_color_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		fill_color_row.append (fill_label);
		fill_color_row.append (fill_btn);
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

		fill_opacity_spin = new Gtk.SpinButton.with_range (0, 100, 1);
		var fill_opacity_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		var fill_opacity_label = new Gtk.Label ("Fill Opacity (%)") { xalign = 0.0f, hexpand = true };
		fill_opacity_label.add_css_class ("caption");
		fill_opacity_row.append (fill_opacity_label);
		fill_opacity_row.append (fill_opacity_spin);
		fill_box.append (fill_opacity_row);

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

		fill_gradient_angle_spin = new Gtk.SpinButton.with_range (0, 360, 1);
		fill_gradient_angle_spin.set_value (0.0);
		fill_gradient_angle_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		var gradient_angle_label2 = new Gtk.Label ("Gradient Angle") { xalign = 0.0f, hexpand = true };
		gradient_angle_label2.add_css_class ("caption");
		fill_gradient_angle_row.append (gradient_angle_label2);
		fill_gradient_angle_row.append (fill_gradient_angle_spin);
		fill_gradient_angle_row.set_visible (false);
		fill_box.append (fill_gradient_angle_row);

		props_area.append (fill_box);

		// Stroke controls (grouped)
		stroke_box = new Gtk.Box (Gtk.Orientation.VERTICAL, 6);
		stroke_box.add_css_class ("mini-content-block");

		stroke_label = new Gtk.Label ("Stroke Color");
		stroke_label.set_xalign (0.0f);
		stroke_label.set_hexpand (true);
		stroke_label.add_css_class ("caption");
		Gdk.RGBA default_stroke = { 0 };
		default_stroke.parse ("#000000");
		stroke_btn = create_color_button (default_stroke);
		var stroke_color_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		stroke_color_row.append (stroke_label);
		stroke_color_row.append (stroke_btn);
		stroke_box.append (stroke_color_row);

		stroke_opacity_spin = new Gtk.SpinButton.with_range (0, 100, 1);
		var stroke_opacity_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		var stroke_opacity_label = new Gtk.Label ("Stroke Opacity (%)") { xalign = 0.0f, hexpand = true };
		stroke_opacity_label.add_css_class ("caption");
		stroke_opacity_row.append (stroke_opacity_label);
		stroke_opacity_row.append (stroke_opacity_spin);
		stroke_box.append (stroke_opacity_row);

		stroke_width_spin = new Gtk.SpinButton.with_range (0, 20, 0.5);
		stroke_width_spin.set_digits (1);
		var stroke_width_row = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		var stroke_width_label = new Gtk.Label ("Stroke Width") { xalign = 0.0f, hexpand = true };
		stroke_width_label.add_css_class ("caption");
		stroke_width_row.append (stroke_width_label);
		stroke_width_row.append (stroke_width_spin);
		stroke_box.append (stroke_width_row);

		props_area.append (stroke_box);

		// Signals

		listbox.row_selected.connect ((lb, row) => {
			if (row == null) {
				model.background_selected = false;
				model.group_selected = false;
				model.selected_group_index = -1;
				model.selected_element_index = -1;
			} else {
				int ridx = row.get_index ();
				if (ridx == 0) {
					model.background_selected = true;
					model.group_selected = false;
					model.selected_group_index = -1;
					model.selected_element_index = -1;
				} else {
					model.background_selected = false;
					model.group_selected = false;
					// Calculate which group and element based on flat index
					// Each group has: 1 header row + N element rows
					int flat_idx = ridx - 1;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         // subtract background row
					int count = 0;
					bool found = false;
					for (int g = 0; g < (int) model.groups.get_n_items (); g++) {
						var group = (ElementGroup) model.groups.get_item ((uint) g);
						int ne = (int) group.elements.get_n_items ();
						// Check if flat_idx points to this group's header
						if (flat_idx == count) {
							// Selected group header
							model.group_selected = true;
							model.selected_group_index = g;
							model.selected_element_index = -1;
							found = true;
							break;
						}
						count++;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 // group header
						// Check if flat_idx is within this group's elements
						if (flat_idx < count + ne) {
							model.selected_group_index = g;
							model.selected_element_index = flat_idx - count;
							found = true;
							break;
						}
						count += ne;
					}
					if (!found) {
						model.selected_group_index = -1;
						model.selected_element_index = -1;
					}
				}
			}
			update_properties_visibility ();
			canvas.queue_draw ();
		});

		add_rect_btn.clicked.connect (() => {
			add_element_in_new_group (new IconElement (ElementType.RECTANGLE));
		});
		add_circle_btn.clicked.connect (() => {
			add_element_in_new_group (new IconElement (ElementType.CIRCLE));
		});
		add_line_btn.clicked.connect (() => {
			var e = new IconElement (ElementType.LINE);
			e.line_length = 56.0f;
			e.line_angle = 0.0;
			e.gradient_secondary = e.stroke;
			refresh_line_deltas (e);
			add_element_in_new_group (e);
		});

		add_svg_btn.clicked.connect (() => {
			var file_chooser = new Gtk.FileDialog ();
			var filter = new Gtk.FileFilter ();
			filter.set_filter_name ("SVG Files");
			filter.add_mime_type ("image/svg+xml");
			filter.add_pattern ("*.svg");
			var filters = new GLib.ListStore (typeof (Gtk.FileFilter));
			filters.append (filter);
			file_chooser.set_filters (filters);
			file_chooser.open.begin (this, null, (obj, res) => {
				try {
					var file = file_chooser.open.end (res);
					if (file != null) {
						load_svg_file (file);
					}
				} catch (Error e) {
					// User cancelled or error occurred
				}
			});
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

			model.selected_group_index = -1;
			model.selected_element_index = -1;
			model.background_selected = false;
			for (int grp = (int) model.groups.get_n_items () - 1; grp >= 0; grp--) {
				var group = (ElementGroup) model.groups.get_item ((uint) grp);
				int ne = (int) group.elements.get_n_items ();
				for (int i = ne - 1; i >= 0; i--) {
					var el = (IconElement) group.elements.get_item ((uint) i);
					if (relx >= el.x && relx <= el.x + el.width && rely >= el.y && rely <= el.y + el.height) {
						model.selected_group_index = grp;
						model.selected_element_index = i;
						break;
					}
				}
				if (model.selected_element_index >= 0)break;
			}
			if (model.selected_group_index >= 0 && model.selected_element_index >= 0) {
				// Calculate flat index with group headers
				int flat_index = 1;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 // background row
				for (int grp2 = 0; grp2 < model.selected_group_index; grp2++) {
					var group = (ElementGroup) model.groups.get_item ((uint) grp2);
					flat_index++;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         // group header
					flat_index += (int) group.elements.get_n_items ();
				}
				flat_index++;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 // selected group's header
				flat_index += model.selected_element_index;
				var row2 = listbox.get_row_at_index (flat_index);
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
			var el = get_selected_element ();
			if (el == null)return;
			el.x = (float) GLib.Math.fmin (GLib.Math.fmax ((float) x_entry.get_value (), 0.0f), 109.0f);
			canvas.queue_draw ();
		});
		y_entry.value_changed.connect (() => {
			if (updating_properties)return;
			var el = get_selected_element ();
			if (el == null)return;
			el.y = (float) GLib.Math.fmin (GLib.Math.fmax ((float) y_entry.get_value (), 0.0f), 109.0f);
			canvas.queue_draw ();
		});
		w_entry.value_changed.connect (() => {
			if (updating_properties)return;
			var el = get_selected_element ();
			if (el == null)return;
			if (el.type == ElementType.LINE)return;
			el.width = (float) GLib.Math.fmin (GLib.Math.fmax ((float) w_entry.get_value (), 1.0f), 109.0f);
			apply_corner_radius_constraints (el);
			canvas.queue_draw ();
		});
		h_entry.value_changed.connect (() => {
			if (updating_properties)return;
			var el = get_selected_element ();
			if (el == null)return;
			if (el.type == ElementType.LINE)return;
			el.height = (float) GLib.Math.fmin (GLib.Math.fmax ((float) h_entry.get_value (), 1.0f), 109.0f);
			apply_corner_radius_constraints (el);
			canvas.queue_draw ();
		});
		stroke_width_spin.value_changed.connect (() => {
			if (updating_properties)return;
			var el = get_selected_element ();
			if (el == null)return;
			el.stroke_width = (float) stroke_width_spin.get_value ();
			canvas.queue_draw ();
		});

		line_length_spin.value_changed.connect (() => {
			if (updating_properties)return;
			var el = get_selected_element ();
			if (el == null)return;
			if (el.type != ElementType.LINE)return;
			float value = (float) GLib.Math.fmax (line_length_spin.get_value (), 1.0);
			el.line_length = value;
			refresh_line_deltas (el);
			canvas.queue_draw ();
		});

		line_angle_spin.value_changed.connect (() => {
			if (updating_properties)return;
			var el = get_selected_element ();
			if (el == null)return;
			if (el.type != ElementType.LINE)return;
			el.line_angle = line_angle_spin.get_value ();
			refresh_line_deltas (el);
			canvas.queue_draw ();
		});

		element_angle_spin.value_changed.connect (() => {
			if (updating_properties)return;
			var el = get_selected_element ();
			if (el == null)return;
			el.element_angle = element_angle_spin.get_value ();
			canvas.queue_draw ();
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
			if (updating_properties)return;
			var el = get_selected_element ();
			if (el == null)return;
			if (el.type != ElementType.RECTANGLE)return;
			bool locked = corner_radius_lock_toggle.get_active ();
			el.corner_radius_locked = locked;
			if (locked) {
				double sum = el.corner_radius_top_left + el.corner_radius_top_right + el.corner_radius_bottom_right + el.corner_radius_bottom_left;
				double avg = sum / 4.0;
				float uniform = (float) GLib.Math.round (avg);
				el.corner_radius_top_left = uniform;
				el.corner_radius_top_right = uniform;
				el.corner_radius_bottom_right = uniform;
				el.corner_radius_bottom_left = uniform;
			}
			apply_corner_radius_constraints (el);
			update_corner_lock_icon ();
			canvas.queue_draw ();
		});
		align_left_btn.clicked.connect (() => {
			align_selected_element_horizontal (0);
		});
		align_center_btn.clicked.connect (() => {
			align_selected_element_horizontal (1);
			align_selected_element_vertical (1);
		});
		align_right_btn.clicked.connect (() => {
			align_selected_element_horizontal (2);
		});
		align_top_btn.clicked.connect (() => {
			align_selected_element_vertical (0);
		});
		align_bottom_btn.clicked.connect (() => {
			align_selected_element_vertical (2);
		});

		fill_btn.clicked.connect (() => {
			if (updating_properties)return;
			var el = get_selected_element ();
			if (el == null)return;
			if (el.type == ElementType.LINE)return;
			show_color_picker_popover (fill_btn, get_color_button_color (fill_btn), (new_color) => {
				float a = (float) (fill_opacity_spin.get_value () / 100.0);
				a = IconiUtils.clampf (a, 0.0f, 1.0f);
				new_color.alpha = a;
				el.fill = new_color;
				var grad = el.gradient_secondary;
				grad.alpha = new_color.alpha;
				el.gradient_secondary = grad;
				update_color_button (fill_btn, new_color);
				canvas.queue_draw ();
			});
		});
		stroke_btn.clicked.connect (() => {
			if (updating_properties)return;
			var el = get_selected_element ();
			if (el == null)return;
			show_color_picker_popover (stroke_btn, get_color_button_color (stroke_btn), (new_color) => {
				float a = (float) (stroke_opacity_spin.get_value () / 100.0);
				a = IconiUtils.clampf (a, 0.0f, 1.0f);
				new_color.alpha = a;
				el.stroke = new_color;
				if (el.type == ElementType.LINE) {
					var grad = el.gradient_secondary;
					grad.alpha = new_color.alpha;
					el.gradient_secondary = grad;
				}
				update_color_button (stroke_btn, new_color);
				canvas.queue_draw ();
			});
		});

		fill_mode_drop.notify.connect ((pspec) => {
			if (updating_properties)return;
			if (pspec.name != "selected")return;
			var el = get_selected_element ();
			if (el == null)return;
			el.use_gradient = (fill_mode_drop.get_selected () == 1u);
			fill_gradient_color_row.set_visible (el.use_gradient);
			fill_gradient_angle_row.set_visible (el.use_gradient);
			canvas.queue_draw ();
		});

		fill_gradient_btn.clicked.connect (() => {
			if (updating_properties)return;
			var el = get_selected_element ();
			if (el == null)return;
			show_color_picker_popover (fill_gradient_btn, get_color_button_color (fill_gradient_btn), (new_color) => {
				if (el.type == ElementType.LINE) {
					new_color.alpha = el.stroke.alpha;
				} else {
					new_color.alpha = el.fill.alpha;
				}
				el.gradient_secondary = new_color;
				update_color_button (fill_gradient_btn, new_color);
				canvas.queue_draw ();
			});
		});

		fill_gradient_angle_spin.value_changed.connect (() => {
			if (updating_properties)return;
			var el = get_selected_element ();
			if (el == null)return;
			el.gradient_angle = fill_gradient_angle_spin.get_value ();
			canvas.queue_draw ();
		});

		fill_opacity_spin.value_changed.connect (() => {
			if (updating_properties)return;
			var el = get_selected_element ();
			if (el == null)return;
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
			var el = get_selected_element ();
			if (el == null)return;
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

		// Background property handlers
		bg_fill_mode_drop.notify.connect ((pspec) => {
			if (updating_properties)return;
			if (pspec.name != "selected")return;
			bool gradient = (bg_fill_mode_drop.get_selected () == 1u);
			model.use_gradient = gradient;
			sync_gradient_controls_visibility ();
			canvas.queue_draw ();
		});
		bg_gradient_end_btn.clicked.connect (() => {
			if (updating_properties)return;
			show_color_picker_popover (bg_gradient_end_btn, get_color_button_color (bg_gradient_end_btn), (new_color) => {
				update_gradient_secondary_color (new_color);
			});
		});
		bg_gradient_angle_spin.value_changed.connect (() => {
			if (updating_properties)return;
			model.gradient_angle = bg_gradient_angle_spin.get_value ();
			if (model.use_gradient && !model.use_wallpaper) {
				canvas.queue_draw ();
			}
		});
		bg_side_color_btn.clicked.connect (() => {
			if (updating_properties)return;
			show_color_picker_popover (bg_side_color_btn, get_color_button_color (bg_side_color_btn), (new_color) => {
				update_bg_color (new_color);
			});
		});

		// Group property handlers
		group_blend_drop.notify.connect ((pspec) => {
			if (updating_properties)return;
			if (pspec.name != "selected")return;
			if (model.selected_group_index < 0)return;
			uint idx = group_blend_drop.get_selected ();
			if (idx >= blend_labels.length)return;
			var group = (ElementGroup?) model.groups.get_item ((uint) model.selected_group_index);
			if (group != null) {
				group.blend_mode = blend_values[(int) idx];
				canvas.queue_draw ();
			}
		});
		group_raised_toggle.state_set.connect ((w, state) => {
			if (updating_properties)return false;
			if (model.selected_group_index < 0)return false;
			var group = (ElementGroup?) model.groups.get_item ((uint) model.selected_group_index);
			if (group != null) {
				group.use_raised_effect = state;
				canvas.queue_draw ();
			}
			return false;
		});
		group_shadow_toggle.state_set.connect ((w, state) => {
			if (updating_properties)return false;
			if (model.selected_group_index < 0)return false;
			var group = (ElementGroup?) model.groups.get_item ((uint) model.selected_group_index);
			if (group != null) {
				group.use_shadow = state;
				canvas.queue_draw ();
			}
			return false;
		});
		group_shadow_mode_drop.notify.connect ((pspec) => {
			if (updating_properties)return;
			if (pspec.name != "selected")return;
			if (model.selected_group_index < 0)return;
			var group = (ElementGroup?) model.groups.get_item ((uint) model.selected_group_index);
			if (group != null) {
				group.shadow_chromatic = (group_shadow_mode_drop.get_selected () == 1);
				canvas.queue_draw ();
			}
		});
		group_effect_scope_drop.notify.connect ((pspec) => {
			if (updating_properties)return;
			if (pspec.name != "selected")return;
			if (model.selected_group_index < 0)return;
			var group = (ElementGroup?) model.groups.get_item ((uint) model.selected_group_index);
			if (group != null) {
				group.effect_scope = (group_effect_scope_drop.get_selected () == 1u) ? GroupEffectScope.COMBINED : GroupEffectScope.INDIVIDUAL;
				canvas.queue_draw ();
			}
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
		props_area.set_visible (false);
		bg_props_area.set_visible (false);
		right_box.set_visible (false);
		update_sidebar_visibility (false);
		refresh_listbox ();

		main_box.append (center_box);

		var overlay = new Gtk.Overlay ();
		overlay.set_hexpand (true);
		overlay.set_vexpand (true);
		overlay.set_halign (Gtk.Align.FILL);
		overlay.set_valign (Gtk.Align.FILL);
		overlay.set_child (main_box);
		overlay.add_overlay (left_box);
		overlay.add_overlay (right_box);
		this.set_child (overlay);

		this.present ();
	}

	// Helpers as private methods

	private void commit_name (Gtk.Text entry, Gtk.Label label, Gtk.Stack stack) {
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
			var lbl = new Gtk.Label (model.name);
			lbl.add_css_class ("cb-title");
			lbl.add_css_class ("caption");
			lbl.set_xalign (0.0f);
			lbl.set_hexpand (true);
			h.append (lbl);
			row.set_child (h);
			listbox.append (row);
		}
		// Groups and elements
		int ng = (int) model.groups.get_n_items ();
		for (int g = 0; g < ng; g++) {
			int group_idx = g;
			var group = (ElementGroup) model.groups.get_item ((uint) g);

			// Group header row
			{
				var row = new Gtk.ListBoxRow ();
				row.set_size_request (-1, 42);
				var h = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
				h.add_css_class ("mini-content-block");
				h.set_margin_start (8);
				var lbl = new Gtk.Label ("Group");
				lbl.add_css_class ("caption");
				lbl.set_xalign (0.0f);
				lbl.set_hexpand (true);
				h.append (lbl);
				row.set_child (h);

				if (model.reorder_mode) {
					var drop_target = new Gtk.DropTarget (typeof (string), Gdk.DragAction.MOVE);
					drop_target.drop.connect ((dt, val, x, y) => {
						var drag_data = (string) val;
						var parts = drag_data.split (":");
						if (parts.length == 2) {
							int src_group = int.parse (parts[0]);
							int src_elem = int.parse (parts[1]);
							int target_pos = (int) group.elements.get_n_items ();
							move_element_between_groups (src_group, src_elem, group_idx, target_pos);
						}
						return true;
					});
					row.add_controller (drop_target);
				}

				listbox.append (row);
			}

			int ne = (int) group.elements.get_n_items ();
			for (int i = 0; i < ne; i++) {
				int elem_idx = i;
				var el = (IconElement) group.elements.get_item ((uint) i);
				var row = new Gtk.ListBoxRow ();
				row.set_size_request (-1, 42);
				var h = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
				h.add_css_class ("mini-content-block");
				h.set_margin_start (16);

				// Mini canvas preview
				var mini_canvas = new Gtk.DrawingArea ();
				mini_canvas.set_content_width (32);
				mini_canvas.set_content_height (32);
				mini_canvas.set_draw_func ((da, cr, w, h) => {
					render_mini_element (cr, el, 32);
				});
				h.append (mini_canvas);

				var lbl = new Gtk.Label (element_label (el));
				lbl.set_xalign (0.0f);
				lbl.set_hexpand (true);
				h.append (lbl);

				if (model.reorder_mode) {
					// Drag source
					var drag_source = new Gtk.DragSource ();
					drag_source.set_actions (Gdk.DragAction.MOVE);
					drag_source.prepare.connect ((ds, x, y) => {
						var drag_data = @"$group_idx:$elem_idx";
						var val = GLib.Value (typeof (string));
						val.set_string (drag_data);
						return new Gdk.ContentProvider.for_value (val);
					});
					row.add_controller (drag_source);

					// Drop target
					var drop_target = new Gtk.DropTarget (typeof (string), Gdk.DragAction.MOVE);
					drop_target.drop.connect ((dt, val, x, y) => {
						var drag_data = (string) val;
						var parts = drag_data.split (":");
						if (parts.length == 2) {
							int src_group = int.parse (parts[0]);
							int src_elem = int.parse (parts[1]);
							move_element_between_groups (src_group, src_elem, group_idx, elem_idx);
						}
						return true;
					});
					row.add_controller (drop_target);
				}

				var rem = new He.Button ("edit-delete-symbolic", "");
				rem.set_tooltip_text ("Remove");
				rem.is_iconic = true;
				rem.set_valign (Gtk.Align.CENTER);
				rem.clicked.connect (() => { remove_element_at (group_idx, elem_idx); });
				h.append (rem);

				row.set_child (h);
				listbox.append (row);
			}
		}

		// Restore selection
		if (model.background_selected) {
			var r0 = listbox.get_row_at_index (0);
			if (r0 != null)listbox.select_row (r0);
		} else if (model.group_selected && model.selected_group_index >= 0) {
			// Calculate flat index for group header: 1 (background) + sum of (1 header + elements) for previous groups + 1 header
			int flat_index = 1;
			for (int g = 0; g < model.selected_group_index; g++) {
				var group = (ElementGroup) model.groups.get_item ((uint) g);
				int ne = (int) group.elements.get_n_items ();
				flat_index += 1 + ne;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 // group header + elements
			}
			flat_index++;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         // the target group header
			var r1 = listbox.get_row_at_index (flat_index);
			if (r1 != null)listbox.select_row (r1);
		} else if (model.selected_group_index >= 0 && model.selected_element_index >= 0) {
			// Calculate flat index: 1 (background) + sum of (1 header + elements) for previous groups + 1 header + element index
			int flat_index = 1;
			for (int g = 0; g < (int) model.groups.get_n_items (); g++) {
				var group = (ElementGroup) model.groups.get_item ((uint) g);
				int ne = (int) group.elements.get_n_items ();
				flat_index++;                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 // group header
				if (g == model.selected_group_index) {
					flat_index += model.selected_element_index;
					break;
				}
				flat_index += ne;
			}
			var r2 = listbox.get_row_at_index (flat_index);
			if (r2 != null)listbox.select_row (r2);
		} else {
			listbox.unselect_all ();
		}
	}

	private string element_label (IconElement e) {
		switch (e.type) {
		case ElementType.RECTANGLE : return "Rectangle";
		case ElementType.CIRCLE : return "Circle";
		case ElementType.LINE : return "Line";
		case ElementType.SVG : return "SVG";
		}
		return "Element";
	}

	private void render_mini_element (Cairo.Context cr, IconElement el, int size) {
		// Light checkerboard background
		draw_rounded_rect_path (cr, 0.0, 0.0, (double) size, (double) size, 2.0);
		cr.clip ();

		int checker_size = 4;
		for (int y = 0; y < size; y += checker_size) {
			for (int x = 0; x < size; x += checker_size) {
				if ((x / checker_size + y / checker_size) % 2 == 0) {
					cr.set_source_rgba (0.9, 0.9, 0.9, 1.0);
				} else {
					cr.set_source_rgba (0.8, 0.8, 0.8, 1.0);
				}
				cr.rectangle ((double) x, (double) y, (double) checker_size, (double) checker_size);
				cr.fill ();
			}
		}
		cr.reset_clip ();

		// Calculate scaling to fit element in mini canvas
		double scale = (double) size / 109.0;
		double ex = el.x * scale;
		double ey = el.y * scale;
		double ew = el.width * scale;
		double eh = el.height * scale;

		cr.save ();
		if (el.element_angle != 0.0) {
			double center_x = ex + ew / 2.0;
			double center_y = ey + eh / 2.0;
			cr.translate (center_x, center_y);
			cr.rotate (el.element_angle * (GLib.Math.PI / 180.0));
			cr.translate (-center_x, -center_y);
		}

		if (el.type == ElementType.RECTANGLE) {
			cr.set_source_rgba (el.fill.red, el.fill.green, el.fill.blue, el.fill.alpha);
			double tl = el.corner_radius_top_left * scale;
			double tr = el.corner_radius_top_right * scale;
			double br = el.corner_radius_bottom_right * scale;
			double bl = el.corner_radius_bottom_left * scale;
			cr.new_path ();
			IconiUtils.append_rounded_rect (cr, ex, ey, ew, eh, tl, tr, br, bl);
			cr.fill_preserve ();
			cr.set_source_rgba (el.stroke.red, el.stroke.green, el.stroke.blue, el.stroke.alpha);
			cr.set_line_width (el.stroke_width * scale);
			cr.stroke ();
		} else if (el.type == ElementType.CIRCLE) {
			double scale_x = ew / 2.0;
			double scale_y = eh / 2.0;
			double line_scale = (GLib.Math.fabs (scale_x) + GLib.Math.fabs (scale_y)) / 2.0;
			if (line_scale <= 0.0)line_scale = 1.0;
			cr.save ();
			cr.translate (ex + ew / 2.0, ey + eh / 2.0);
			cr.scale (scale_x, scale_y);
			cr.arc (0.0, 0.0, 1.0, 0.0, 2.0 * GLib.Math.PI);
			cr.restore ();
			cr.set_source_rgba (el.fill.red, el.fill.green, el.fill.blue, el.fill.alpha);
			cr.fill_preserve ();
			cr.set_source_rgba (el.stroke.red, el.stroke.green, el.stroke.blue, el.stroke.alpha);
			cr.set_line_width (el.stroke_width * scale);
			cr.stroke ();
		} else if (el.type == ElementType.LINE) {
			cr.set_source_rgba (el.stroke.red, el.stroke.green, el.stroke.blue, el.stroke.alpha);
			cr.set_line_width (el.stroke_width * scale);
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
				warning ("Failed to render SVG in mini canvas: %s", e.message);
			}
		}

		cr.restore ();
	}

	private void draw_rounded_rect_path (Cairo.Context cr, double x, double y, double w, double h, double radius) {
		cr.new_path ();
		IconiUtils.append_rounded_rect (cr, x, y, w, h, radius, radius, radius, radius);
	}

	private void remove_element_at (int group_index, int element_index) {
		if (group_index < 0 || element_index < 0)return;
		var group = (ElementGroup?) model.groups.get_item ((uint) group_index);
		if (group == null)return;
		uint count = group.elements.get_n_items ();
		if (element_index >= (int) count)return;
		group.elements.remove ((uint) element_index);
		int remaining = (int) group.elements.get_n_items ();
		if (remaining == 0) {
			// Remove the empty group
			model.groups.remove ((uint) group_index);
			model.selected_element_index = -1;
			model.selected_group_index = -1;
			model.background_selected = true;
		} else {
			int next_index = element_index;
			if (next_index >= remaining)next_index = remaining - 1;
			model.selected_element_index = next_index;
			model.selected_group_index = group_index;
			model.background_selected = false;
		}
		refresh_listbox ();
		update_properties_visibility ();
		canvas.queue_draw ();
	}

	private void move_element_between_groups (int src_group_idx, int src_elem_idx, int dest_group_idx, int dest_elem_idx) {
		if (src_group_idx < 0 || dest_group_idx < 0)return;
		if (src_elem_idx < 0)return;

		var src_group = (ElementGroup?) model.groups.get_item ((uint) src_group_idx);
		if (src_group == null)return;

		int src_count = (int) src_group.elements.get_n_items ();
		if (src_elem_idx >= src_count)return;

		bool same_group = (src_group_idx == dest_group_idx);
		var dest_group = same_group ? src_group : (ElementGroup?) model.groups.get_item ((uint) dest_group_idx);
		if (dest_group == null)return;

		if (dest_elem_idx < 0)dest_elem_idx = 0;

		var item = src_group.elements.get_item ((uint) src_elem_idx);
		if (item == null)return;

		src_group.elements.remove ((uint) src_elem_idx);

		if (!same_group) {
			if (src_group.elements.get_n_items () == 0) {
				model.groups.remove ((uint) src_group_idx);
				if (dest_group_idx > src_group_idx)dest_group_idx--;
				dest_group = (ElementGroup?) model.groups.get_item ((uint) dest_group_idx);
				if (dest_group == null) {
					model.selected_group_index = -1;
					model.selected_element_index = -1;
					model.background_selected = true;
					model.group_selected = false;
					refresh_listbox ();
					update_properties_visibility ();
					canvas.queue_draw ();
					return;
				}
			}
		}

		int dest_count = (int) dest_group.elements.get_n_items ();
		int adjusted_dest = dest_elem_idx;
		if (same_group && adjusted_dest > src_elem_idx)adjusted_dest--;
		if (adjusted_dest > dest_count)adjusted_dest = dest_count;
		if (adjusted_dest < 0)adjusted_dest = 0;

		dest_group.elements.insert ((uint) adjusted_dest, item);

		model.selected_group_index = dest_group_idx;
		model.selected_element_index = adjusted_dest;
		model.background_selected = false;
		model.group_selected = false;

		refresh_listbox ();
		update_properties_visibility ();
		canvas.queue_draw ();
	}

	private Gtk.Button create_color_button (Gdk.RGBA initial_color) {
		var btn = new Gtk.Button ();
		btn.set_size_request (48, 32);
		var area = new Gtk.DrawingArea ();
		area.set_content_width (48);
		area.set_content_height (32);
		btn.set_data<Gdk.RGBA?> ("current_color", initial_color);
		area.set_draw_func ((da, cr, w, h) => {
			Gdk.RGBA? stored_color = btn.get_data<Gdk.RGBA?> ("current_color");
			if (stored_color == null) {
				stored_color = initial_color;
			}
			cr.set_source_rgba (stored_color.red, stored_color.green, stored_color.blue, stored_color.alpha);
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
		entry.set_width_chars (3);
		entry.set_max_length (3);
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

	private string sanitize_corner_entry_text (string input) {
		string digits = "";
		for (int i = 0; i < input.length; i++) {
			char c = input[i];
			if (c >= '0' && c <= '9') {
				if (digits.length >= 3) {
					break;
				}
				digits += "%c".printf (c);
			}
		}
		return digits;
	}

	private void set_corner_entry_value (Gtk.Entry entry, double value) {
		double rounded = GLib.Math.round (value);
		double clamped = GLib.Math.fmax (0.0, GLib.Math.fmin (rounded, 999.0));
		string text = "%d".printf ((int) clamped);
		bool previous = updating_properties;
		updating_properties = true;
		entry.set_text (text);
		entry.set_position (text.length);
		updating_properties = previous;
	}

	private void update_corner_lock_icon () {
		if (corner_radius_lock_toggle == null)return;
		bool locked = corner_radius_lock_toggle.get_active ();
		string resource_path = locked ? ICON_LOCKED : ICON_UNLOCKED;
		string tooltip = locked ? "Unlock corner radii" : "Lock corner radii";
		if (corner_radius_lock_picture != null) {
			corner_radius_lock_picture.icon_name = resource_path;
		}
		corner_radius_lock_toggle.set_tooltip_text (tooltip);
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
					popover.popdown ();
				});
				grid.attach (swatch_btn, col, row, 1, 1);
			}
		}

		// Add neutral colors row
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
				popover.popdown ();
			});
			neutral_box.append (neutral_btn);
		}

		var button_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
		button_box.set_halign (Gtk.Align.END);
		content_box.append (button_box);

		var cancel_btn = new Gtk.Button.with_label ("Cancel");
		cancel_btn.clicked.connect (() => {
			popover.popdown ();
		});
		button_box.append (cancel_btn);

		var triggering_widget = parent;
		if (triggering_widget != null) {
			popover.set_parent (triggering_widget);
		} else {
			popover.set_parent (this);
		}
		popover.popup ();
	}

	private void apply_view_background_css () {
		if (center_box == null)return;
		if (view_bg_css == null) {
			view_bg_css = new Gtk.CssProvider ();
			var display = get_display ();
			if (display != null) {
				Gtk.StyleContext.add_provider_for_display (display, view_bg_css, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION);
			}
		}

		bool needs_light_fg = model.use_wallpaper || should_use_light_view_foreground ();
		if (needs_light_fg) {
			center_box.add_css_class ("light-fg");
		} else {
			center_box.remove_css_class ("light-fg");
		}

		var builder = new GLib.StringBuilder ("#center-bg { ");
		var vb = model.view_background;
		int r = (int) (vb.red * 255.0 + 0.5);
		int g = (int) (vb.green * 255.0 + 0.5);
		int b = (int) (vb.blue * 255.0 + 0.5);
		builder.append ("background: rgba(%d, %d, %d, %.3f);".printf (r, g, b, vb.alpha));

		if (model.use_wallpaper) {
			string? uri = get_preferred_wallpaper_uri ();
			if (uri != null) {
				if (wallpaper_uri_cache != uri) {
					wallpaper_uri_cache = uri;
				}
				string escaped = IconiUtils.escape_css_url (uri);
				builder.append (" background-image: url(\"%s\"); background-size: cover; background-position: center; background-repeat: no-repeat;".printf (escaped));
			}
		}
		builder.append (" }");

		view_bg_css.load_from_data ((uint8[]) builder.str);
	}

	private bool should_use_light_view_foreground () {
		double bg_luminance = IconiUtils.compute_relative_luminance (model.view_background);
		double contrast_white = IconiUtils.contrast_ratio (bg_luminance, 1.0);
		double contrast_black = IconiUtils.contrast_ratio (bg_luminance, 0.0);
		return contrast_white >= contrast_black;
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
		updating_properties = previous;
		apply_view_background_css ();
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

	private void update_sidebar_visibility (bool show) {
		if (right_box == null || mappbar == null || canvas == null)return;

		right_box.set_visible (show);

		if (show) {
			// Allocate space for sidebar
			mappbar.set_margin_end (348);
			canvas.set_margin_end (348);
			mappbar.show_right_title_buttons = false;
		} else {
			mappbar.set_margin_end (0);
			canvas.set_margin_end (0);
			mappbar.show_right_title_buttons = true;
		}
	}

	private void update_properties_visibility () {
		updating_properties = true;
		try {
			bool show_bg = model.background_selected;
			bool show_group = model.group_selected;
			bool show_el = (!model.background_selected && !model.group_selected && model.selected_group_index >= 0 && model.selected_element_index >= 0);

			bg_props_area.set_visible (show_bg);
			group_props_area.set_visible (show_group);
			props_area.set_visible (show_el);

			update_sidebar_visibility (show_bg || show_group || show_el);

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
					int bidx = 0;
					for (int i = 0; i < blend_values.length; i++) {
						if (blend_values[i] == group.blend_mode) {
							bidx = i;
							break;
						}
					}
					group_blend_drop.set_selected ((uint) bidx);
					group_raised_toggle.set_active (group.use_raised_effect);
					group_shadow_toggle.set_active (group.use_shadow);
					group_shadow_mode_drop.set_selected (group.shadow_chromatic ? 1u : 0u);
					group_effect_scope_drop.set_selected (group.effect_scope == GroupEffectScope.COMBINED ? 1u : 0u);
				}
			}
			if (show_el) {
				var el = get_selected_element ();
				if (el == null)return;
				x_entry.set_value ((double) el.x);
				y_entry.set_value ((double) el.y);
				w_entry.set_value ((double) el.width);
				h_entry.set_value ((double) el.height);
				stroke_width_spin.set_value ((double) el.stroke_width);
				update_color_button (fill_btn, el.fill);
				update_color_button (stroke_btn, el.stroke);

				bool is_line = (el.type == ElementType.LINE);
				bool show_fill = !is_line;
				fill_box.set_visible (show_fill);

				size_box.set_visible (!is_line);
				line_controls_box.set_visible (is_line);
				corner_box.set_visible (el.type == ElementType.RECTANGLE);
				if (el.type == ElementType.RECTANGLE) {
					apply_corner_radius_constraints (el);
				}

				if (is_line) {
					line_length_spin.set_value ((double) el.line_length);
					line_angle_spin.set_value (el.line_angle);
				}

				element_angle_spin.set_value (el.element_angle);

				fill_opacity_spin.set_value ((double) ((float) el.fill.alpha * 100.0f));
				stroke_opacity_spin.set_value ((double) ((float) el.stroke.alpha * 100.0f));

				fill_mode_drop.set_selected (el.use_gradient ? 1u : 0u);
				update_color_button (fill_gradient_btn, el.gradient_secondary);
				fill_gradient_angle_spin.set_value (el.gradient_angle);
				fill_gradient_color_row.set_visible (el.use_gradient);
				fill_gradient_angle_row.set_visible (el.use_gradient);
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
		update_color_button (bg_side_color_btn, rgba);
		updating_properties = previous;
		sync_gradient_controls_visibility ();
		canvas.queue_draw ();
	}

	private void update_gradient_secondary_color (Gdk.RGBA rgba) {
		model.gradient_secondary = rgba;
		bool previous = updating_properties;
		updating_properties = true;
		update_color_button (bg_gradient_end_btn, rgba);
		updating_properties = previous;
		if (model.use_gradient) {
			canvas.queue_draw ();
		}
	}

	private void update_position_entries (IconElement el) {
		bool previous = updating_properties;
		updating_properties = true;
		x_entry.set_value ((double) el.x);
		y_entry.set_value ((double) el.y);
		updating_properties = previous;
	}

	private void update_corner_radius_controls (IconElement el) {
		if (corner_radius_tl_entry == null)return;
		set_corner_entry_value (corner_radius_tl_entry, el.corner_radius_top_left);
		set_corner_entry_value (corner_radius_tr_entry, el.corner_radius_top_right);
		set_corner_entry_value (corner_radius_br_entry, el.corner_radius_bottom_right);
		set_corner_entry_value (corner_radius_bl_entry, el.corner_radius_bottom_left);
		bool previous = updating_properties;
		updating_properties = true;
		corner_radius_lock_toggle.set_active (el.corner_radius_locked);
		updating_properties = previous;
		update_corner_lock_icon ();
	}

	private void handle_corner_radius_entry (CornerHandle handle, Gtk.Entry entry) {
		if (updating_properties)return;
		var el = get_selected_element ();
		if (el == null)return;
		if (el.type != ElementType.RECTANGLE)return;
		string raw = entry.get_text ();
		string sanitized = sanitize_corner_entry_text (raw);
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
		int value = 0;
		value = int.parse (sanitized);
		if (value > 999) {
			entry.set_text ("999");
			entry.set_position (3);
			return;
		}
		float radius = (float) value;
		if (el.corner_radius_locked) {
			el.corner_radius_top_left = radius;
			el.corner_radius_top_right = radius;
			el.corner_radius_bottom_right = radius;
			el.corner_radius_bottom_left = radius;
		} else {
			switch (handle) {
			case CornerHandle.TOP_LEFT :
				el.corner_radius_top_left = radius;
				break;
			case CornerHandle.TOP_RIGHT :
				el.corner_radius_top_right = radius;
				break;
			case CornerHandle.BOTTOM_RIGHT :
				el.corner_radius_bottom_right = radius;
				break;
			case CornerHandle.BOTTOM_LEFT :
				el.corner_radius_bottom_left = radius;
				break;
			}
		}
		apply_corner_radius_constraints (el);
		canvas.queue_draw ();
	}

	private void apply_corner_radius_constraints (IconElement el) {
		if (el.type != ElementType.RECTANGLE)return;
		if (el.corner_radius_locked) {
			double uniform = el.corner_radius_top_left;
			uniform = GLib.Math.fmax (0.0, GLib.Math.fmin (uniform, 999.0));
			float uniformf = (float) uniform;
			el.corner_radius_top_left = uniformf;
			el.corner_radius_top_right = uniformf;
			el.corner_radius_bottom_right = uniformf;
			el.corner_radius_bottom_left = uniformf;
		}

		double width = el.width;
		double height = el.height;
		double tl = el.corner_radius_top_left;
		double tr = el.corner_radius_top_right;
		double br = el.corner_radius_bottom_right;
		double bl = el.corner_radius_bottom_left;

		IconiUtils.normalize_corner_radii (ref tl, ref tr, ref br, ref bl, width, height);

		tl = GLib.Math.fmax (0.0, GLib.Math.fmin (GLib.Math.floor (tl), 999.0));
		tr = GLib.Math.fmax (0.0, GLib.Math.fmin (GLib.Math.floor (tr), 999.0));
		br = GLib.Math.fmax (0.0, GLib.Math.fmin (GLib.Math.floor (br), 999.0));
		bl = GLib.Math.fmax (0.0, GLib.Math.fmin (GLib.Math.floor (bl), 999.0));

		el.corner_radius_top_left = (float) tl;
		el.corner_radius_top_right = (float) tr;
		el.corner_radius_bottom_right = (float) br;
		el.corner_radius_bottom_left = (float) bl;

		update_corner_radius_controls (el);
	}

	private void align_selected_element_horizontal (int mode) {
		var el = get_selected_element ();
		if (el == null)return;
		double canvas_size = 109.0;
		if (el.type == ElementType.LINE) {
			double x1 = el.x;
			double x2 = el.x + el.width;
			double min_x = GLib.Math.fmin (x1, x2);
			double max_x = GLib.Math.fmax (x1, x2);
			double span = max_x - min_x;
			double target = 0.0;
			double max_target = GLib.Math.fmax (canvas_size - span, 0.0);
			switch (mode) {
			case 0 : target = 0.0; break;
			case 1 : target = (canvas_size - span) / 2.0; break;
			case 2 : target = canvas_size - span; break;
				default : target = 0.0; break;
			}
			target = GLib.Math.fmax (0.0, GLib.Math.fmin (target, max_target));
			double delta = target - min_x;
			el.x = (float) (el.x + delta);
		} else {
			double width = el.width;
			double target = 0.0;
			double max_target = GLib.Math.fmax (canvas_size - width, 0.0);
			switch (mode) {
			case 0 : target = 0.0; break;
			case 1 : target = (canvas_size - width) / 2.0; break;
			case 2 : target = canvas_size - width; break;
			default: target = 0.0; break;
			}
			target = GLib.Math.fmax (0.0, GLib.Math.fmin (target, max_target));
			el.x = IconiUtils.clampf ((float) target, 0.0f, (float) canvas_size);
		}
		update_position_entries (el);
		canvas.queue_draw ();
	}

	private void align_selected_element_vertical (int mode) {
		var el = get_selected_element ();
		if (el == null)return;
		double canvas_size = 109.0;
		if (el.type == ElementType.LINE) {
			double y1 = el.y;
			double y2 = el.y + el.height;
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
			el.y = (float) (el.y + delta);
		} else {
			double height = el.height;
			double target = 0.0;
			double max_target = GLib.Math.fmax (canvas_size - height, 0.0);
			switch (mode) {
			case 0: target = 0.0; break;
			case 1: target = (canvas_size - height) / 2.0; break;
			case 2: target = canvas_size - height; break;
			default: target = 0.0; break;
			}
			target = GLib.Math.fmax (0.0, GLib.Math.fmin (target, max_target));
			el.y = IconiUtils.clampf ((float) target, 0.0f, (float) canvas_size);
		}
		update_position_entries (el);
		canvas.queue_draw ();
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
		try {
			var file = GLib.File.new_for_path (filename);
			var stream = file.replace (null, false, GLib.FileCreateFlags.NONE);
			var data_stream = new GLib.DataOutputStream (stream);

			double svg_size = 128.0;
			double icon_size = 109.0;
			double offset = (svg_size - icon_size) / 2.0;
			double radius = 24.0;

			data_stream.put_string ("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");
			data_stream.put_string ("<svg xmlns=\"http://www.w3.org/2000/svg\" ");
			data_stream.put_string ("width=\"128\" height=\"128\" viewBox=\"0 0 128 128\">\n");
			data_stream.put_string ("  <defs>\n");

			int gradient_id = 0;
			if (model.use_gradient) {
				data_stream.put_string ("    <linearGradient id=\"bg-gradient\" ");
				data_stream.put_string ("x1=\"0%%\" y1=\"0%%\" x2=\"100%%\" y2=\"100%%\" gradientTransform=\"rotate(%g 0.5 0.5)\">\n".printf (model.gradient_angle));
				data_stream.put_string ("      <stop offset=\"0%%\" style=\"stop-color:%s;stop-opacity:%.3f\"/>\n".printf (IconiUtils.rgba_to_hex (model.background), model.background.alpha));
				data_stream.put_string ("      <stop offset=\"100%%\" style=\"stop-color:%s;stop-opacity:%.3f\"/>\n".printf (IconiUtils.rgba_to_hex (model.gradient_secondary), model.gradient_secondary.alpha));
				data_stream.put_string ("    </linearGradient>\n");
			}

			int ng = (int) model.groups.get_n_items ();
			for (int g = 0; g < ng; g++) {
				var group = (ElementGroup) model.groups.get_item ((uint) g);
				int ne = (int) group.elements.get_n_items ();
				for (int i = 0; i < ne; i++) {
					var el = (IconElement) group.elements.get_item ((uint) i);
					if (el.use_gradient) {
						string grad_id = "gradient-%d".printf (gradient_id++);
						data_stream.put_string ("    <linearGradient id=\"%s\" ".printf (grad_id));
						data_stream.put_string ("gradientTransform=\"rotate(%g 0.5 0.5)\">\n".printf (el.gradient_angle));
						data_stream.put_string ("      <stop offset=\"0%%\" style=\"stop-color:%s;stop-opacity:%.3f\"/>\n".printf (IconiUtils.rgba_to_hex (el.fill), el.fill.alpha));
						data_stream.put_string ("      <stop offset=\"100%%\" style=\"stop-color:%s;stop-opacity:%.3f\"/>\n".printf (IconiUtils.rgba_to_hex (el.gradient_secondary), el.gradient_secondary.alpha));
						data_stream.put_string ("    </linearGradient>\n");
					}
				}
			}
			data_stream.put_string ("  </defs>\n");
			data_stream.put_string ("  <g id=\"icon\" transform=\"translate(%g,%g)\">\n".printf (offset, offset));

			string bg_fill;
			if (model.use_gradient) {
				bg_fill = "url(#bg-gradient)";
			} else {
				bg_fill = IconiUtils.rgba_to_hex (model.background);
			}
			data_stream.put_string ("    <rect id=\"background\" x=\"0\" y=\"0\" width=\"%g\" height=\"%g\" rx=\"%g\" ".printf (icon_size, icon_size, radius));
			data_stream.put_string ("fill=\"%s\" fill-opacity=\"%.3f\"/>\n".printf (bg_fill, model.use_gradient ? 1.0 : model.background.alpha));

			gradient_id = 0;
			for (int g = 0; g < ng; g++) {
				var group = (ElementGroup) model.groups.get_item ((uint) g);
				string group_blend_style = group.blend_mode != "normal" ? " style=\"mix-blend-mode:%s\"".printf (group.blend_mode) : "";
				data_stream.put_string ("    <g id=\"group-%d\"%s>\n".printf (g, group_blend_style));

				int ne = (int) group.elements.get_n_items ();
				for (int i = 0; i < ne; i++) {
					var el = (IconElement) group.elements.get_item ((uint) i);

					string element_id = "element-g%d-e%d".printf (g, i);
					string fill_value;
					double fill_opacity;

					if (el.use_gradient) {
						fill_value = "url(#gradient-%d)".printf (gradient_id++);
						fill_opacity = 1.0;
					} else {
						fill_value = IconiUtils.rgba_to_hex (el.fill);
						fill_opacity = el.fill.alpha;
					}

					string stroke_value = IconiUtils.rgba_to_hex (el.stroke);
					double stroke_opacity = el.stroke.alpha;

					string transform_str = "";
					if (el.element_angle != 0.0) {
						double center_x = el.x + el.width / 2.0;
						double center_y = el.y + el.height / 2.0;
						transform_str = " transform=\"rotate(%g %g %g)\"".printf (el.element_angle, center_x, center_y);
					}

					if (el.type == ElementType.RECTANGLE) {
						double tl = el.corner_radius_top_left;
						double tr = el.corner_radius_top_right;
						double br = el.corner_radius_bottom_right;
						double bl = el.corner_radius_bottom_left;
						IconiUtils.normalize_corner_radii (ref tl, ref tr, ref br, ref bl, el.width, el.height);
						bool uniform_corners = IconiUtils.corner_radii_are_uniform (tl, tr, br, bl);
						if (uniform_corners) {
							double bradius = tl;
							data_stream.put_string ("      <rect id=\"%s\" x=\"%g\" y=\"%g\" width=\"%g\" height=\"%g\" ".printf (element_id, el.x, el.y, el.width, el.height));
							data_stream.put_string ("fill=\"%s\" fill-opacity=\"%.3f\" ".printf (fill_value, fill_opacity));
							data_stream.put_string ("stroke=\"%s\" stroke-opacity=\"%.3f\" stroke-width=\"%g\" rx=\"%g\" ry=\"%g\"%s/>\n".printf (stroke_value, stroke_opacity, el.stroke_width, bradius, bradius, transform_str));
						} else {
							string path_data = IconiUtils.rounded_rect_path_d (el.x, el.y, el.width, el.height, tl, tr, br, bl);
							data_stream.put_string ("      <path id=\"%s\" d=\"%s\" ".printf (element_id, path_data));
							data_stream.put_string ("fill=\"%s\" fill-opacity=\"%.3f\" ".printf (fill_value, fill_opacity));
							data_stream.put_string ("stroke=\"%s\" stroke-opacity=\"%.3f\" stroke-width=\"%g\"%s/>\n".printf (stroke_value, stroke_opacity, el.stroke_width, transform_str));
						}
					} else if (el.type == ElementType.CIRCLE) {
						double cx = el.x + el.width / 2.0;
						double cy = el.y + el.height / 2.0;
						double rx = el.width / 2.0;
						double ry = el.height / 2.0;
						data_stream.put_string ("      <ellipse id=\"%s\" cx=\"%g\" cy=\"%g\" rx=\"%g\" ry=\"%g\" ".printf (element_id, cx, cy, rx, ry));
						data_stream.put_string ("fill=\"%s\" fill-opacity=\"%.3f\" ".printf (fill_value, fill_opacity));
						data_stream.put_string ("stroke=\"%s\" stroke-opacity=\"%.3f\" stroke-width=\"%g\"%s/>\n".printf (stroke_value, stroke_opacity, el.stroke_width, transform_str));
					} else if (el.type == ElementType.LINE) {
						double x2 = el.x + el.width;
						double y2 = el.y + el.height;

						if (el.use_gradient) {
							string line_grad_id = "gradient-%d".printf (gradient_id - 1);
							data_stream.put_string ("      <line id=\"%s\" x1=\"%g\" y1=\"%g\" x2=\"%g\" y2=\"%g\" ".printf (element_id, el.x, el.y, x2, y2));
							data_stream.put_string ("stroke=\"url(#%s)\" stroke-opacity=\"1.0\" stroke-width=\"%g\"%s/>\n".printf (line_grad_id, el.stroke_width, transform_str));
						} else {
							data_stream.put_string ("      <line id=\"%s\" x1=\"%g\" y1=\"%g\" x2=\"%g\" y2=\"%g\" ".printf (element_id, el.x, el.y, x2, y2));
							data_stream.put_string ("stroke=\"%s\" stroke-opacity=\"%.3f\" stroke-width=\"%g\"%s/>\n".printf (stroke_value, stroke_opacity, el.stroke_width, transform_str));
						}
					} else if (el.type == ElementType.SVG) {
						data_stream.put_string ("      <g id=\"%s\"%s>\n".printf (element_id, transform_str));
						data_stream.put_string ("        <svg x=\"%g\" y=\"%g\" width=\"%g\" height=\"%g\">\n".printf (el.x, el.y, el.width, el.height));
						data_stream.put_string ("          %s\n".printf (el.svg_data));
						data_stream.put_string ("        </svg>\n");
						data_stream.put_string ("      </g>\n");
					}
				}
				data_stream.put_string ("    </g>\n");
			}

			double overlay_scale = icon_size / 128.0;
			if (model.use_raised_effect) {
				write_overlay_svg (data_stream, "effects", "/com/fyralabs/Iconi/effects.svg", overlay_scale);
			}
			if (model.use_frame_overlay) {
				write_overlay_svg (data_stream, "frame", "/com/fyralabs/Iconi/frame.svg", overlay_scale);
			}
			if (model.show_dev_badge) {
				write_overlay_svg (data_stream, "dev", "/com/fyralabs/Iconi/dev.svg", overlay_scale);
			}

			data_stream.put_string ("  </g>\n");
			data_stream.put_string ("</svg>\n");

			data_stream.close ();
		} catch (GLib.Error e) {
			GLib.warning ("Failed to export SVG: %s", e.message);
		}
	}

	private string ? load_overlay_svg (string resource_path) {
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
			GLib.warning ("Failed to load overlay resource %s: %s", resource_path, e.message);
			return null;
		}
	}

	private string normalize_overlay_svg (string raw) {
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

	private void write_overlay_svg (GLib.DataOutputStream stream, string overlay_id, string resource_path, double scale) {
		string? raw = load_overlay_svg (resource_path);
		if (raw == null || raw.length == 0) {
			return;
		}
		string normalized = normalize_overlay_svg (raw);
		if (normalized.strip ().length == 0) {
			return;
		}

		try {
			stream.put_string ("    <g id=\"overlay-%s\" transform=\"scale(%g)\">\n".printf (overlay_id, scale));
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
}
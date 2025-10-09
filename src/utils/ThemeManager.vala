/*
 * digger-vala - DNS lookup tool with GTK interface
 * Copyright (C) 2024 tobagin
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 */

namespace Digger {
    public enum ColorScheme {
        SYSTEM,
        LIGHT,
        DARK;
        
        public string to_string() {
            switch (this) {
                case SYSTEM:
                    return "system";
                case LIGHT:
                    return "light";
                case DARK:
                    return "dark";
                default:
                    return "system";
            }
        }
        
        public static ColorScheme from_string(string str) {
            switch (str.down()) {
                case "light":
                    return LIGHT;
                case "dark":
                    return DARK;
                case "system":
                default:
                    return SYSTEM;
            }
        }
    }
    
    public class ThemeManager : GLib.Object {
        private static ThemeManager? instance = null;
        private Adw.StyleManager style_manager;
        private GLib.Settings settings;
        
        public signal void theme_changed(ColorScheme scheme);
        
        private ThemeManager() {
            style_manager = Adw.StyleManager.get_default();
            
            // Set up settings
            try {
                settings = new GLib.Settings(Config.APP_ID);
                var stored_theme = settings.get_string("color-scheme");
                apply_theme(ColorScheme.from_string(stored_theme));
            } catch (Error e) {
                warning("Could not load settings: %s", e.message);
                apply_theme(ColorScheme.SYSTEM);
            }
        }
        
        public static ThemeManager get_instance() {
            if (instance == null) {
                instance = new ThemeManager();
            }
            return instance;
        }
        
        public void set_color_scheme(ColorScheme scheme) {
            apply_theme(scheme);
            
            // Save to settings
            try {
                settings.set_string("color-scheme", scheme.to_string());
            } catch (Error e) {
                warning("Could not save theme setting: %s", e.message);
            }
            
            theme_changed(scheme);
        }
        
        private void apply_theme(ColorScheme scheme) {
            switch (scheme) {
                case ColorScheme.LIGHT:
                    style_manager.color_scheme = Adw.ColorScheme.FORCE_LIGHT;
                    break;
                case ColorScheme.DARK:
                    style_manager.color_scheme = Adw.ColorScheme.FORCE_DARK;
                    break;
                case ColorScheme.SYSTEM:
                default:
                    style_manager.color_scheme = Adw.ColorScheme.DEFAULT;
                    break;
            }
        }
        
        public ColorScheme get_current_scheme() {
            switch (style_manager.color_scheme) {
                case Adw.ColorScheme.FORCE_LIGHT:
                    return ColorScheme.LIGHT;
                case Adw.ColorScheme.FORCE_DARK:
                    return ColorScheme.DARK;
                case Adw.ColorScheme.DEFAULT:
                case Adw.ColorScheme.PREFER_LIGHT:
                case Adw.ColorScheme.PREFER_DARK:
                default:
                    return ColorScheme.SYSTEM;
            }
        }
        
        public bool is_dark_theme_active() {
            return style_manager.dark;
        }
    }
}

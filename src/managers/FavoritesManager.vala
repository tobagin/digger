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
    public class FavoriteEntry : Object {
        public string domain { get; set; }
        public string label { get; set; default = ""; }
        public RecordType record_type { get; set; default = RecordType.A; }
        public string? dns_server { get; set; default = null; }
        public string? tags { get; set; default = null; }
        public DateTime created { get; set; }

        public FavoriteEntry (string domain, RecordType record_type = RecordType.A) {
            this.domain = domain;
            this.record_type = record_type;
            this.created = new DateTime.now_local ();
        }

        public FavoriteEntry.from_json (Json.Object obj) {
            this.domain = obj.get_string_member ("domain");
            this.label = obj.has_member ("label") ? obj.get_string_member ("label") : "";
            this.record_type = RecordType.from_string (
                obj.has_member ("recordType") ? obj.get_string_member ("recordType") : "A"
            );
            this.dns_server = obj.has_member ("dnsServer") ? obj.get_string_member ("dnsServer") : null;
            this.tags = obj.has_member ("tags") ? obj.get_string_member ("tags") : null;

            if (obj.has_member ("created")) {
                this.created = new DateTime.from_unix_local (obj.get_int_member ("created"));
            } else {
                this.created = new DateTime.now_local ();
            }
        }

        public Json.Object to_json () {
            var obj = new Json.Object ();
            obj.set_string_member ("domain", domain);
            obj.set_string_member ("label", label);
            obj.set_string_member ("recordType", record_type.to_string ());
            if (dns_server != null && dns_server.length > 0) {
                obj.set_string_member ("dnsServer", dns_server);
            }
            if (tags != null && tags.length > 0) {
                obj.set_string_member ("tags", tags);
            }
            obj.set_int_member ("created", created.to_unix ());
            return obj;
        }

        public string get_display_label () {
            if (label.length > 0) {
                return label;
            }
            return domain;
        }

        public Gee.ArrayList<string> get_tag_list () {
            var tag_list = new Gee.ArrayList<string> ();
            if (tags != null && tags.length > 0) {
                var parts = tags.split (",");
                foreach (var part in parts) {
                    var trimmed = part.strip ();
                    if (trimmed.length > 0) {
                        tag_list.add (trimmed);
                    }
                }
            }
            return tag_list;
        }
    }

    public class FavoritesManager : Object {
        private static FavoritesManager? instance = null;
        private Gee.ArrayList<FavoriteEntry> favorites;
        private File favorites_file;

        public signal void favorites_updated ();

        public static FavoritesManager get_instance () {
            if (instance == null) {
                instance = new FavoritesManager ();
            }
            return instance;
        }

        private FavoritesManager () {
            favorites = new Gee.ArrayList<FavoriteEntry> ();

            var data_dir = File.new_for_path (Environment.get_user_data_dir ())
                .get_child ("digger");

            try {
                if (!data_dir.query_exists ()) {
                    data_dir.make_directory_with_parents ();
                }
            } catch (Error e) {
                warning ("Failed to create data directory: %s", e.message);
            }

            favorites_file = data_dir.get_child ("favorites.json");
            load_favorites.begin ();
        }

        public async void load_favorites () {
            if (!favorites_file.query_exists ()) {
                return;
            }

            try {
                uint8[] contents;
                yield favorites_file.load_contents_async (null, out contents, null);

                var parser = new Json.Parser ();
                parser.load_from_data ((string) contents);

                var root = parser.get_root ();
                if (root != null && root.get_node_type () == Json.NodeType.ARRAY) {
                    var array = root.get_array ();
                    favorites.clear ();

                    array.foreach_element ((arr, index, node) => {
                        if (node.get_node_type () == Json.NodeType.OBJECT) {
                            var entry = new FavoriteEntry.from_json (node.get_object ());
                            favorites.add (entry);
                        }
                    });

                    favorites_updated ();
                }
            } catch (Error e) {
                warning ("Failed to load favorites: %s", e.message);
            }
        }

        public async void save_favorites () {
            try {
                var generator = new Json.Generator ();
                var root = new Json.Node (Json.NodeType.ARRAY);
                var array = new Json.Array ();

                foreach (var entry in favorites) {
                    var node = new Json.Node (Json.NodeType.OBJECT);
                    node.set_object (entry.to_json ());
                    array.add_element (node);
                }

                root.set_array (array);
                generator.set_root (root);
                generator.set_pretty (true);

                string json_data = generator.to_data (null);
                yield favorites_file.replace_contents_async (
                    json_data.data,
                    null,
                    false,
                    FileCreateFlags.REPLACE_DESTINATION,
                    null,
                    null
                );
            } catch (Error e) {
                warning ("Failed to save favorites: %s", e.message);
            }
        }

        public void add_favorite (FavoriteEntry entry) {
            foreach (var fav in favorites) {
                if (fav.domain == entry.domain && fav.record_type == entry.record_type) {
                    return;
                }
            }

            favorites.add (entry);
            save_favorites.begin ();
            favorites_updated ();
        }

        public void remove_favorite (FavoriteEntry entry) {
            favorites.remove (entry);
            save_favorites.begin ();
            favorites_updated ();
        }

        public void update_favorite (FavoriteEntry entry) {
            save_favorites.begin ();
            favorites_updated ();
        }

        public bool is_favorite (string domain, RecordType record_type) {
            foreach (var fav in favorites) {
                if (fav.domain == domain && fav.record_type == record_type) {
                    return true;
                }
            }
            return false;
        }

        public FavoriteEntry? get_favorite (string domain, RecordType record_type) {
            foreach (var fav in favorites) {
                if (fav.domain == domain && fav.record_type == record_type) {
                    return fav;
                }
            }
            return null;
        }

        public Gee.ArrayList<FavoriteEntry> get_all_favorites () {
            return favorites;
        }

        public Gee.ArrayList<FavoriteEntry> search_favorites (string query) {
            var results = new Gee.ArrayList<FavoriteEntry> ();
            string lower_query = query.down ();

            foreach (var fav in favorites) {
                if (fav.domain.down ().contains (lower_query) ||
                    fav.label.down ().contains (lower_query) ||
                    (fav.tags != null && fav.tags.down ().contains (lower_query))) {
                    results.add (fav);
                }
            }

            return results;
        }

        public Gee.HashSet<string> get_all_tags () {
            var tag_set = new Gee.HashSet<string> ();

            foreach (var fav in favorites) {
                var tags = fav.get_tag_list ();
                foreach (var tag in tags) {
                    tag_set.add (tag);
                }
            }

            return tag_set;
        }
    }
}
